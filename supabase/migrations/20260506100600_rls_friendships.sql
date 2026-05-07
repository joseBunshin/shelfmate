-- U2 RLS: friendships.
--
-- Affected privacy tables: friendships.
-- Schema: 20260506100100_schema_friendships.sql (same commit).
-- pgTAP coverage: 14_rls_friendships.sql (same commit).
--
-- Policy summary:
--   SELECT — only rows the caller is part of (user_id_a or user_id_b matches
--            auth.uid()). Friendship rows are private to the pair.
--   INSERT — caller must be the initiator and a member of the pair, status
--            must be 'pending'. Active/blocked rows are created via UPDATE
--            transitions, not direct INSERT.
--   UPDATE — only the pair members can mutate. blocked_by must be set
--            consistently with status (CHECK constraint also enforces).
--   DELETE — pair members only (un-friend = delete row; block uses UPDATE).
--   anon-role — no access.
--   service_role — full access.

alter table public.friendships enable row level security;

create policy friendships_select_pair on public.friendships
  for select to authenticated
  using (auth.uid() in (user_id_a, user_id_b));

create policy friendships_insert_initiator on public.friendships
  for insert to authenticated
  with check (
    auth.uid() in (user_id_a, user_id_b)
    and initiated_by = auth.uid()
    and status = 'pending'
  );

create policy friendships_update_pair on public.friendships
  for update to authenticated
  using (auth.uid() in (user_id_a, user_id_b))
  with check (auth.uid() in (user_id_a, user_id_b));

create policy friendships_delete_pair on public.friendships
  for delete to authenticated
  using (auth.uid() in (user_id_a, user_id_b));

create policy friendships_service_all on public.friendships
  for all to service_role
  using (true)
  with check (true);
