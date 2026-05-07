-- pgTAP coverage for U2 visibility helpers + auth trigger provisioning.
--
-- Tested:
--   fn_handle_new_auth_user — fires on auth.users insert, creates the three
--     public-side rows (users, privacy_settings, profiles) with correct defaults
--   fn_friendship_status   — returns enum or NULL across canonical orderings
--   fn_is_blocked          — symmetric: blocker direction does not matter

begin;

select plan(17);

-- ==========================================================================
-- Setup: three users via the auth trigger
-- ==========================================================================

insert into auth.users (
  id, instance_id, email, aud, role, encrypted_password, raw_user_meta_data,
  created_at, updated_at
)
values
  ('11111111-1111-1111-1111-111111111111'::uuid,
   '00000000-0000-0000-0000-000000000000'::uuid,
   'alice@test.local', 'authenticated', 'authenticated', '$$placeholder$$',
   '{"full_name":"Alice Reader"}'::jsonb, now(), now()),
  ('22222222-2222-2222-2222-222222222222'::uuid,
   '00000000-0000-0000-0000-000000000000'::uuid,
   'bob@test.local', 'authenticated', 'authenticated', '$$placeholder$$',
   '{"full_name":"Bob Reader"}'::jsonb, now(), now()),
  ('33333333-3333-3333-3333-333333333333'::uuid,
   '00000000-0000-0000-0000-000000000000'::uuid,
   'carol@test.local', 'authenticated', 'authenticated', '$$placeholder$$',
   '{"full_name":"Carol Reader"}'::jsonb, now(), now());

-- ==========================================================================
-- fn_handle_new_auth_user provisions all three public rows
-- ==========================================================================

select is(
  (select display_name from public.users where id = '11111111-1111-1111-1111-111111111111'::uuid),
  'Alice Reader',
  'auth trigger sets display_name from raw_user_meta_data.full_name'
);

select is(
  (select count(*)::int from public.users where id in (
    '11111111-1111-1111-1111-111111111111'::uuid,
    '22222222-2222-2222-2222-222222222222'::uuid,
    '33333333-3333-3333-3333-333333333333'::uuid
  )),
  3,
  'auth trigger created public.users rows for all three test users'
);

select is(
  (select writer_setting from public.privacy_settings
    where user_id = '11111111-1111-1111-1111-111111111111'::uuid),
  'everyone'::public.privacy_audience,
  'privacy_settings default writer_setting = everyone'
);

select is(
  (select viewer_setting from public.privacy_settings
    where user_id = '11111111-1111-1111-1111-111111111111'::uuid),
  'everyone'::public.privacy_audience,
  'privacy_settings default viewer_setting = everyone'
);

select is(
  (select is_public from public.profiles
    where user_id = '11111111-1111-1111-1111-111111111111'::uuid),
  true,
  'profiles default is_public = true'
);

select is(
  (select deletion_in_progress from public.users
    where id = '11111111-1111-1111-1111-111111111111'::uuid),
  false,
  'users default deletion_in_progress = false'
);

-- ==========================================================================
-- Setup: two friendship rows for fn_friendship_status / fn_is_blocked tests
--   alice <-> bob: active
--   alice <-> carol: blocked, blocked_by alice
-- ==========================================================================

insert into public.friendships (user_id_a, user_id_b, status, initiated_by, blocked_by)
values
  (least(
     '11111111-1111-1111-1111-111111111111'::uuid,
     '22222222-2222-2222-2222-222222222222'::uuid),
   greatest(
     '11111111-1111-1111-1111-111111111111'::uuid,
     '22222222-2222-2222-2222-222222222222'::uuid),
   'active', '11111111-1111-1111-1111-111111111111'::uuid, null),
  (least(
     '11111111-1111-1111-1111-111111111111'::uuid,
     '33333333-3333-3333-3333-333333333333'::uuid),
   greatest(
     '11111111-1111-1111-1111-111111111111'::uuid,
     '33333333-3333-3333-3333-333333333333'::uuid),
   'blocked', '11111111-1111-1111-1111-111111111111'::uuid,
   '11111111-1111-1111-1111-111111111111'::uuid);

