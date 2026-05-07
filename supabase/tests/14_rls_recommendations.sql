-- pgTAP coverage for U2 RLS on recommendations.
--
-- Verifies friendship-gated INSERT (active friendship required), party-only
-- SELECT for authenticated users, anon SELECT (UUID-unguessability model),
-- recipient-only UPDATE, and the sender-deletion anonymisation trigger.

begin;

select plan(14);

-- ==========================================================================
-- Setup: alice (sender, friend with bob), bob (recipient), carol (no friendship)
-- ==========================================================================

insert into auth.users (
  id, instance_id, email, aud, role, encrypted_password, raw_user_meta_data,
  created_at, updated_at
) values
  ('11111111-1111-1111-1111-111111111111'::uuid,
   '00000000-0000-0000-0000-000000000000'::uuid,
   'alice@t.local', 'authenticated', 'authenticated', '$$x$$', '{"full_name":"Alice"}'::jsonb, now(), now()),
  ('22222222-2222-2222-2222-222222222222'::uuid,
   '00000000-0000-0000-0000-000000000000'::uuid,
   'bob@t.local', 'authenticated', 'authenticated', '$$x$$', '{"full_name":"Bob"}'::jsonb, now(), now()),
  ('33333333-3333-3333-3333-333333333333'::uuid,
   '00000000-0000-0000-0000-000000000000'::uuid,
   'carol@t.local', 'authenticated', 'authenticated', '$$x$$', '{"full_name":"Carol"}'::jsonb, now(), now());

insert into public.friendships (user_id_a, user_id_b, status, initiated_by) values
  (least('11111111-1111-1111-1111-111111111111'::uuid, '22222222-2222-2222-2222-222222222222'::uuid),
   greatest('11111111-1111-1111-1111-111111111111'::uuid, '22222222-2222-2222-2222-222222222222'::uuid),
   'active', '11111111-1111-1111-1111-111111111111'::uuid);

insert into public.books (id, external_id, title, source) values
  ('bbbbbbbb-1111-0000-0000-000000000001'::uuid, 'openlibrary:OLREC1', 'Test Book Rec', 'openlibrary');

-- ==========================================================================
-- ACT AS ALICE
-- ==========================================================================

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated')::text,
  true
);

-- Friend INSERT works
select lives_ok(
  $$insert into public.recommendations
      (sender_id, recipient_id, book_id, note, sender_display_name_snapshot)
    values (
      '11111111-1111-1111-1111-111111111111'::uuid,
      '22222222-2222-2222-2222-222222222222'::uuid,
      'bbbbbbbb-1111-0000-0000-000000000001'::uuid,
      'You will love this one — read it last week.',
      'Alice'
    )$$,
  'recommendations RLS: active friend can INSERT a rec'
);

-- Self-rec rejected. Both the RLS WITH CHECK and the CHECK constraint
-- (recommendations_no_self) reject self-recs. RLS WITH CHECK fires first
-- in Postgres' evaluation order, so the surfaced SQLSTATE is 42501. The
-- CHECK is defense-in-depth (verified separately by attempting via
-- service_role bypass — out of scope for this assertion).
select throws_ok(
  $$insert into public.recommendations
      (sender_id, recipient_id, book_id, note, sender_display_name_snapshot)
    values (
      '11111111-1111-1111-1111-111111111111'::uuid,
      '11111111-1111-1111-1111-111111111111'::uuid,
      'bbbbbbbb-1111-0000-0000-000000000001'::uuid,
      'self', 'Alice'
    )$$,
  '42501',
  null,
  'recommendations: self-rec rejected by RLS WITH CHECK (recipient_id <> sender_id)'
);

-- Non-friend INSERT rejected (carol is not a friend of alice)
select throws_ok(
  $$insert into public.recommendations
      (sender_id, recipient_id, book_id, note, sender_display_name_snapshot)
    values (
      '11111111-1111-1111-1111-111111111111'::uuid,
      '33333333-3333-3333-3333-333333333333'::uuid,
      'bbbbbbbb-1111-0000-0000-000000000001'::uuid,
      'rec to non-friend',
      'Alice'
    )$$,
  '42501',
  null,
  'recommendations RLS: INSERT to non-friend rejected (no active friendship)'
);

