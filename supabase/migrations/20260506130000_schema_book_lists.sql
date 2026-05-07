-- U2 schema: book_lists, book_list_items, book_list_shares.
--
-- Affected privacy tables: book_lists, book_list_shares.
-- (book_list_items inherits visibility from its parent list — RLS reads from
-- book_lists which applies its own policy. Privacy-affected by transitive
-- composition rather than direct policy.)
-- RLS: 20260506130100 (same commit).
-- pgTAP: 15_rls_book_lists.sql (same commit).
--
-- Visibility rules (E6 + E10-004):
--   private  — owner only
--   friends  — owner + active friends + listed in book_list_shares
--   public   — everyone, including anon (E10-004 conversion surface)
--
-- Block-before-intersection: a user blocked by the owner sees nothing,
-- regardless of visibility setting or share row presence.
--
-- Reordering: book_list_items.position is advisory — index for sort order
-- only, no UNIQUE so reordering swaps don't trip a constraint mid-batch.

create type public.book_list_visibility as enum ('private', 'friends', 'public');

create table public.book_lists (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.users(id) on delete cascade,
  title text not null check (length(title) between 1 and 100),
  description text check (description is null or length(description) <= 1000),
  visibility public.book_list_visibility not null default 'private',
  cover_book_id uuid references public.books(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index book_lists_owner_idx on public.book_lists (owner_id, updated_at desc);
create index book_lists_public_idx on public.book_lists (id) where visibility = 'public';

create trigger book_lists_updated_at before update on public.book_lists
  for each row execute function public.tg_set_updated_at();

create table public.book_list_items (
  list_id uuid not null references public.book_lists(id) on delete cascade,
  book_id uuid not null references public.books(id) on delete cascade,
  position int not null default 0,
  note text check (note is null or length(note) <= 500),
  added_at timestamptz not null default now(),
  primary key (list_id, book_id)
);

create index book_list_items_position_idx on public.book_list_items (list_id, position);

create table public.book_list_shares (
  list_id uuid not null references public.book_lists(id) on delete cascade,
  recipient_id uuid not null references public.users(id) on delete cascade,
  shared_at timestamptz not null default now(),
  primary key (list_id, recipient_id)
);

create index book_list_shares_recipient_idx on public.book_list_shares (recipient_id);

comment on table public.book_lists is
  'User-curated reading lists. visibility: private | friends | public. R11: visibility flips trigger E10-004 SSR cache invalidation (handled in U7 via pg_net trigger).';
comment on table public.book_list_items is
  'Items within a list. position is advisory (clients sort by it; no UNIQUE so reorder swaps do not trip mid-batch).';
comment on table public.book_list_shares is
  'Friends-only or private lists shared with specific recipients. Owner controls share; recipient sees the list as if friends-visible.';
