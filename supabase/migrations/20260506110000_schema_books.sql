-- U2 schema: books cache.
--
-- Affected privacy tables: none. books holds book metadata only and is a
-- public read surface. RLS exists for write-path hardening (only authenticated
-- users can INSERT new books; UPDATE/DELETE limited to service_role to
-- prevent metadata vandalism).
--
-- Rows are de-duplicated by external_id (e.g. "openlibrary:OL12345W"). The
-- proxy-cover Edge Function (lands in U4/U5) populates cover_storage_url
-- after fetching from OL/GB and re-hosting in Supabase Storage. Until that
-- function ships, cover_storage_url stays NULL and the app renders covers
-- directly from the cached_network_image-cached OL URL.

create table public.books (
  id uuid primary key default gen_random_uuid(),
  external_id text not null unique,
  isbn_13 text unique,
  isbn_10 text,
  title text not null check (length(title) between 1 and 500),
  authors text[] not null default array[]::text[],
  cover_storage_url text,                          -- populated by proxy-cover (R12)
  publication_year int check (publication_year is null or publication_year between 1 and extract(year from now())::int + 5),
  description text,
  source text not null check (source in ('openlibrary', 'googlebooks', 'manual')),
  cached_at timestamptz not null default now()
);

create index books_isbn_13_idx on public.books (isbn_13) where isbn_13 is not null;
-- to_tsvector(regconfig, text) is IMMUTABLE; the (text, text) form is STABLE
-- and rejected for index expressions. Cast the literal so the resolver picks
-- the regconfig overload.
create index books_title_authors_idx on public.books using gin (
  to_tsvector('english'::regconfig, title || ' ' || array_to_string(authors, ' '))
);

comment on table public.books is
  'Public cache of book metadata from Open Library / Google Books. Public read; INSERT for authenticated users; UPDATE/DELETE service_role only.';
comment on column public.books.cover_storage_url is
  'R12: Supabase Storage URL after proxy-cover re-hosting. Raw third-party URLs are never embedded in Recommendation rows.';

-- ==========================================================================
-- RLS for books
-- ==========================================================================

alter table public.books enable row level security;

create policy books_select_all on public.books
  for select to authenticated, anon
  using (true);

create policy books_insert_authed on public.books
  for insert to authenticated
  with check (true);

create policy books_service_all on public.books
  for all to service_role
  using (true)
  with check (true);
