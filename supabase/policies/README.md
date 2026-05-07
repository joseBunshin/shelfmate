# RLS policy documentation

This directory holds documented copies of the RLS policies that govern
access to privacy-affected tables. CI applies policies via the
`migrations/` directory (Supabase replays migrations on every deploy);
this `policies/` directory exists for review and onboarding clarity —
one file per table.

Convention: `policies/<table>.sql` contains all RLS policies for that
table — anon-role + authenticated + service-role.

Per AGENTS.md privacy-affected migration discipline, every migration
that touches one of these tables MUST include an accompanying RLS
policy update in the same commit. The pgTAP suite in `supabase/tests/`
gates this at CI merge time.

Tables landing in U2:
- `users.sql`, `privacy_settings.sql`, `profiles.sql`
- `comments.sql`, `user_books.sql`, `friendships.sql`
- `book_lists.sql`, `book_list_shares.sql`, `recommendations.sql`
- `ai_rec_cache.sql`, `consumed_tokens.sql`
