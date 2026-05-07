-- pgTAP coverage for U2 RLS on book_lists, book_list_items, book_list_shares.

begin;

select plan(17);

-- ==========================================================================
-- Setup: alice (owner), bob (friend), carol (blocked), dan (stranger),
-- eve (private-share recipient)
-- ==========================================================================

insert into auth.users (
  id, instance_id, email, aud, role, encrypted_password, raw_user_meta_data,
  created_at, updated_at
) values
  ('11111111-1111-1111-1111-111111111111'::uuid,
   '00000000-0000-0000-0000-000000000000'::uuid,
   'a@t.local', 'authenticated', 'authenticated', '$$x$$', '{"full_name":"Alice"}'::jsonb, now(), now()),
  ('22222222-2222-2222-2222-222222222222'::uuid,
   '00000000-0000-0000-0000-000000000000'::uuid,
   'b@t.local', 'authenticated', 'authenticated', '$$x$$', '{"full_name":"Bob"}'::jsonb, now(), now()),
  ('33333333-3333-3333-3333-333333333333'::uuid,
   '00000000-0000-0000-0000-000000000000'::uuid,
   'c@t.local', 'authenticated', 'authenticated', '$$x$$', '{"full_name":"Carol"}'::jsonb, now(), now()),
  ('44444444-4444-4444-4444-444444444444'::uuid,
   '00000000-0000-0000-0000-000000000000'::uuid,
   'd@t.local', 'authenticated', 'authenticated', '$$x$$', '{"full_name":"Dan"}'::jsonb, now(), now()),
  ('55555555-5555-5555-5555-555555555555'::uuid,
   '00000000-0000-0000-0000-000000000000'::uuid,
   'e@t.local', 'authenticated', 'authenticated', '$$x$$', '{"full_name":"Eve"}'::jsonb, now(), now());

-- alice ↔ bob: active friendship
insert into public.friendships (user_id_a, user_id_b, status, initiated_by) values
  (least('11111111-1111-1111-1111-111111111111'::uuid, '22222222-2222-2222-2222-222222222222'::uuid),
   greatest('11111111-1111-1111-1111-111111111111'::uuid, '22222222-2222-2222-2222-222222222222'::uuid),
   'active', '11111111-1111-1111-1111-111111111111'::uuid);
-- alice ↔ carol: blocked by alice
insert into public.friendships (user_id_a, user_id_b, status, initiated_by, blocked_by) values
  (least('11111111-1111-1111-1111-111111111111'::uuid, '33333333-3333-3333-3333-333333333333'::uuid),
   greatest('11111111-1111-1111-1111-111111111111'::uuid, '33333333-3333-3333-3333-333333333333'::uuid),
   'blocked',
   '11111111-1111-1111-1111-111111111111'::uuid,
   '11111111-1111-1111-1111-111111111111'::uuid);

insert into public.books (id, external_id, title, source) values
  ('bbbbbbbb-1111-0000-0000-000000000001'::uuid, 'openlibrary:OLLIST1', 'Book One', 'openlibrary'),
  ('bbbbbbbb-2222-0000-0000-000000000002'::uuid, 'openlibrary:OLLIST2', 'Book Two', 'openlibrary');

-- alice creates three lists: private, friends, public
insert into public.book_lists (id, owner_id, title, visibility) values
  ('11111111-aaaa-0000-0000-000000000001'::uuid,
   '11111111-1111-1111-1111-111111111111'::uuid, 'Private List', 'private'),
  ('11111111-aaaa-0000-0000-000000000002'::uuid,
   '11111111-1111-1111-1111-111111111111'::uuid, 'Friends List', 'friends'),
  ('11111111-aaaa-0000-0000-000000000003'::uuid,
   '11111111-1111-1111-1111-111111111111'::uuid, 'Public List', 'public');

insert into public.book_list_items (list_id, book_id, position) values
  ('11111111-aaaa-0000-0000-000000000003'::uuid,
   'bbbbbbbb-1111-0000-0000-000000000001'::uuid, 0),
  ('11111111-aaaa-0000-0000-000000000003'::uuid,
   'bbbbbbbb-2222-0000-0000-000000000002'::uuid, 1);

-- alice shares the private list with eve
insert into public.book_list_shares (list_id, recipient_id) values
  ('11111111-aaaa-0000-0000-000000000001'::uuid,
   '55555555-5555-5555-5555-555555555555'::uuid);

-- ==========================================================================
-- ACT AS ALICE (owner) — sees all three of her own lists
-- ==========================================================================

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated')::text,
  true
);

select is(
  (select count(*)::int from public.book_lists where owner_id = '11111111-1111-1111-1111-111111111111'::uuid),
  3,
  'book_lists RLS: owner sees all three own lists regardless of visibility'
);

-- ==========================================================================
-- ACT AS BOB (active friend) — sees friends + public, NOT private
-- ==========================================================================

select set_config(
  'request.jwt.claims',
  json_build_object('sub', '22222222-2222-2222-2222-222222222222', 'role', 'authenticated')::text,
  true
);

select is(
  (select count(*)::int from public.book_lists
    where owner_id = '11111111-1111-1111-1111-111111111111'::uuid),
  2,
  'book_lists RLS: active friend sees friends + public, not private'
);

