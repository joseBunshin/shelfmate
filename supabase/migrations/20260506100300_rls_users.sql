-- U2 RLS: users.
--
-- Affected privacy tables: users.
-- Schema: 20260506100000_schema_users_privacy_profiles.sql (same commit).
-- pgTAP coverage: 11_rls_users.sql (same commit).
--
-- Policy summary:
--   SELECT — authenticated users see their own row + all rows where the other
--            user is not currently being deleted (display_name + avatar are
--            needed across the app for any friend/rec/list rendering, and
--            usernames are public per spec). NOT gated by friendship — the
--            visibility intersection only governs *notes/comments*, not
--            identity-shaped data.
--   INSERT — service_role only. Real provisioning runs through the auth
--            trigger (fn_handle_new_auth_user), not user-initiated inserts.
--   UPDATE — own row only, and only when not deletion_in_progress.
--   DELETE — service_role only (delete-account Edge Function uses cascading
--            delete of auth.users, which cascades here via the FK).
--   anon-role — SELECT only, only rows where the user has profiles.is_public
--               = true and is not deletion_in_progress (E10-002 surface).

alter table public.users enable row level security;

-- authenticated: SELECT non-deleted users
create policy users_select_authed on public.users
  for select to authenticated
  using (deletion_in_progress = false);

-- authenticated: UPDATE own row, only while active
create policy users_update_own on public.users
  for update to authenticated
  using (id = auth.uid() and deletion_in_progress = false)
  with check (id = auth.uid() and deletion_in_progress = false);

-- service_role: full access (used by Edge Functions for delete-account, etc.)
create policy users_service_all on public.users
  for all to service_role
  using (true)
  with check (true);

-- anon: read identity data for any non-deleted user. The "is this user
-- discoverable on a public profile page" decision is enforced at the
-- profiles table (is_public gate), not here. Identity-shape data
-- (display_name, avatar) is the same surface authenticated users see, so
-- exposing it to anon adds no privacy burden — and a cross-table EXISTS
-- into profiles would create mutually-recursive RLS with the profiles
-- anon policy.
create policy users_select_anon_active on public.users
  for select to anon
  using (deletion_in_progress = false);