-- ==========================================================================
-- fn_friendship_status — order-independent lookup
-- ==========================================================================

select is(
  public.fn_friendship_status(
    '11111111-1111-1111-1111-111111111111'::uuid,
    '22222222-2222-2222-2222-222222222222'::uuid),
  'active'::public.friendship_status,
  'fn_friendship_status returns active for alice→bob'
);

select is(
  public.fn_friendship_status(
    '22222222-2222-2222-2222-222222222222'::uuid,
    '11111111-1111-1111-1111-111111111111'::uuid),
  'active'::public.friendship_status,
  'fn_friendship_status is order-independent (bob→alice = active)'
);

select is(
  public.fn_friendship_status(
    '11111111-1111-1111-1111-111111111111'::uuid,
    '33333333-3333-3333-3333-333333333333'::uuid),
  'blocked'::public.friendship_status,
  'fn_friendship_status returns blocked for alice/carol'
);

select is(
  public.fn_friendship_status(
    '22222222-2222-2222-2222-222222222222'::uuid,
    '33333333-3333-3333-3333-333333333333'::uuid),
  null::public.friendship_status,
  'fn_friendship_status returns NULL when no row exists (bob/carol)'
);

-- ==========================================================================
-- fn_is_blocked — symmetric, never partially-true
-- ==========================================================================

select ok(
  public.fn_is_blocked(
    '11111111-1111-1111-1111-111111111111'::uuid,
    '33333333-3333-3333-3333-333333333333'::uuid),
  'fn_is_blocked true for blocker→blocked (alice→carol)'
);

select ok(
  public.fn_is_blocked(
    '33333333-3333-3333-3333-333333333333'::uuid,
    '11111111-1111-1111-1111-111111111111'::uuid),
  'fn_is_blocked symmetric: also true for blocked→blocker (carol→alice)'
);

select ok(
  not public.fn_is_blocked(
    '11111111-1111-1111-1111-111111111111'::uuid,
    '22222222-2222-2222-2222-222222222222'::uuid),
  'fn_is_blocked false for active friends (alice/bob)'
);

select ok(
  not public.fn_is_blocked(
    '22222222-2222-2222-2222-222222222222'::uuid,
    '33333333-3333-3333-3333-333333333333'::uuid),
  'fn_is_blocked false when no friendship row exists (bob/carol)'
);

-- ==========================================================================
-- friendship CHECK constraints — defense-in-depth alongside RLS
-- ==========================================================================

select throws_ok(
  $$insert into public.friendships (user_id_a, user_id_b, status, initiated_by)
    values (
      '22222222-2222-2222-2222-222222222222'::uuid,
      '11111111-1111-1111-1111-111111111111'::uuid,
      'pending',
      '22222222-2222-2222-2222-222222222222'::uuid)$$,
  '23514',
  null,
  'friendships_canonical_order CHECK rejects user_id_a > user_id_b'
);

select throws_ok(
  $$insert into public.friendships (user_id_a, user_id_b, status, initiated_by, blocked_by)
    values (
      least(
        '22222222-2222-2222-2222-222222222222'::uuid,
        '33333333-3333-3333-3333-333333333333'::uuid),
      greatest(
        '22222222-2222-2222-2222-222222222222'::uuid,
        '33333333-3333-3333-3333-333333333333'::uuid),
      'active',
      '22222222-2222-2222-2222-222222222222'::uuid,
      '22222222-2222-2222-2222-222222222222'::uuid)$$,
  '23514',
  null,
  'friendships_blocked_by_consistency CHECK rejects blocked_by set when status != blocked'
);

select throws_ok(
  $$insert into public.friendships (user_id_a, user_id_b, status, initiated_by)
    values (
      least(
        '22222222-2222-2222-2222-222222222222'::uuid,
        '33333333-3333-3333-3333-333333333333'::uuid),
      greatest(
        '22222222-2222-2222-2222-222222222222'::uuid,
        '33333333-3333-3333-3333-333333333333'::uuid),
      'pending',
      '11111111-1111-1111-1111-111111111111'::uuid)$$,
  '23514',
  null,
  'friendships_initiated_by_in_pair CHECK rejects initiator outside the pair'
);

select * from finish();

rollback;
