-- U2 RLS: recommendations.
--
-- Affected privacy tables: recommendations.
-- Schema: 20260506120000 (same commit).
-- pgTAP: 14_rls_recommendations.sql (same commit).
--
-- Policy summary:
--   SELECT (authenticated) — sender OR recipient sees the row
--   SELECT (anon)          — full read access. Security model: UUIDs are
--                            unguessable. The E10-001 landing renders by
--                            specific recId from the deep link. PostgREST
--                            will not return a row without an id filter
--                            because there's no list endpoint exposed to anon.
--   INSERT (authenticated) — sender_id = auth.uid() AND friends with
--                            recipient (active friendship) AND not blocked.
--                            CHECK enforces; clients cannot forge sender.
--   UPDATE (authenticated) — recipient may transition status (viewed →
--                            finished | declined). Sender cannot modify
--                            after send.
--   DELETE (authenticated) — sender or recipient may delete their copy
--   service_role           — full

alter table public.recommendations enable row level security;

create policy recommendations_select_party on public.recommendations
  for select to authenticated
  using (auth.uid() in (sender_id, recipient_id));

create policy recommendations_select_anon on public.recommendations
  for select to anon
  using (true);

create policy recommendations_insert_friend on public.recommendations
  for insert to authenticated
  with check (
    sender_id = auth.uid()
    and recipient_id <> sender_id
    and not public.fn_is_blocked(sender_id, recipient_id)
    and public.fn_friendship_status(sender_id, recipient_id) = 'active'
  );

create policy recommendations_update_recipient on public.recommendations
  for update to authenticated
  using (recipient_id = auth.uid())
  with check (recipient_id = auth.uid());

create policy recommendations_delete_party on public.recommendations
  for delete to authenticated
  using (auth.uid() in (sender_id, recipient_id));

create policy recommendations_service_all on public.recommendations
  for all to service_role
  using (true)
  with check (true);
