// proxy-cover Edge Function — R12 invariant.
//
// Required JWT claims: sub (user id), role=authenticated.
// Required environment: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_ANON_KEY
//
// Body (JSON):
//   { book_id: uuid, source_url: string }
//
// Returns:
//   200 { storage_url: string }   — the canonical Supabase Storage URL
//   200 { storage_url: string, cached: true } — already proxied
//   400 { error: 'bad_request' }
//   401 { error: 'invalid_jwt' }
//   415 { error: 'unsupported_content_type' } — source returned non-image
//   502 { error: 'fetch_failed' }              — source URL refused/errored
//
// R12: never embed raw third-party URLs (Open Library, Google Books) in
// recommendation rows. Call this function at rec creation, store the
// returned storage_url on the rec.
//
// Idempotency: re-calling for a book_id whose covers/<book_id>.<ext>
// object already exists is a fast-path return — no second download, no
// second upload. The book's books.cover_storage_url is also updated as
// a side-effect, mirroring the Storage URL into the books cache row.

import { serve } from "https://deno.land/std@0.220.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");

const ALLOWED_MIME = new Set(["image/jpeg", "image/png", "image/webp"]);
const MAX_BYTES = 5 * 1024 * 1024;

interface Body {
  book_id?: unknown;
  source_url?: unknown;
}

serve(async (req) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });
  if (!SUPABASE_URL || !SERVICE_ROLE_KEY || !ANON_KEY) {
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

  let body: Body;
  try {
    body = await req.json();
  } catch {
    return jsonError("bad_json", 400);
  }
  const { book_id, source_url } = body;
  if (typeof book_id !== "string" || typeof source_url !== "string") {
    return jsonError("bad_request", 400);
  }

  // Validate source URL — only http(s), only OL/GB hosts. Defense against
  // SSRF: this function runs with service_role, so an attacker-controlled
  // URL could otherwise scan internal endpoints.
  let url: URL;
  try {
    url = new URL(source_url);
  } catch {
    return jsonError("bad_source_url", 400);
  }
  if (!isAllowedHost(url)) return jsonError("disallowed_host", 400);

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Fast path: already cached?
  const { data: existingBook } = await admin
    .from("books")
    .select("cover_storage_url")
    .eq("id", book_id)
    .maybeSingle();
  if (existingBook?.cover_storage_url) {
    return jsonOk({ storage_url: existingBook.cover_storage_url, cached: true });
  }

  // Fetch the source image.
  let sourceResp: Response;
  try {
    sourceResp = await fetch(source_url, { redirect: "follow" });
  } catch {
    return jsonError("fetch_failed", 502);
  }
  if (!sourceResp.ok) return jsonError("fetch_failed", 502);

  const contentType = (sourceResp.headers.get("content-type") || "").split(";")[0]!.trim();
  if (!ALLOWED_MIME.has(contentType)) return jsonError("unsupported_content_type", 415);

  const arrayBuffer = await sourceResp.arrayBuffer();
  if (arrayBuffer.byteLength > MAX_BYTES) return jsonError("too_large", 413);

  const ext = mimeToExt(contentType);
  const path = `${book_id}.${ext}`;

  // Magic-bytes verification — the content-type header is hint-only;
  // verify the bytes match the claimed MIME so a server returning
  // image/jpeg headers can't sneak through arbitrary bytes.
  if (!matchesMagicBytes(new Uint8Array(arrayBuffer), contentType)) {
    return jsonError("bytes_dont_match_mime", 415);
  }

  const { error: uploadErr } = await admin.storage.from("covers").upload(path, arrayBuffer, {
    contentType,
    upsert: true,
  });
  if (uploadErr) {
    console.error("proxy-cover upload failed", uploadErr);
    return jsonError("upload_failed", 500);
  }

  const { data: pub } = admin.storage.from("covers").getPublicUrl(path);
  const storageUrl = pub.publicUrl;

  await admin.from("books").update({ cover_storage_url: storageUrl }).eq("id", book_id);

  return jsonOk({ storage_url: storageUrl });
});

function isAllowedHost(url: URL): boolean {
  if (url.protocol !== "https:") return false;
  const host = url.hostname.toLowerCase();
  return (
    host === "covers.openlibrary.org" ||
    host === "books.google.com" ||
    host.endsWith(".googleusercontent.com")
  );
}

function mimeToExt(mime: string): string {
  if (mime === "image/jpeg") return "jpg";
  if (mime === "image/png") return "png";
  if (mime === "image/webp") return "webp";
  return "bin";
}

// Inspect first bytes against MIME signatures. Returns true when bytes
// match the claimed type. JPEG: FF D8 FF. PNG: 89 50 4E 47 0D 0A 1A 0A.
// WebP: bytes 0..3 = "RIFF", 8..11 = "WEBP".
function matchesMagicBytes(bytes: Uint8Array, mime: string): boolean {
  if (bytes.length < 12) return false;
  if (mime === "image/jpeg") {
    return bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  }
  if (mime === "image/png") {
    return (
      bytes[0] === 0x89 &&
      bytes[1] === 0x50 &&
      bytes[2] === 0x4e &&
      bytes[3] === 0x47 &&
      bytes[4] === 0x0d &&
      bytes[5] === 0x0a &&
      bytes[6] === 0x1a &&
      bytes[7] === 0x0a
    );
  }
  if (mime === "image/webp") {
    const ascii = (b: number) => String.fromCharCode(b);
    return (
      ascii(bytes[0]!) + ascii(bytes[1]!) + ascii(bytes[2]!) + ascii(bytes[3]!) === "RIFF" &&
      ascii(bytes[8]!) + ascii(bytes[9]!) + ascii(bytes[10]!) + ascii(bytes[11]!) === "WEBP"
    );
  }
  return false;
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
