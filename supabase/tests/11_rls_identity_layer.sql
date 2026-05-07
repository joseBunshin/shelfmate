-- pgTAP coverage for U2 RLS on the identity layer:
--   users, privacy_settings, profiles, friendships
--
-- Acts as authenticated users by setting `role` + `request.jwt.claims` so
-- auth.uid() inside the policies resolves to the impersonated user. Anon-role
-- assertions switch to the `anon` role with no JWT.

begin;

select plan(26);

-- ==========================================================================
-- Setup (privileged role): three users + one friendship + one block
--   alice = active user, public profile, default privacy
--   bob   = active user, public profile, default privacy, friends-with-alice
--   carol = active user, NON-public profile, blocked-by-alice
--   dan   = active user, public profile, no friendship with anyone
--   eve   = active user, public profile, deletion_in_progress = true
-- ==========================================================================

insert into auth.users (
  id, instance_id, email, aud, role, encrypted_password, raw_user_meta_data,
  created_at, updated_at
) values
  ('11111111-1111-1111-1111-111111111111'::uuid,
   '00000000-0000-0000-0000-000000000000'::uuid,
   'alice@test.local', 'authenticated', 'authenticated', '$$placeholder$$',
   '{"full_name":"Alice"}'::jsonb, now(), now()),
  ('22222222-2222-2222-2222-222222222222'::uuid,
   '00000000-0000-0000-0000-000000000000'::uuid,
   'bob@test.local', 'authenticated', 'authenticated', '$$placeholder$$',
   '{"full_name":"Bob"}'::jsonb, now(), now()),
  ('33333333-3333-3333-3333-333333333333'::uuid,
   '00000000-0000-0000-0000-000000000000'::uuid,
   'carol@test.local', 'authenticated', 'authenticated', '$$placeholder$$',
   '{"full_name":"Carol"}'::jsonb, now(), now()),
  ('44444444-4444-4444-4444-444444444444'::uuid,
   '00000000-0000-0000-0000-000000000000'::uuid,
   'dan@test.local', 'authenticated', 'authenticated', '$$placeholder$$',
   '{"full_name":"Dan"}'::jsonb, now(), now()),
  ('55555555-5555-5555-5555-555555555555'::uuid,
   '00000000-0000-0000-0000-000000000000'::uuid,
   'eve@test.local', 'authenticated', 'authenticated', '$$placeholder$$',
   '{"full_name":"Eve"}'::jsonb, now(), now());

update public.profiles set is_public = false
  where user_id = '33333333-3333-3333-3333-333333333333'::uuid;

update public.users set deletion_in_progress = true
  where id = '55555555-5555-5555-5555-555555555555'::uuid;

insert into public.friendships (user_id_a, user_id_b, status, initiated_by)
values (
  least('11111111-1111-1111-1111-111111111111'::uuid, '22222222-2222-2222-2222-222222222222'::uuid),
  greatest('11111111-1111-1111-1111-111111111111'::uuid, '22222222-2222-2222-2222-222222222222'::uuid),
  'active', '11111111-1111-1111-1111-111111111111'::uuid
);

insert into public.friendships (user_id_a, user_id_b, status, initiated_by, blocked_by)
values (
  least('11111111-1111-1111-1111-111111111111'::uuid, '33333333-3333-3333-3333-333333333333'::uuid),
  greatest('11111111-1111-1111-1111-111111111111'::uuid, '33333333-3333-3333-3333-333333333333'::uuid),
  'blocked',
  '11111111-1111-1111-1111-111111111111'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);

-- ==========================================================================
-- ACT AS ALICE (authenticated)
-- ==========================================================================

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated')::text,
  true
);

-- users RLS

select is(
  (select count(*)::int from public.users where id = '11111111-1111-1111-1111-111111111111'::uuid),
  1,
  'users RLS: authenticated sees own row'
);

select is(
  (select count(*)::int from public.users
    where id in ('22222222-2222-2222-2222-222222222222'::uuid,
                 '33333333-3333-3333-3333-333333333333'::uuid,
                 '44444444-4444-4444-4444-444444444444'::uuid)),
  3,
  'users RLS: authenticated sees other active users (display_name is public)'
);

select is(
  (select count(*)::int from public.users
    where id = '55555555-5555-5555-5555-555555555555'::uuid),
  0,
  'users RLS: authenticated does NOT see deletion_in_progress users'
);

-- privacy_settings RLS

select is(
  (select count(*)::int from public.privacy_settings
    where user_id = '11111111-1111-1111-1111-111111111111'::uuid),
  1,
  'privacy_settings RLS: authenticated sees own row'
);

select is(
  (select count(*)::int from public.privacy_settings
    where user_id <> '11111111-1111-1111-1111-111111111111'::uuid),
  0,
  'privacy_settings RLS: authenticated does NOT see others rows (the trust seam)'
);

-- profiles RLS

select is(
  (select count(*)::int from public.profiles
    where user_id = '11111111-1111-1111-1111-111111111111'::uuid),
  1,
  'profiles RLS: own profile always visible'
);

select is(
  (select count(*)::int from public.profiles
    where user_id = '22222222-2222-2222-2222-222222222222'::uuid),
  1,
  'profiles RLS: friend public profile visible'
);

select is(
  (select count(*)::int from public.profiles
    where user_id = '33333333-3333-3333-3333-333333333333'::uuid),
  0,
  'profiles RLS: blocked user profile NOT visible (block-before-intersection)'
);

select is(
  (select count(*)::int from public.profiles
    where user_id = '44444444-4444-4444-4444-444444444444'::uuid),
  1,
  'profiles RLS: stranger public profile visible (is_public=true overrides non-friend)'
);

