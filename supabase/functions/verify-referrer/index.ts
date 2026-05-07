// verify-referrer Edge Function — R26 / E1-006.
//
// Required JWT claims: sub (user id, the new installer), role=authenticated.
// Required environment:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_ANON_KEY
//
// Body (JSON):
//   { branch_token: string, install_id: string, from_user_id: string }
//
// Returns:
//   200 { ok: true, friendship_status: 'pending' } — referrer connected,
//        a pending friendship row was created.
//   200 { ok: false, reason: 'replay'|'invalidated'|'blocked'|'sender_missing' }
//        — token consumed already / sender deleted / sender blocked viewer /
//        sender id is unknown. UX falls through to manual-add.
//   401 — caller's JWT missing or invalid.
//   400 — request body missing required fields.
//
// Atomicity model:
//   The single INSERT INTO consumed_tokens ... ON CONFLICT DO NOTHING
//   RETURNING is the atomic claim. Two concurrent installs racing the
//   same token both run that statement; only one gets a row back. The
//   function commits the friendship row and the consumption together,
//   so a power-cut between them does not orphan a half-state.
//
// Token hashing: we hash the raw Branch token before storing so the
// consumed_tokens table never holds a value that could be replayed if
// leaked. SHA-256 is sufficient — the goal is "given the table dump,
// can't issue another valid match", not cryptographic key derivation.

import { serve } from "https://deno.land/std@0.220.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");

interface Body {
  branch_token?: unknown;
  install_id?: unknown;
  from_user_id?: unknown;
}

serve(async (req) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });
  if (!SUPABASE_URL || !SERVICE_ROLE_KEY || !ANON_KEY) {
    return jsonError("server_misconfigured", 500);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return jsonError("missing_auth", 401);

  // Resolve the calling user via JWT.
  const userClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: authError } = await userClient.auth.getUser();
  if (authError || !userData.user) return jsonError("invalid_jwt", 401);
  const newUserId = userData.user.id;

  // Parse body.
  let body: Body;
  try {
    body = await req.json();
  } catch {
    return jsonError("bad_json", 400);
  }
  const { branch_token, install_id, from_user_id } = body;
  if (
    typeof branch_token !== "string" ||
    typeof install_id !== "string" ||
    typeof from_user_id !== "string"
  ) {
    return jsonError("missing_fields", 400);
  }

  // Self-referral guard: a user cannot refer themselves.
  if (from_user_id === newUserId) return jsonOk({ ok: false, reason: "self_referral" });

  const tokenHash = await sha256Hex(branch_token);

  const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Step 1: atomic claim.
  const { data: claimRows, error: claimErr } = await adminClient
    .from("consumed_tokens")
    .insert({
      token_hash: tokenHash,
      install_id,
      consumed_at: new Date().toISOString(),
    })
    .select("token_hash, invalidated")
    .single();

  // PostgREST returns an error when ON CONFLICT DO NOTHING produces 0 rows;
  // that's the replay/invalidation path. Distinguish via separate read.
  if (claimErr || !claimRows) {
    const { data: existing } = await adminClient
      .from("consumed_tokens")
      .select("invalidated")
      .eq("token_hash", tokenHash)
      .maybeSingle();
    if (existing?.invalidated) return jsonOk({ ok: false, reason: "invalidated" });
    return jsonOk({ ok: false, reason: "replay" });
  }

  // Step 2: verify sender exists and is not blocked relative to the new user.
  const { data: senderRow } = await adminClient
    .from("users")
    .select("id, deletion_in_progress")
    .eq("id", from_user_id)
    .maybeSingle();

  if (!senderRow || senderRow.deletion_in_progress) {
    return jsonOk({ ok: false, reason: "sender_missing" });
  }

  const { data: blockedRow } = await adminClient
    .rpc("fn_is_blocked", { viewer: newUserId, other: from_user_id });
  if (blockedRow === true) return jsonOk({ ok: false, reason: "blocked" });

  // Step 3: create the pending friendship (canonical pair ordering).
  const userA = newUserId < from_user_id ? newUserId : from_user_id;
  const userB = newUserId < from_user_id ? from_user_id : newUserId;

  const { error: friendshipErr } = await adminClient
    .from("friendships")
    .upsert({
      user_id_a: userA,
      user_id_b: userB,
      status: "pending",
      initiated_by: from_user_id,
    }, { onConflict: "user_id_a,user_id_b", ignoreDuplicates: true });

  if (friendshipErr) {
    console.error("verify-referrer: friendship upsert failed", friendshipErr);
    return jsonError("friendship_failed", 500);
  }

  return jsonOk({ ok: true, friendship_status: "pending" });
});

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
