-- U2 RLS: profiles.
--
-- Affected privacy tables: profiles.
-- Schema: 20260506100000_schema_users_privacy_profiles.sql (same commit).
-- pgTAP coverage: 13_rls_profiles.sql (same commit).
--
-- Policy summary:
--   SELECT — authenticated users see any profile where the owner is active
--            and either is_public = true OR they are friends. Block-before-
--            intersection still applies: blocked users cannot read each
--            other's profiles.
--   INSERT — service_role only (auth trigger).
--   UPDATE — own row only.
--   DELETE — cascades from users only.
--   anon-role — only is_public profiles where the owner is active. Used by
--               E10-002 (Social Discovery) and E10-003 (Inviter Profile).

alter table public.profiles enable row level security;

create policy profiles_select_authed on public.profiles
  for select to authenticated
  using (
    -- own profile always visible
    user_id = auth.uid()
    or (
      not public.fn_is_blocked(auth.uid(), user_id)
      and exists (
        select 1 from public.users u
         where u.id = profiles.user_id and u.deletion_in_progress = false
      )
      and (
        is_public = true
        or public.fn_friendship_status(auth.uid(), user_id) = 'active'
      )
    )
  );

create policy profiles_update_own on public.profiles
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy profiles_select_anon_public on public.profiles
  for select to anon
  using (
    is_public = true
    and exists (
      select 1 from public.users u
       where u.id = profiles.user_id and u.deletion_in_progress = false
    )
  );

create policy profiles_service_all on public.profiles
  for all to service_role
  using (true)
  with check (true);
