// Supabase client for the web project.
//
// CRITICAL: This file uses ONLY the anon key. The service-role key must
// NEVER be configured in the Vercel project's environment variables (per
// AGENTS.md and plan U7). Anon-role RLS policies on the privacy-affected
// tables enforce visibility for the non-user surface.
//
// U1.3 wires SUPABASE_PROJECT_URL + NEXT_PUBLIC_SUPABASE_ANON_KEY from
// Vercel env vars; until then, the client is constructed lazily and any
// import-time access throws so misconfiguration surfaces loudly.

import { createClient, SupabaseClient } from "@supabase/supabase-js";

let _client: SupabaseClient | null = null;

export function getSupabaseAnonClient(): SupabaseClient {
  if (_client) return _client;

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!url || !anonKey) {
    throw new Error(
      "Supabase env vars missing. Set NEXT_PUBLIC_SUPABASE_URL and " +
        "NEXT_PUBLIC_SUPABASE_ANON_KEY in Vercel project settings (per env). " +
        "DO NOT set SUPABASE_SERVICE_ROLE_KEY in this project."
    );
  }

  _client = createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return _client;
}
