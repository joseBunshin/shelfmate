-- U2 schema: recommendations.
--
-- Affected privacy tables: recommendations.
-- RLS: 20260506120100_rls_recommendations.sql (same commit).
-- Anonymisation trigger: 20260506120200 (same commit).
-- pgTAP: 14_rls_recommendations.sql (same commit).
--
-- Recommendation = "{sender} sent {recipient} the book {book} with {note}".
-- One book, one friend (E5 spec). Friends-only at INSERT (RLS WITH CHECK
-- requires fn_friendship_status = 'active'). Recipient can transition
-- status (viewed → finished/declined); sender cannot modify after send.
--
-- Sender deletion path (R23, plan U2 delete-account): sender_id FK is
-- ON DELETE SET NULL, and an UPDATE trigger anonymises
-- sender_display_name_snapshot the moment sender_id transitions to NULL.
-- The recipient still sees the rec; the rec just shows "A ShelfMate user"
-- as the sender. This preserves the recipient's reading queue across the
-- sender's account deletion without leaking the deleted user's identity.

create type public.recommendation_status as enum (
  'sent',       -- delivered, recipient has not opened
  'viewed',     -- recipient opened the rec
  'finished',   -- recipient marked the book finished
  'declined'    -- recipient declined / not interested
);

create table public.recommendations (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid references public.users(id) on delete set null,
  recipient_id uuid not null references public.users(id) on delete cascade,
  book_id uuid not null references public.books(id) on delete cascade,
  note text not null check (length(note) between 1 and 1000),
  -- snapshot taken at INSERT; anonymised by trigger if sender_id later → NULL
  sender_display_name_snapshot text not null,
  -- R12: Supabase Storage URL ONLY. Raw OL/GB URLs are never embedded in
  -- recommendations because the row is rendered on E10-001 and any
  -- third-party-CDN compromise would inject into a ShelfMate landing page.
  cover_storage_url text,
  status public.recommendation_status not null default 'sent',
  created_at timestamptz not null default now(),
  viewed_at timestamptz,
  finished_at timestamptz,
  constraint recommendations_no_self check (
    sender_id is null or sender_id <> recipient_id
  ),
  constraint recommendations_viewed_at_status check (
    viewed_at is null or status in ('viewed', 'finished', 'declined')
  ),
  constraint recommendations_finished_at_status check (
    finished_at is null or status = 'finished'
  )
);

create index recommendations_recipient_status_idx
  on public.recommendations (recipient_id, status, created_at desc);
create index recommendations_sender_idx
  on public.recommendations (sender_id, created_at desc)
  where sender_id is not null;

comment on table public.recommendations is
  'One-friend-to-one-friend book rec (E5). Friends-only INSERT. Sender deletion anonymises sender_display_name_snapshot via trigger; sender_id FK is ON DELETE SET NULL.';
comment on column public.recommendations.cover_storage_url is
  'R12 invariant: Supabase Storage URL only. proxy-cover Edge Function (U4/U5) populates this at rec creation time. Raw third-party URLs are never embedded.';
