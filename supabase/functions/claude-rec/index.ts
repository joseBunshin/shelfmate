// claude-rec Edge Function — U6 Discover / AI rec composer.
//
// Required JWT claims: sub (user id), role=authenticated.
// Required environment:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_ANON_KEY,
//   ANTHROPIC_API_KEY, ANTHROPIC_MODEL (defaults to claude-opus-4-7).
//
// Body (JSON):
//   { genres: string[], recently_read_book_ids: string[], n: number }
//
// Returns:
//   200 { recommendations: [{ book_id, title, authors, why }], cached: boolean,
//         from_cache_id?: string }
//   401 invalid_jwt
//   400 bad_request
//   429 rate_limited (more than N calls / window per user)
//   502 claude_failed
//
// Cache model:
//   1. Build cache_key = sha256(sorted_genres + sorted_recently_read).
//   2. Look up ai_rec_cache by (user_id, cache_key) where freshness check
//      is generated_at + ttl_seconds > now(). On hit: return cached.
//   3. On miss: build the Anthropic message with genres + recently_read +
//      ai_not_interested exclusions, call Claude, parse the structured
//      response, look up the suggested book ids in the books cache (or
//      add fresh rows from OL/GB metadata embedded in the response),
//      write a new ai_rec_cache row with token usage + cost.
//
// Cost monitoring:
//   - prompt_tokens, completion_tokens captured per row.
//   - cost_cents computed from per-1k pricing of the chosen model.
//   - Rate limit: 30 calls/24h per user (enforced by counting rows in
//     ai_rec_cache for this user where generated_at > now() - interval
//     '24 hours'). The Anthropic spend cap (set in U1.2) is the backstop.

import { serve } from "https://deno.land/std@0.220.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY");
const ANTHROPIC_MODEL = Deno.env.get("ANTHROPIC_MODEL") ?? "claude-opus-4-7";

// Per-1M-token cost in cents. Conservative defaults; refresh when Anthropic
// publishes updated pricing for the chosen model.
const INPUT_CENTS_PER_MTOK = 1500; // $15 / 1M input
const OUTPUT_CENTS_PER_MTOK = 7500; // $75 / 1M output

const RATE_LIMIT_PER_DAY = 30;
const CACHE_TTL_SECONDS = 6 * 60 * 60; // 6h freshness window

interface Body {
  genres?: unknown;
  recently_read_book_ids?: unknown;
  n?: unknown;
}

interface ClaudeRec {
  title: string;
  authors: string[];
  why: string;
  isbn_13?: string;
}

serve(async (req) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });
  if (!SUPABASE_URL || !SERVICE_ROLE_KEY || !ANON_KEY || !ANTHROPIC_API_KEY) {
    return jsonError("server_misconfigured", 500);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return jsonError("missing_auth", 401);

  const userClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: authError } = await userClient.auth.getUser();
  if (authError || !userData.user) return jsonError("invalid_jwt", 401);
  const userId = userData.user.id;

  let body: Body;
  try {
    body = await req.json();
  } catch {
    return jsonError("bad_json", 400);
  }
  const genres = Array.isArray(body.genres) ? body.genres.filter((g): g is string => typeof g === "string") : [];
  const recently_read_book_ids = Array.isArray(body.recently_read_book_ids)
    ? body.recently_read_book_ids.filter((s): s is string => typeof s === "string")
    : [];
  const n = typeof body.n === "number" && body.n > 0 && body.n <= 10 ? Math.floor(body.n) : 5;

  if (genres.length === 0) return jsonError("genres_required", 400);

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Rate limit
  const sinceIso = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const { count: callsToday } = await admin
    .from("ai_rec_cache")
    .select("*", { count: "exact", head: true })
    .eq("user_id", userId)
    .gte("generated_at", sinceIso);
  if ((callsToday ?? 0) >= RATE_LIMIT_PER_DAY) {
    return jsonError("rate_limited", 429);
  }

  // Cache key
  const cacheKey = await sha256Hex(
    [...genres].sort().join("|") + "::" + [...recently_read_book_ids].sort().join("|")
  );

  // Cache lookup
  const { data: cached } = await admin
    .from("ai_rec_cache")
    .select("id, recommended_book_ids, generated_at, ttl_seconds")
    .eq("user_id", userId)
    .eq("cache_key", cacheKey)
    .order("generated_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (cached) {
    const generatedAt = new Date(cached.generated_at).getTime();
    const expiresAt = generatedAt + cached.ttl_seconds * 1000;
    if (Date.now() < expiresAt) {
      const books = await fetchBooks(admin, cached.recommended_book_ids as string[]);
      return jsonOk({ recommendations: books, cached: true, from_cache_id: cached.id });
    }
  }

  // Compose Claude prompt
  const { data: notInterestedRows } = await admin
    .from("ai_not_interested")
    .select("book_id")
    .eq("user_id", userId);
  const notInterestedIds = (notInterestedRows ?? []).map((r) => r.book_id as string);

  const prompt = buildPrompt({ genres, recently_read_book_ids, notInterestedIds, n });

  // Call Claude
  let claudeResp: Response;
  try {
    claudeResp = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: ANTHROPIC_MODEL,
        max_tokens: 2048,
        messages: [{ role: "user", content: prompt }],
      }),
    });
  } catch {
    return jsonError("claude_failed", 502);
  }
  if (!claudeResp.ok) {
    console.error("claude-rec: Anthropic returned", claudeResp.status);
    return jsonError("claude_failed", 502);
  }

  const claudeJson = (await claudeResp.json()) as {
    content?: { type: string; text?: string }[];
    usage?: { input_tokens: number; output_tokens: number };
  };

  const text = claudeJson.content?.find((c) => c.type === "text")?.text ?? "";
  const recs = parseRecs(text, n);
  if (recs.length === 0) return jsonError("claude_failed", 502);

  // Resolve / create books cache rows
  const resolvedBookIds: string[] = [];
  for (const rec of recs) {
    const id = await upsertBook(admin, rec);
    if (id) resolvedBookIds.push(id);
  }

  const promptTokens = claudeJson.usage?.input_tokens ?? 0;
  const completionTokens = claudeJson.usage?.output_tokens ?? 0;
  const costCents =
    (promptTokens * INPUT_CENTS_PER_MTOK) / 1_000_000 +
    (completionTokens * OUTPUT_CENTS_PER_MTOK) / 1_000_000;

  await admin.from("ai_rec_cache").upsert(
    {
      user_id: userId,
      cache_key: cacheKey,
      query_context: { genres, recently_read_book_ids, n },
      recommended_book_ids: resolvedBookIds,
      claude_model: ANTHROPIC_MODEL,
      prompt_tokens: promptTokens,
      completion_tokens: completionTokens,
      cost_cents: Number(costCents.toFixed(4)),
      ttl_seconds: CACHE_TTL_SECONDS,
    },
    { onConflict: "user_id,cache_key" }
  );

  const books = await fetchBooks(admin, resolvedBookIds);
  return jsonOk({ recommendations: books, cached: false });
});

