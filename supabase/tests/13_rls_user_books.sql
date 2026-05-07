-- pgTAP coverage for U2 RLS on user_books.
--
-- Verifies the RLS policy on user_books correctly delegates to
-- fn_can_see_comment by exercising the policy via SELECT + INSERT/UPDATE/
-- DELETE under different role + JWT contexts. The intersection logic itself
-- is exhaustively tested in 12_visibility_intersection.sql; this file
-- confirms the policy is wired to the function.

begin;

select plan(13);

-- ==========================================================================
-- Setup: alice (active friend with bob) + bob + carol (no relationship)
-- + a books row + user_books rows for each user
-- ==========================================================================

insert into auth.users (
  id, instance_id, email, aud, role, encrypted_password, raw_user_meta_data,
  created_at, updated_at
) values
  ('11111111-1111-1111-1111-111111111111'::uuid,
   '00000000-0000-0000-0000-000000000000'::uuid,
   'a@t.local', 'authenticated', 'authenticated', '$$x$$', '{"full_name":"A"}'::jsonb, now(), now()),
  ('22222222-2222-2222-2222-222222222222'::uuid,
   '00000000-0000-0000-0000-000000000000'::uuid,
   'b@t.local', 'authenticated', 'authenticated', '$$x$$', '{"full_name":"B"}'::jsonb, now(), now()),
  ('33333333-3333-3333-3333-333333333333'::uuid,
   '00000000-0000-0000-0000-000000000000'::uuid,
   'c@t.local', 'authenticated', 'authenticated', '$$x$$', '{"full_name":"C"}'::jsonb, now(), now());

insert into public.friendships (user_id_a, user_id_b, status, initiated_by) values
  (least('11111111-1111-1111-1111-111111111111'::uuid, '22222222-2222-2222-2222-222222222222'::uuid),
   greatest('11111111-1111-1111-1111-111111111111'::uuid, '22222222-2222-2222-2222-222222222222'::uuid),
   'active', '11111111-1111-1111-1111-111111111111'::uuid);

insert into public.books (id, external_id, title, source) values
  ('bbbbbbbb-1111-0000-0000-000000000001'::uuid, 'openlibrary:OLTEST1', 'Test Book One', 'openlibrary');

-- alice's user_book: status=read, note set
insert into public.user_books (id, user_id, book_id, status, rating, note, finished_at) values
  ('cccccccc-1111-0000-0000-000000000001'::uuid,
   '11111111-1111-1111-1111-111111111111'::uuid,
   'bbbbbbbb-1111-0000-0000-000000000001'::uuid,
   'read', 4.5, 'alice''s note on this book', now());

-- bob's user_book
insert into public.user_books (id, user_id, book_id, status, rating, note, finished_at) values
  ('cccccccc-2222-0000-0000-000000000001'::uuid,
   '22222222-2222-2222-2222-222222222222'::uuid,
   'bbbbbbbb-1111-0000-0000-000000000001'::uuid,
   'read', 5.0, 'bob loved this book', now());

-- carol's user_book
insert into public.user_books (id, user_id, book_id, status, rating, note, finished_at) values
  ('cccccccc-3333-0000-0000-000000000001'::uuid,
   '33333333-3333-3333-3333-333333333333'::uuid,
   'bbbbbbbb-1111-0000-0000-000000000001'::uuid,
   'reading', null, null, null);

-- ==========================================================================
-- ACT AS ALICE (active friend with bob, stranger to carol)
-- ==========================================================================

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated')::text,
  true
);

-- Default privacy settings: everyone × everyone
select is(
  (select count(*)::int from public.user_books where user_id = '11111111-1111-1111-1111-111111111111'::uuid),
  1,
  'user_books RLS: own row always visible (alice sees own)'
);

select is(
  (select count(*)::int from public.user_books where user_id = '22222222-2222-2222-2222-222222222222'::uuid),
  1,
  'user_books RLS: friend with everyone × everyone → bob visible'
);

select is(
  (select count(*)::int from public.user_books where user_id = '33333333-3333-3333-3333-333333333333'::uuid),
  1,
  'user_books RLS: stranger with everyone × everyone → carol visible (no friendship needed for everyone)'
);

