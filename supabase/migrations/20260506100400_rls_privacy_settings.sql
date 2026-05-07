-- U2 RLS: privacy_settings.
--
-- Affected privacy tables: privacy_settings.
-- Schema: 20260506100000_schema_users_privacy_profiles.sql (same commit).
-- pgTAP coverage: 12_rls_privacy_settings.sql (same commit).
--
-- Policy summary:
--   SELECT — own row only, even for authenticated users. Other users' privacy
--            settings are NOT a public read surface; they are accessed only
--            via the SECURITY DEFINER fn_can_see_comment, which performs its
--            own server-side lookup.
--   INSERT/UPDATE — own row only.
--   DELETE — never via the API. Cascades from users delete only.
--   anon-role — no access.
--   service_role — full access (needed by fn_can_see_comment via SECURITY
--                  DEFINER and by the auth provisioning trigger).

alter table public.privacy_settings enable row level security;

create policy privacy_settings_select_own on public.privacy_settings
  for select to authenticated
  using (user_id = auth.uid());

create policy privacy_settings_insert_own on public.privacy_settings
  for insert to authenticated
  with check (user_id = auth.uid());

create policy privacy_settings_update_own on public.privacy_settings
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy privacy_settings_service_all on public.privacy_settings
  for all to service_role
  using (true)
  with check (true);
