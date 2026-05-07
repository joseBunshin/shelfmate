-- U2 helper functions for book_lists / book_list_shares RLS.
--
-- The cross-table EXISTS subqueries between book_lists and book_list_shares
-- create infinite RLS recursion: book_lists policy queries book_list_shares,
-- which has its own RLS that queries book_lists, which queries book_list_shares
-- again, and so on. Postgres detects this and aborts the policy with
-- "infinite recursion detected in policy for relation".
--
-- Two SECURITY DEFINER helpers break the cycle by reading the target table
-- under the function owner's privileges (owner bypasses RLS). Each helper
-- takes both ids as parameters so callers can't tamper with the lookup.

create or replace function public.fn_user_owns_list(p_list_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.book_lists
     where id = p_list_id and owner_id = p_user_id
  );
$$;

create or replace function public.fn_has_list_share(p_list_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.book_list_shares
     where list_id = p_list_id and recipient_id = p_user_id
  );
$$;

comment on function public.fn_user_owns_list(uuid, uuid) is
  'Owner check that bypasses RLS so book_list_shares policies can reference book_lists ownership without recursion.';
comment on function public.fn_has_list_share(uuid, uuid) is
  'Share-recipient check that bypasses RLS so book_lists policies can reference book_list_shares without recursion.';
