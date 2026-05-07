-- U2 RLS: user_books.
--
-- Affected privacy tables: user_books.
-- Schema: 20260506110100 (same commit).
-- Visibility helper: fn_can_see_comment in 20260506110200 (same commit).
-- pgTAP: 13_rls_user_books.sql (same commit).
--
-- Policy summary:
--   SELECT — own rows always; others' rows iff fn_can_see_comment passes.
--            The whole row is gated together (status + rating + note); no
--            partial visibility split in v1.
--   INSERT — own row only.
--   UPDATE — own row only.
--   DELETE — own row only.
--   anon-role — only rows where the writer's writer_setting = 'everyone',
--               via the same fn_can_see_comment with viewer = NULL.
--   service_role — full access.

alter table public.user_books enable row level security;

create policy user_books_select_visible on public.user_books
  for select to authenticated
  using (public.fn_can_see_comment(auth.uid(), user_id));

create policy user_books_insert_own on public.user_books
  for insert to authenticated
  with check (user_id = auth.uid());

create policy user_books_update_own on public.user_books
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy user_books_delete_own on public.user_books
  for delete to authenticated
  using (user_id = auth.uid());

create policy user_books_select_anon on public.user_books
  for select to anon
  using (public.fn_can_see_comment(null, user_id));

create policy user_books_service_all on public.user_books
  for all to service_role
  using (true)
  with check (true);
