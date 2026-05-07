-- U2 visibility helper functions: fn_friendship_status, fn_is_blocked,
-- fn_handle_new_auth_user.
--
-- Affected privacy tables: none directly — these are SECURITY DEFINER functions
-- that read from privacy-affected tables under the function owner's privileges
-- so that RLS-protected callers can use them without recursive RLS overhead.
-- (RLS policies for users / privacy_settings / friendships still gate direct
-- table access; these helpers are explicitly privileged read paths.)
--
-- All functions take user UUIDs by argument (never via current_setting or
-- set_config — those are client-controllable in a Postgres session and would
-- break the trust model for the privacy intersection rule).

-- ==========================================================================
-- fn_friendship_status(a, b) — normalized lookup, returns NULL if no row
-- ==========================================================================

create or replace function public.fn_friendship_status(viewer uuid, other uuid)
returns public.friendship_status
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select status from public.friendships
   where user_id_a = least(viewer, other)
     and user_id_b = greatest(viewer, other)
   limit 1;
$$;

comment on function public.fn_friendship_status(uuid, uuid) is
  'Returns friendship_status enum or NULL when no row exists. Normalizes argument order (canonical pair: a < b).';

-- ==========================================================================
-- fn_is_blocked(viewer, other) — true if either side has blocked the other
-- ==========================================================================
-- A block is symmetric for visibility: regardless of who blocked whom, neither
-- party should see the other's notes/comments. The blocker is recorded in
-- blocked_by for moderation/UX purposes, not for the visibility check.

create or replace function public.fn_is_blocked(viewer uuid, other uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.friendships
     where user_id_a = least(viewer, other)
       and user_id_b = greatest(viewer, other)
       and status = 'blocked'
  );
$$;

comment on function public.fn_is_blocked(uuid, uuid) is
  'True if a blocked-status row exists between the two users in either direction. Symmetric: blocker direction is irrelevant to visibility.';

-- ==========================================================================
-- on auth.users insert trigger — provision public.users + privacy_settings + profiles
-- ==========================================================================
-- Supabase Auth creates auth.users rows on signup. We mirror them into public
-- with sensible defaults so the rest of the app has consistent identity rows
-- to FK against. display_name comes from the auth metadata (provider name,
-- email-local-part fallback). Username is intentionally null — set later by
-- the user during onboarding (E1).

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

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.fn_handle_new_auth_user();

comment on function public.fn_handle_new_auth_user() is
  'Provisions public.users + privacy_settings + profiles rows when Supabase Auth creates an auth.users row. Defaults: display_name from metadata, settings = everyone, profile public.';