select is(
  (select count(*)::int from public.book_lists
    where owner_id = '11111111-1111-1111-1111-111111111111'::uuid
      and visibility = 'private'),
  0,
  'book_lists RLS: friend cannot see owner''s private list'
);

select is(
  (select count(*)::int from public.book_lists
    where owner_id = '11111111-1111-1111-1111-111111111111'::uuid
      and visibility = 'friends'),
  1,
  'book_lists RLS: friend sees owner''s friends-only list'
);

-- ==========================================================================
-- ACT AS CAROL (blocked by alice) — sees nothing of alice's
-- ==========================================================================

select set_config(
  'request.jwt.claims',
  json_build_object('sub', '33333333-3333-3333-3333-333333333333', 'role', 'authenticated')::text,
  true
);

select is(
  (select count(*)::int from public.book_lists
    where owner_id = '11111111-1111-1111-1111-111111111111'::uuid),
  0,
  'book_lists RLS: blocked user sees nothing of the blocker''s lists (block-before-intersection)'
);

-- ==========================================================================
-- ACT AS DAN (stranger — no friendship, no block, not shared)
-- ==========================================================================

select set_config(
  'request.jwt.claims',
  json_build_object('sub', '44444444-4444-4444-4444-444444444444', 'role', 'authenticated')::text,
  true
);

select is(
  (select count(*)::int from public.book_lists
    where owner_id = '11111111-1111-1111-1111-111111111111'::uuid),
  1,
  'book_lists RLS: stranger sees only the public list'
);

-- ==========================================================================
-- ACT AS EVE (private-share recipient, no friendship)
-- ==========================================================================

select set_config(
  'request.jwt.claims',
  json_build_object('sub', '55555555-5555-5555-5555-555555555555', 'role', 'authenticated')::text,
  true
);

select is(
  (select count(*)::int from public.book_lists
    where owner_id = '11111111-1111-1111-1111-111111111111'::uuid),
  2,
  'book_lists RLS: share recipient sees public + the privately-shared list'
);

select is(
  (select count(*)::int from public.book_lists
    where id = '11111111-aaaa-0000-0000-000000000001'::uuid),
  1,
  'book_lists RLS: the privately-shared list specifically is visible to eve via book_list_shares'
);

-- ==========================================================================
-- book_list_items inherits parent visibility (composition test)
-- ==========================================================================

-- as eve (only sees public + shared private), the public list's items should be visible
select is(
  (select count(*)::int from public.book_list_items
    where list_id = '11111111-aaaa-0000-0000-000000000003'::uuid),
  2,
  'book_list_items RLS: items of public list visible to eve'
);

-- as bob (sees friends + public, NOT private), items of private list should be invisible
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '22222222-2222-2222-2222-222222222222', 'role', 'authenticated')::text,
  true
);

select is(
  (select count(*)::int from public.book_list_items
    where list_id = '11111111-aaaa-0000-0000-000000000001'::uuid),
  0,
  'book_list_items RLS: items of private list invisible to non-shared friend'
);

-- ==========================================================================
-- INSERT/UPDATE/DELETE owner-only
-- ==========================================================================

select set_config(
  'request.jwt.claims',
  json_build_object('sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated')::text,
  true
);

-- alice can add an item to her own list
select lives_ok(
  $$insert into public.book_list_items (list_id, book_id, position)
    values ('11111111-aaaa-0000-0000-000000000002'::uuid,
            'bbbbbbbb-1111-0000-0000-000000000001'::uuid, 0)$$,
  'book_list_items RLS: owner can INSERT items into own list'
);

-- bob cannot add an item to alice's list
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '22222222-2222-2222-2222-222222222222', 'role', 'authenticated')::text,
  true
);
select throws_ok(
  $$insert into public.book_list_items (list_id, book_id, position)
    values ('11111111-aaaa-0000-0000-000000000003'::uuid,
            'bbbbbbbb-2222-0000-0000-000000000002'::uuid, 5)$$,
  '42501',
  null,
  'book_list_items RLS: non-owner INSERT rejected'
);

-- bob cannot create a list owned by alice (forge owner_id)
select throws_ok(
  $$insert into public.book_lists (owner_id, title, visibility)
    values ('11111111-1111-1111-1111-111111111111'::uuid, 'Forged', 'public')$$,
  '42501',
  null,
  'book_lists RLS: cannot forge owner_id <> auth.uid()'
);

-- ==========================================================================
-- ACT AS ANON (E10-004 surface)
-- ==========================================================================

reset role;
select set_config('request.jwt.claims', '', true);
set local role anon;

select is(
  (select count(*)::int from public.book_lists),
  1,
  'book_lists RLS (anon): only public list visible'
);

select is(
  (select visibility from public.book_lists limit 1),
  'public'::public.book_list_visibility,
  'book_lists RLS (anon): the visible list IS public'
);

select is(
  (select count(*)::int from public.book_list_items
    where list_id = '11111111-aaaa-0000-0000-000000000003'::uuid),
  2,
  'book_list_items RLS (anon): items of public list visible'
);

select is(
  (select count(*)::int from public.book_list_items
    where list_id = '11111111-aaaa-0000-0000-000000000001'::uuid),
  0,
  'book_list_items RLS (anon): items of private list NOT visible'
);

select * from finish();

rollback;
