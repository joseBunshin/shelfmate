-- U2 schema: users, privacy_settings, profiles.
--
-- Affected privacy tables: users, privacy_settings, profiles.
-- RLS policies: see migrations 20260506100400 / 100500 / 100600 (same commit).
--
-- Three tables in one migration because they share a 1-to-1 lifecycle anchored
-- to auth.users — creating any one without the others would leave a partial
-- identity record, which the auth trigger in 20260506100200 needs all three of.
--
-- Privacy semantics (per buildspec data model + plan U2):
--   privacy_settings.writer_setting — who can SEE this user's comments/notes
--   privacy_settings.viewer_setting — whose comments/notes this user wants to SEE
--   "More restrictive wins" intersection is computed in fn_can_see_comment
--   (lands with user_books in a later U2 migration).

-- ==========================================================================
-- users — public mirror of auth.users with profile-shaped data
-- ==========================================================================
-- One row per Supabase Auth user. Created by the on_auth_user_created trigger
-- (20260506100200). RLS enabled; policies in 20260506100300_rls_users.sql.

create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (length(display_name) between 1 and 50),
  username citext unique check (
    username is null
    or (length(username) between 3 and 30 and username ~ '^[a-z0-9_]+$')
  ),
  avatar_storage_path text,                      -- supabase storage path; null = default avatar
  genre_preferences jsonb not null default '[]'::jsonb,  -- E1-005 onboarding picks
  deletion_in_progress boolean not null default false,   -- R23: set true during delete-account orchestration
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- citext extension powers case-insensitive usernames; load it now (idempotent).
create extension if not exists citext with schema extensions;

create index users_username_idx on public.users (username) where username is not null;
create index users_active_idx on public.users (id) where deletion_in_progress = false;

comment on table public.users is
  'Public mirror of auth.users. One row per authenticated user. RLS-protected.';
comment on column public.users.deletion_in_progress is
  'R23: set by delete-account Edge Function before cascading deletes; blocks all writes by this user during deletion.';

-- ==========================================================================
-- privacy_settings — writer + viewer settings per user
-- ==========================================================================
-- The trust seam. Both settings looked up server-side inside fn_can_see_comment
-- so neither client can spoof them via session-state APIs (current_setting,
-- set_config). Defaults to most-permissive (Everyone) so absent settings don't
-- silently hide content the user expected to be public.

create type public.privacy_audience as enum ('everyone', 'friends', 'only_me');

create table public.privacy_settings (
  user_id uuid primary key references public.users(id) on delete cascade,
  writer_setting public.privacy_audience not null default 'everyone',
  viewer_setting public.privacy_audience not null default 'everyone',
  updated_at timestamptz not null default now()
);

comment on table public.privacy_settings is
  'Per-user privacy. writer_setting = who sees my notes; viewer_setting = whose notes I see. Intersection is "more restrictive wins" — see fn_can_see_comment.';

-- ==========================================================================
-- profiles — extended profile data (bio, public toggles)
-- ==========================================================================
-- Separate from public.users to keep the hot identity row narrow. Profile
-- fields are read on Book Detail / Public Profile (E10-002) and are nullable.

create table public.profiles (
  user_id uuid primary key references public.users(id) on delete cascade,
  bio text check (bio is null or length(bio) <= 280),
  is_public boolean not null default true,        -- E10-002 anon-role visibility gate
  updated_at timestamptz not null default now()
);

comment on table public.profiles is
  'Extended profile fields. is_public gates E10-002 (Social Discovery) anon-role visibility — must be true AND user has not been blocked by viewer.';

-- ==========================================================================
-- updated_at trigger (shared across the three tables)
-- ==========================================================================

create or replace function public.tg_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger users_updated_at before update on public.users
  for each row execute function public.tg_set_updated_at();
create trigger privacy_settings_updated_at before update on public.privacy_settings
  for each row execute function public.tg_set_updated_at();
create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.tg_set_updated_at();