select is(
  (select count(*)::int from public.profiles
    where user_id = '55555555-5555-5555-5555-555555555555'::uuid),
  0,
  'profiles RLS: deletion_in_progress profile NOT visible'
);

-- friendships RLS

select is(
  (select count(*)::int from public.friendships
    where '11111111-1111-1111-1111-111111111111'::uuid in (user_id_a, user_id_b)),
  2,
  'friendships RLS: authenticated sees both rows they are part of'
);

select is(
  (select count(*)::int from public.friendships
    where '11111111-1111-1111-1111-111111111111'::uuid not in (user_id_a, user_id_b)),
  0,
  'friendships RLS: authenticated cannot see rows they are not part of'
);

-- can update own row, cannot update others
select lives_ok(
  $$update public.users set display_name = 'Alice (updated)'
     where id = '11111111-1111-1111-1111-111111111111'::uuid$$,
  'users RLS: authenticated can UPDATE own row'
);

select is(
  (select display_name from public.users where id = '11111111-1111-1111-1111-111111111111'::uuid),
  'Alice (updated)',
  'users RLS: own UPDATE actually persisted'
);

-- attempting to update another user's row succeeds-with-zero-rows under RLS
-- (RLS makes the row invisible to UPDATE, not an error)
select is(
  (with attempted as (
    update public.users set display_name = 'hacked'
      where id = '22222222-2222-2222-2222-222222222222'::uuid
      returning 1
  ) select count(*)::int from attempted),
  0,
  'users RLS: authenticated UPDATE on another user touches 0 rows'
);

select is(
  (select display_name from public.users where id = '22222222-2222-2222-2222-222222222222'::uuid),
  null,
  'users RLS: foreign-row UPDATE attempt did not leak via RETURNING (nothing visible to read back)'
);

-- friendships INSERT: only as initiator, only pending, only when in pair
select lives_ok(
  $$insert into public.friendships (user_id_a, user_id_b, status, initiated_by)
    values (
      least('11111111-1111-1111-1111-111111111111'::uuid, '44444444-4444-4444-4444-444444444444'::uuid),
      greatest('11111111-1111-1111-1111-111111111111'::uuid, '44444444-4444-4444-4444-444444444444'::uuid),
      'pending', '11111111-1111-1111-1111-111111111111'::uuid)$$,
  'friendships RLS: authenticated can INSERT pending row as initiator within own pair'
);

-- attempting to INSERT for a pair you are not in
select throws_ok(
  $$insert into public.friendships (user_id_a, user_id_b, status, initiated_by)
    values (
      least('22222222-2222-2222-2222-222222222222'::uuid, '44444444-4444-4444-4444-444444444444'::uuid),
      greatest('22222222-2222-2222-2222-222222222222'::uuid, '44444444-4444-4444-4444-444444444444'::uuid),
      'pending', '22222222-2222-2222-2222-222222222222'::uuid)$$,
  '42501',
  'new row violates row-level security policy for table "friendships"',
  'friendships RLS: cannot INSERT for a pair you are not in'
);

-- attempting to INSERT as a non-initiator
select throws_ok(
  $$insert into public.friendships (user_id_a, user_id_b, status, initiated_by)
    values (
      least('11111111-1111-1111-1111-111111111111'::uuid, '44444444-4444-4444-4444-444444444444'::uuid),
      greatest('11111111-1111-1111-1111-111111111111'::uuid, '44444444-4444-4444-4444-444444444444'::uuid),
      'active', '44444444-4444-4444-4444-444444444444'::uuid)$$,
  '42501',
  null,
  'friendships RLS: cannot INSERT with status<>pending or initiated_by<>self'
);

-- ==========================================================================
-- ACT AS DAN (no friendships, no blocks)
-- ==========================================================================

select set_config(
  'request.jwt.claims',
  json_build_object('sub', '44444444-4444-4444-4444-444444444444', 'role', 'authenticated')::text,
  true
);

select is(
  (select count(*)::int from public.profiles
    where user_id = '33333333-3333-3333-3333-333333333333'::uuid),
  0,
  'profiles RLS: stranger sees no non-public, non-friend profile (carol)'
);

select is(
  (select count(*)::int from public.profiles
    where user_id = '11111111-1111-1111-1111-111111111111'::uuid),
  1,
  'profiles RLS: stranger sees a non-friend public profile (alice)'
);

-- ==========================================================================
-- ACT AS ANON (no JWT)
-- ==========================================================================

reset role;
select set_config('request.jwt.claims', '', true);
set local role anon;

select is(
  (select count(*)::int from public.users
    where id = '11111111-1111-1111-1111-111111111111'::uuid),
  1,
  'users RLS (anon): public+active user visible (E10 surface)'
);

select is(
  (select count(*)::int from public.users
    where id = '33333333-3333-3333-3333-333333333333'::uuid),
  1,
  'users RLS (anon): identity row visible for any active user (display_name is public-safe)'
);

select is(
  (select count(*)::int from public.profiles
    where user_id = '33333333-3333-3333-3333-333333333333'::uuid),
  0,
  'profiles RLS (anon): non-public profile NOT visible (the actual privacy gate)'
);

select is(
  (select count(*)::int from public.users
    where id = '55555555-5555-5555-5555-555555555555'::uuid),
  0,
  'users RLS (anon): deletion_in_progress NOT visible'
);

select is(
  (select count(*)::int from public.privacy_settings),
  0,
  'privacy_settings RLS (anon): no rows visible (settings are not a public surface)'
);

select * from finish();

rollback;
