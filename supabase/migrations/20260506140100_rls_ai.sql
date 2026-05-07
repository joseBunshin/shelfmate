-- U2 RLS: ai_rec_cache, ai_not_interested.
--
-- Both tables are strictly own-row. There's no cross-user visibility — AI
-- rec history is per-user and not shared with friends. service_role has
-- full access for the claude-rec Edge Function (lands in U6).

alter table public.ai_rec_cache enable row level security;
alter table public.ai_not_interested enable row level security;

create policy ai_rec_cache_select_own on public.ai_rec_cache
  for select to authenticated
  using (user_id = auth.uid());

create policy ai_rec_cache_insert_own on public.ai_rec_cache
  for insert to authenticated
  with check (user_id = auth.uid());

create policy ai_rec_cache_delete_own on public.ai_rec_cache
  for delete to authenticated
  using (user_id = auth.uid());

create policy ai_rec_cache_service_all on public.ai_rec_cache
  for all to service_role
  using (true)
  with check (true);

create policy ai_not_interested_select_own on public.ai_not_interested
  for select to authenticated
  using (user_id = auth.uid());

create policy ai_not_interested_insert_own on public.ai_not_interested
  for insert to authenticated
  with check (user_id = auth.uid());

create policy ai_not_interested_delete_own on public.ai_not_interested
  for delete to authenticated
  using (user_id = auth.uid());

create policy ai_not_interested_service_all on public.ai_not_interested
  for all to service_role
  using (true)
  with check (true);
