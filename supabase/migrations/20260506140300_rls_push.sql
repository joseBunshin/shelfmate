-- U2 RLS: device_tokens, notification_prefs (v1.1 push reservation).
--
-- Strictly own-row. service_role full access for v1.1 push-send code.

alter table public.device_tokens enable row level security;
alter table public.notification_prefs enable row level security;

create policy device_tokens_select_own on public.device_tokens
  for select to authenticated
  using (user_id = auth.uid());

create policy device_tokens_insert_own on public.device_tokens
  for insert to authenticated
  with check (user_id = auth.uid());

create policy device_tokens_update_own on public.device_tokens
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy device_tokens_delete_own on public.device_tokens
  for delete to authenticated
  using (user_id = auth.uid());

create policy device_tokens_service_all on public.device_tokens
  for all to service_role
  using (true)
  with check (true);

create policy notification_prefs_select_own on public.notification_prefs
  for select to authenticated
  using (user_id = auth.uid());

create policy notification_prefs_update_own on public.notification_prefs
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy notification_prefs_service_all on public.notification_prefs
  for all to service_role
  using (true)
  with check (true);
