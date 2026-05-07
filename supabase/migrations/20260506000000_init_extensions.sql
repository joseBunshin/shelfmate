-- U1 init migration. Loads the Postgres extensions the v1 architecture
-- depends on. Per AGENTS.md migration discipline, no privacy-affected
-- table is created here, so no RLS update is required in this commit.
--
-- Extensions:
--   pgcrypto — gen_random_uuid() for primary keys; password hashing helpers
--   pg_net   — async HTTP from Postgres; used by U7's revalidation trigger
--              (book_lists.visibility UPDATE → POST to Vercel /api/revalidate)
--   http     — synchronous HTTP for diagnostic queries (rarely used; kept off
--              the critical path because it blocks the connection)
--
-- pgTAP is loaded by `supabase test db` against the local stack, not in
-- production migrations.

create extension if not exists pgcrypto with schema extensions;
create extension if not exists pg_net with schema extensions;
create extension if not exists http with schema extensions;