-- Forging sender_id rejected
select throws_ok(
  $$insert into public.recommendations
      (sender_id, recipient_id, book_id, note, sender_display_name_snapshot)
    values (
      '22222222-2222-2222-2222-222222222222'::uuid,  -- alice trying to forge bob as sender
      '33333333-3333-3333-3333-333333333333'::uuid,
      'bbbbbbbb-1111-0000-0000-000000000001'::uuid,
      'forged',
      'Bob'
    )$$,
  '42501',
  null,
  'recommendations RLS: cannot forge sender_id <> auth.uid()'
);

-- alice (sender) sees the rec
select is(
  (select count(*)::int from public.recommendations
    where sender_id = '11111111-1111-1111-1111-111111111111'::uuid),
  1,
  'recommendations RLS: sender sees own outbound rec'
);

-- ==========================================================================
-- ACT AS BOB (recipient)
-- ==========================================================================

select set_config(
  'request.jwt.claims',
  json_build_object('sub', '22222222-2222-2222-2222-222222222222', 'role', 'authenticated')::text,
  true
);

-- bob sees the inbound rec
select is(
  (select count(*)::int from public.recommendations
    where recipient_id = '22222222-2222-2222-2222-222222222222'::uuid),
  1,
  'recommendations RLS: recipient sees inbound rec'
);

-- bob can update status
select lives_ok(
  $$update public.recommendations
       set status = 'viewed', viewed_at = now()
     where recipient_id = '22222222-2222-2222-2222-222222222222'::uuid$$,
  'recommendations RLS: recipient can transition status'
);

select is(
  (select status from public.recommendations
    where recipient_id = '22222222-2222-2222-2222-222222222222'::uuid),
  'viewed'::public.recommendation_status,
  'recommendations: recipient status update persisted'
);

-- ==========================================================================
-- ACT AS CAROL (no friendship — not party to the rec)
-- ==========================================================================

select set_config(
  'request.jwt.claims',
  json_build_object('sub', '33333333-3333-3333-3333-333333333333', 'role', 'authenticated')::text,
  true
);

-- carol cannot see the rec (not party)
select is(
  (select count(*)::int from public.recommendations),
  0,
  'recommendations RLS: third party cannot SELECT a rec they are not part of'
);

-- carol cannot update someone else's rec — silently affects 0 rows.
-- Carol cannot SELECT the row either, so we verify by switching to
-- service_role afterward to confirm status was not changed.
update public.recommendations set status = 'declined';

reset role;
set local role service_role;
select is(
  (select status from public.recommendations limit 1),
  'viewed'::public.recommendation_status,
  'recommendations RLS: third-party UPDATE silently did nothing (status still viewed)'
);
-- restore carol context for any later assertions in this section (none here)

-- ==========================================================================
-- ACT AS ANON (E10-001 surface)
-- ==========================================================================

reset role;
select set_config('request.jwt.claims', '', true);
set local role anon;

-- anon CAN read recs (UUID security model). The actual safety comes from
-- not exposing a list endpoint and from UUID unguessability.
select is(
  (select count(*)::int from public.recommendations),
  1,
  'recommendations RLS (anon): can read recs (UUID-unguessability is the gate)'
);

-- ==========================================================================
-- Anonymisation trigger (sender deletion path)
-- ==========================================================================

reset role;

-- Simulate sender deletion: cascade nullifies sender_id (FK SET NULL).
-- Real path is delete cascade from auth.users → public.users; here we
-- delete public.users directly to exercise the FK SET NULL + trigger.
delete from public.users where id = '11111111-1111-1111-1111-111111111111'::uuid;

select is(
  (select sender_id from public.recommendations limit 1),
  null::uuid,
  'recommendations: sender deletion sets sender_id to NULL (FK ON DELETE SET NULL)'
);

select is(
  (select sender_display_name_snapshot from public.recommendations limit 1),
  'A ShelfMate user',
  'recommendations: anonymisation trigger replaced sender_display_name_snapshot on sender delete'
);

select is(
  (select count(*)::int from public.recommendations),
  1,
  'recommendations: rec row survives sender deletion (recipient still has it)'
);

select * from finish();

rollback;
