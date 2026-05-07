-- U2 schema: user_books.
--
-- Affected privacy tables: user_books (the spec's "Comment" column lives here
-- as `note` — buildspec data model treats per-book notes as a property of the
-- shelving record, not a separate Comment object).
-- RLS: 20260506110300_rls_user_books.sql (same commit).
-- Visibility helper: fn_can_see_comment in 20260506110200 (same commit).
-- pgTAP: 12_visibility_intersection.sql + 13_rls_user_books.sql (same commit).
--
-- Per-row gate: fn_can_see_comment(viewer, owner) — gates both row existence
-- and column reads. If a friend can see the row, they see status + rating +
-- note as a unit. There is no v1 mechanism to share status without sharing
-- the note: that finer grain would require a separate `note_visibility`
-- column overriding the writer's per-user setting, which is a follow-up.

create type public.user_book_status as enum (
  'reading',       -- E2-007 Reading shelf
  'read',          -- E2-005 finished
  'want_to_read',  -- E2-006 backlog
  'dropped'        -- E2-009 abandoned
);

create table public.user_books (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  book_id uuid not null references public.books(id) on delete cascade,
  status public.user_book_status not null,
  -- 0.5..5.0 in 0.5 increments per E2-005 half-star spec
  rating numeric(2,1) check (
    rating is null
    or (rating >= 0.5 and rating <= 5.0 and (rating * 2) = floor(rating * 2))
  ),
  note text check (note is null or length(note) <= 5000),
  progress_page int check (progress_page is null or progress_page >= 0),
  finished_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, book_id),
  -- finished_at must be set iff status='read' (don't enforce strictly to
  -- allow reads without a recorded finish date, but require status alignment
  -- when finished_at is set)
  constraint user_books_finished_at_status check (
    finished_at is null or status = 'read'
  )
);

create index user_books_user_status_idx on public.user_books (user_id, status);
create index user_books_book_idx on public.user_books (book_id);
create index user_books_user_finished_idx on public.user_books (user_id, finished_at desc)
  where status = 'read';

create trigger user_books_updated_at before update on public.user_books
  for each row execute function public.tg_set_updated_at();

comment on table public.user_books is
  'Per-user shelving record. status enum: reading | read | want_to_read | dropped. Rating: 0.5-5.0 half-stars. Note text is the spec''s "Comment" — gated by fn_can_see_comment (intersection of writer + viewer privacy_settings, block-before-intersection).';