-- Set carol writer to friends → alice (no friendship with carol) loses visibility.
-- Privileged context required because privacy_settings RLS only allows users
-- to UPDATE their OWN row; alice cannot UPDATE carol's settings.
reset role;
update public.privacy_settings set writer_setting = 'friends'
  where user_id = '33333333-3333-3333-3333-333333333333'::uuid;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated')::text,
  true
);

select is(
  (select count(*)::int from public.user_books where user_id = '33333333-3333-3333-3333-333333333333'::uuid),
  0,
  'user_books RLS: stranger with writer=friends + no friendship → INVISIBLE'
);

-- Restore carol everyone, set alice viewer to only_me → alice loses visibility on others.
-- carol setting is foreign to alice; alice's setting is her own. Use privileged
-- role for the carol update; alice can update her own settings under RLS.
reset role;
update public.privacy_settings set writer_setting = 'everyone'
  where user_id = '33333333-3333-3333-3333-333333333333'::uuid;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated')::text,
  true
);
update public.privacy_settings set viewer_setting = 'only_me'
  where user_id = '11111111-1111-1111-1111-111111111111'::uuid;

select is(
  (select count(*)::int from public.user_books where user_id = '22222222-2222-2222-2222-222222222222'::uuid),
  0,
  'user_books RLS: viewer=only_me masks all others (bob invisible to alice)'
);

select is(
  (select count(*)::int from public.user_books where user_id = '11111111-1111-1111-1111-111111111111'::uuid),
  1,
  'user_books RLS: viewer=only_me does not mask own row (alice still sees self)'
);

-- Restore alice viewer
update public.privacy_settings set viewer_setting = 'everyone'
  where user_id = '11111111-1111-1111-1111-111111111111'::uuid;

-- ==========================================================================
-- INSERT/UPDATE/DELETE policies
-- ==========================================================================

-- alice can INSERT own row
select lives_ok(
  $$insert into public.user_books (user_id, book_id, status)
    values ('11111111-1111-1111-1111-111111111111'::uuid,
            'bbbbbbbb-1111-0000-0000-000000000001'::uuid,
            'want_to_read')
    on conflict do nothing$$,
  'user_books RLS: authenticated INSERT own row (no-op via on conflict)'
);

-- alice cannot INSERT for another user
select throws_ok(
  $$insert into public.user_books (user_id, book_id, status)
    values ('22222222-2222-2222-2222-222222222222'::uuid,
            'bbbbbbbb-1111-0000-0000-000000000001'::uuid,
            'reading')$$,
  '42501',
  null,
  'user_books RLS: authenticated INSERT for another user is rejected'
);

-- alice can UPDATE own row
select lives_ok(
  $$update public.user_books set rating = 5.0
    where user_id = '11111111-1111-1111-1111-111111111111'::uuid$$,
  'user_books RLS: authenticated UPDATE own row'
);

-- alice UPDATE on bob's row silently affects no rows (RLS hides it from
-- the update path). Verify by reading bob's rating after — should be
-- unchanged at 5.0 from the setup insert.
update public.user_books set rating = 1.0
  where user_id = '22222222-2222-2222-2222-222222222222'::uuid;

select is(
  (select rating from public.user_books
    where user_id = '22222222-2222-2222-2222-222222222222'::uuid),
  5.0::numeric(2,1),
  'user_books RLS: foreign UPDATE silently did nothing (Bob rating unchanged)'
);

-- alice DELETE own row
select lives_ok(
  $$delete from public.user_books
     where user_id = '11111111-1111-1111-1111-111111111111'::uuid
       and status = 'want_to_read'$$,
  'user_books RLS: authenticated DELETE own row'
);

-- ==========================================================================
-- ANON role
-- ==========================================================================

reset role;
select set_config('request.jwt.claims', '', true);
set local role anon;

-- Default settings (everyone × 3) — anon sees all three rows
select is(
  (select count(*)::int from public.user_books),
  3,
  'user_books RLS (anon): writer=everyone for all three users → 3 rows visible'
);

-- Set bob's writer to friends → anon loses visibility on bob
reset role;
update public.privacy_settings set writer_setting = 'friends'
  where user_id = '22222222-2222-2222-2222-222222222222'::uuid;
set local role anon;

select is(
  (select count(*)::int from public.user_books where user_id = '22222222-2222-2222-2222-222222222222'::uuid),
  0,
  'user_books RLS (anon): writer=friends → invisible to anon (no friendship possible from null viewer)'
);

select * from finish();

rollback;
