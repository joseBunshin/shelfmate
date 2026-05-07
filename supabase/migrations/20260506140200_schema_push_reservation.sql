-- U2 v1.1 push-notification schema reservation (per origin Dependencies).
--
-- v1 ships these tables empty + RLS-protected so future push-notification
-- code can land without retrofit-style migrations on a populated DB.
-- v1 does NOT:
--   - register devices (no client code calls supabase here)
--   - send pushes (no APNs/FCM integration)
--   - read notification_prefs (no UI surfaces it)
--
-- The schema is designed for the eventual integration:
--   - device_tokens: one row per (user, token) pair. Last-seen tracked
--     so v1.1 can age out stale tokens.
--   - notification_prefs: one row per user, autocreated by the same
--     auth trigger that creates the other identity rows. Defaults to
--     all-enabled so v1.1 cutover doesn't accidentally mute users.

create type public.device_platform as enum ('ios', 'android');

create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  token text not null,
  platform public.device_platform not null,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  unique (user_id, token)
);

create index device_tokens_user_idx on public.device_tokens (user_id);

create table public.notification_prefs (
  user_id uuid primary key references public.users(id) on delete cascade,
  recs_enabled boolean not null default true,
  friend_requests_enabled boolean not null default true,
  friend_finished_book_enabled boolean not null default true,
  list_shared_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

create trigger notification_prefs_updated_at before update on public.notification_prefs
  for each row execute function public.tg_set_updated_at();

-- Update fn_handle_new_auth_user to also seed notification_prefs.
-- This is the first table addition that the auth trigger needs to
-- provision; we replace the function rather than add a separate trigger
-- to keep provisioning atomic.
create or replace function public.fn_handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_display text;
begin
  v_display := coalesce(
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'name',
    split_part(new.email, '@', 1),
    'Reader'
  );

  insert into public.users (id, display_name)
  values (new.id, left(v_display, 50))
  on conflict (id) do nothing;

  insert into public.privacy_settings (user_id) values (new.id)
  on conflict (user_id) do nothing;

  insert into public.profiles (user_id) values (new.id)
  on conflict (user_id) do nothing;

  insert into public.notification_prefs (user_id) values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

comment on table public.device_tokens is
  'v1.1 push notification reservation. v1 does not write to this table; schema reserved to avoid retrofit on populated DB.';
comment on table public.notification_prefs is
  'v1.1 push notification preferences. Auto-provisioned by auth trigger with all-enabled defaults so v1.1 cutover does not accidentally mute users.';