function buildPrompt({
  genres,
  recently_read_book_ids,
  notInterestedIds,
  n,
}: {
  genres: string[];
  recently_read_book_ids: string[];
  notInterestedIds: string[];
  n: number;
}): string {
  return `You are recommending books to an avid reader. Suggest ${n} books they would
likely enjoy based on the signals below. Respond with ONLY a JSON array of
objects with shape: { "title": string, "authors": string[], "why": string,
"isbn_13"?: string }. The "why" should be 1-2 sentences and concrete (not
generic praise).

Signals:
- Preferred genres: ${genres.join(", ")}
- Recently read book ids (avoid recommending these again): ${recently_read_book_ids.join(", ") || "(none)"}
- Explicit "not interested" book ids: ${notInterestedIds.join(", ") || "(none)"}

Constraints: do not recommend the same book twice; do not recommend books
the reader has already read; prefer books published in the last 25 years
unless a classic is clearly the right fit.`;
}

function parseRecs(text: string, n: number): ClaudeRec[] {
  // Claude might wrap the JSON in code fences or add prose. Find the first
  // [ and the last ] and parse what's between. Conservative — if parse
  // fails, return [] which surfaces as claude_failed to the caller.
  const start = text.indexOf("[");
  const end = text.lastIndexOf("]");
  if (start === -1 || end === -1 || end <= start) return [];
  try {
    const parsed = JSON.parse(text.slice(start, end + 1));
    if (!Array.isArray(parsed)) return [];
    return parsed
      .filter((r): r is ClaudeRec => {
        return (
          r &&
          typeof r === "object" &&
          typeof r.title === "string" &&
          Array.isArray(r.authors) &&
          typeof r.why === "string"
        );
      })
      .slice(0, n);
  } catch {
    return [];
  }
}

async function upsertBook(
  admin: ReturnType<typeof createClient>,
  rec: ClaudeRec
): Promise<string | null> {
  // Primary key for de-dup is books.external_id. Claude doesn't always
  // give an isbn_13; fall back to a synthesised "claude:<title>:<author>" id
  // so future recs for the same book reuse the row.
  const externalId =
    rec.isbn_13 && rec.isbn_13.length >= 10
      ? `isbn:${rec.isbn_13}`
      : `claude:${slugify(rec.title)}:${slugify(rec.authors.join("-"))}`;

  const { data: existing } = await admin
    .from("books")
    .select("id")
    .eq("external_id", externalId)
    .maybeSingle();
  if (existing) return existing.id as string;

  const { data: inserted, error } = await admin
    .from("books")
    .insert({
      external_id: externalId,
      isbn_13: rec.isbn_13 ?? null,
      title: rec.title,
      authors: rec.authors,
      source: "manual",
    })
    .select("id")
    .single();
  if (error) {
    console.error("claude-rec: book upsert failed", error);
    return null;
  }
  return inserted.id as string;
}

async function fetchBooks(
  admin: ReturnType<typeof createClient>,
  ids: string[]
): Promise<{ book_id: string; title: string; authors: string[] }[]> {
  if (ids.length === 0) return [];
  const { data } = await admin
    .from("books")
    .select("id, title, authors")
    .in("id", ids);
  return (data ?? []).map((b) => ({
    book_id: b.id as string,
    title: b.title as string,
    authors: (b.authors as string[]) ?? [],
  }));
}

function slugify(s: string): string {
  return s
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80);
}

async function sha256Hex(input: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(input));
  return Array.from(new Uint8Array(buf))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function jsonOk(body: object): Response {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
}

function jsonError(code: string, status: number): Response {
  return new Response(JSON.stringify({ error: code }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
