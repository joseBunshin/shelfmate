// delete-account Edge Function — R23 / Apple Review §5.1.1.
//
// Required JWT claims: sub (user id), role=authenticated.
// Required environment:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_ANON_KEY
//
// Orchestration:
//   1. Authenticate the calling user via JWT.
//   2. Mark public.users.deletion_in_progress = true so the user's RLS
//      UPDATE policy (USING deletion_in_progress = false) blocks any
//      further writes during the deletion window.
//   3. (U3 follow-up) Invalidate any unconsumed Branch referrer tokens
//      issued by this user — punted because consumed_tokens lands in U3.
//   4. Delete the auth.users row via the admin API. The FK chain
//      cascades:
//        auth.users → public.users (CASCADE)
//          → privacy_settings (CASCADE)
//          → profiles (CASCADE)
//          → friendships (CASCADE both sides)
//          → user_books (CASCADE)
//          → book_lists (CASCADE) → book_list_items (CASCADE) →
//                                    book_list_shares (CASCADE)
//          → recommendations.recipient_id (CASCADE)
//          → recommendations.sender_id (SET NULL + anonymisation trigger)
//          → ai_rec_cache, ai_not_interested (CASCADE)
//          → device_tokens, notification_prefs (CASCADE)
//   5. (U7 follow-up) Emit a Sentry event for the deletion audit trail.
//
// Idempotency: a second call for the same user returns 401 because the
// JWT is invalidated by step 4. No 500-class errors should fire — repeat
// invocations are safe.

import { serve } from "https://deno.land/std@0.220.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  if (!SUPABASE_URL || !SERVICE_ROLE_KEY || !ANON_KEY) {
    return jsonError("server_misconfigured", 500);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return jsonError("missing_auth", 401);

  // Resolve the calling user via their JWT (anon-key client + Authorization header).
  const userClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userData, error: authError } = await userClient.auth.getUser();
  if (authError || !userData.user) return jsonError("invalid_jwt", 401);

  const userId = userData.user.id;

  // Service-role client bypasses RLS for the orchestration steps.
  const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Step 2: Mark deletion in progress.
  const { error: flagErr } = await adminClient
    .from("users")
    .update({ deletion_in_progress: true })
    .eq("id", userId);

  if (flagErr) {
    console.error("delete-account: failed to set deletion_in_progress", flagErr);
    return jsonError("flag_failed", 500);
  }

  // Step 4: Cascade-delete via auth admin API. This triggers all
  // FK-cascade chains in one shot.
  const { error: deleteErr } = await adminClient.auth.admin.deleteUser(userId);
  if (deleteErr) {
    console.error("delete-account: auth.admin.deleteUser failed", deleteErr);
    return jsonError("delete_failed", 500);
  }

  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});

function jsonError(code: string, status: number): Response {
  return new Response(JSON.stringify({ error: code }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
