-- U2 RLS: book_lists, book_list_items, book_list_shares.
--
-- Affected privacy tables: book_lists, book_list_shares (book_list_items
-- inherits via composition).
-- Schema: 20260506130000 (same commit).
-- pgTAP: 15_rls_book_lists.sql (same commit).
--
-- Visibility composition: book_list_items SELECT delegates to book_lists
-- via EXISTS subquery — RLS applies recursively, so the item is visible
-- iff the parent list is visible to the caller. Same trick for the anon
-- path. This avoids re-implementing the visibility logic in two places.

alter table public.book_lists enable row level security;
alter table public.book_list_items enable row level security;
alter table public.book_list_shares enable row level security;

-- ==========================================================================
-- book_lists
-- ==========================================================================

create policy book_lists_select_authed on public.book_lists
  for select to authenticated
  using (
    owner_id = auth.uid()
    or (
      not public.fn_is_blocked(auth.uid(), owner_id)
      and (
        visibility = 'public'
        or (visibility = 'friends'
            and public.fn_friendship_status(auth.uid(), owner_id) = 'active')
        -- fn_has_list_share bypasses RLS on book_list_shares; using a
        -- raw EXISTS would recurse into book_list_shares' policy which
        -- in turn queries book_lists.
        or public.fn_has_list_share(book_lists.id, auth.uid())
      )
    )
  );

create policy book_lists_select_anon on public.book_lists
  for select to anon
  using (visibility = 'public');

create policy book_lists_insert_own on public.book_lists
  for insert to authenticated
  with check (owner_id = auth.uid());

create policy book_lists_update_own on public.book_lists
  for update to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy book_lists_delete_own on public.book_lists
  for delete to authenticated
  using (owner_id = auth.uid());

create policy book_lists_service_all on public.book_lists
  for all to service_role
  using (true)
  with check (true);

-- ==========================================================================
-- book_list_items — visibility inherits from parent list
-- ==========================================================================

create policy book_list_items_select_authed on public.book_list_items
  for select to authenticated
  using (
    exists (
      select 1 from public.book_lists bl where bl.id = book_list_items.list_id
    )
  );

create policy book_list_items_select_anon on public.book_list_items
  for select to anon
  using (
    exists (
      select 1 from public.book_lists bl where bl.id = book_list_items.list_id
    )
  );

-- Mutations: owner of the parent list only.
create policy book_list_items_insert_owner on public.book_list_items
  for insert to authenticated
  with check (
    exists (
      select 1 from public.book_lists bl
       where bl.id = book_list_items.list_id and bl.owner_id = auth.uid()
    )
  );

create policy book_list_items_update_owner on public.book_list_items
  for update to authenticated
  using (
    exists (
      select 1 from public.book_lists bl
       where bl.id = book_list_items.list_id and bl.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.book_lists bl
       where bl.id = book_list_items.list_id and bl.owner_id = auth.uid()
    )
  );

create policy book_list_items_delete_owner on public.book_list_items
  for delete to authenticated
  using (
    exists (
      select 1 from public.book_lists bl
       where bl.id = book_list_items.list_id and bl.owner_id = auth.uid()
    )
  );

create policy book_list_items_service_all on public.book_list_items
  for all to service_role
  using (true)
  with check (true);

-- ==========================================================================
-- book_list_shares
-- ==========================================================================

-- All "is the caller the owner of this list" checks below use
-- fn_user_owns_list (SECURITY DEFINER, bypasses RLS) to avoid recursing
-- into book_lists' own policy which queries book_list_shares.
create policy book_list_shares_select_party on public.book_list_shares
  for select to authenticated
  using (
    recipient_id = auth.uid()
    or public.fn_user_owns_list(book_list_shares.list_id, auth.uid())
  );

-- Owner can create shares; the recipient must not be blocked by the owner.
create policy book_list_shares_insert_owner on public.book_list_shares
  for insert to authenticated
  with check (
    public.fn_user_owns_list(book_list_shares.list_id, auth.uid())
    and not public.fn_is_blocked(auth.uid(), recipient_id)
  );

-- Owner can revoke shares; recipient can mute (delete their own share row).
create policy book_list_shares_delete_party on public.book_list_shares
  for delete to authenticated
  using (
    recipient_id = auth.uid()
    or public.fn_user_owns_list(book_list_shares.list_id, auth.uid())
  );

create policy book_list_shares_service_all on public.book_list_shares
  for all to service_role
  using (true)
  with check (true);
