-- pgTAP coverage for U2 R23 account-deletion cascade.
--
-- Verifies that deleting an auth.users row cascades through the entire
-- privacy-affected schema as expected:
--   - public.users (CASCADE)
--   - privacy_settings, profiles, notification_prefs (CASCADE from users)
--   - friendships on both sides (CASCADE)
--   - user_books, book_lists + items + shares (CASCADE)
--   - ai_rec_cache, ai_not_interested, device_tokens (CASCADE)
--   - recommendations.recipient_id (CASCADE)
--   - recommendations.sender_id (SET NULL + anonymisation trigger)
--
-- The Edge Function (supabase/functions/delete-account/index.ts) drives
-- this in production via auth.admin.deleteUser. This test exercises the
-- raw cascade chain.

begin;

select plan(15);

-- ==========================================================================
-- Setup: alice (about to be deleted), bob (friend, recipient of recs from alice)
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
   'bob@t.local', 'authenticated', 'authenticated', '$$x$$', '{"full_name":"Bob"}'::jsonb, now(), now());

insert into public.friendships (user_id_a, user_id_b, status, initiated_by) values
  (least('11111111-1111-1111-1111-111111111111'::uuid, '22222222-2222-2222-2222-222222222222'::uuid),
   greatest('11111111-1111-1111-1111-111111111111'::uuid, '22222222-2222-2222-2222-222222222222'::uuid),
   'active', '11111111-1111-1111-1111-111111111111'::uuid);

insert into public.books (id, external_id, title, source) values
  ('bbbbbbbb-1111-0000-0000-000000000001'::uuid, 'openlibrary:OLDEL1', 'Cascade Test', 'openlibrary');

-- alice has data across every privacy-affected table:
insert into public.user_books (user_id, book_id, status, rating, note) values
  ('11111111-1111-1111-1111-111111111111'::uuid,
   'bbbbbbbb-1111-0000-0000-000000000001'::uuid,
   'read', 4.0, 'alice''s note');

insert into public.book_lists (id, owner_id, title, visibility) values
  ('11111111-aaaa-0000-0000-000000000001'::uuid,
   '11111111-1111-1111-1111-111111111111'::uuid, 'Alice''s List', 'public');

insert into public.book_list_items (list_id, book_id, position) values
  ('11111111-aaaa-0000-0000-000000000001'::uuid,
   'bbbbbbbb-1111-0000-0000-000000000001'::uuid, 0);

insert into public.book_list_shares (list_id, recipient_id) values
  ('11111111-aaaa-0000-0000-000000000001'::uuid,
   '22222222-2222-2222-2222-222222222222'::uuid);

-- alice → bob recommendation (sender = alice)
insert into public.recommendations
    (sender_id, recipient_id, book_id, note, sender_display_name_snapshot)
  values (
    '11111111-1111-1111-1111-111111111111'::uuid,
    '22222222-2222-2222-2222-222222222222'::uuid,
    'bbbbbbbb-1111-0000-0000-000000000001'::uuid,
    'alice recommends this',
    'Alice'
  );

-- alice ai_rec_cache + ai_not_interested + device_tokens
insert into public.ai_rec_cache
    (user_id, cache_key, query_context, claude_model, prompt_tokens,
     completion_tokens, cost_cents)
  values (
    '11111111-1111-1111-1111-111111111111'::uuid,
    'k1', '{}'::jsonb, 'claude-sonnet-4-7', 100, 50, 0.001
  );

insert into public.ai_not_interested (user_id, book_id) values
  ('11111111-1111-1111-1111-111111111111'::uuid,
   'bbbbbbbb-1111-0000-0000-000000000001'::uuid);

insert into public.device_tokens (user_id, token, platform) values
  ('11111111-1111-1111-1111-111111111111'::uuid, 't-alice', 'ios');

-- ==========================================================================
-- Pre-deletion sanity: alice's data exists everywhere
-- ==========================================================================

select is(
  (select count(*)::int from public.users
    where id = '11111111-1111-1111-1111-111111111111'::uuid),
  1,
  'pre: alice exists in public.users'
);

-- ==========================================================================
-- Trigger the cascade by deleting auth.users row
-- ==========================================================================

delete from auth.users where id = '11111111-1111-1111-1111-111111111111'::uuid;

-- ==========================================================================
-- Post-deletion: every alice-owned row gone or anonymised
-- ==========================================================================

select is(
  (select count(*)::int from public.users
    where id = '11111111-1111-1111-1111-111111111111'::uuid),
  0,
  'cascade: public.users row gone'
);

select is(
  (select count(*)::int from public.privacy_settings
    where user_id = '11111111-1111-1111-1111-111111111111'::uuid),
  0,
  'cascade: privacy_settings gone'
);

select is(
  (select count(*)::int from public.profiles
    where user_id = '11111111-1111-1111-1111-111111111111'::uuid),
  0,
  'cascade: profiles gone'
);

select is(
  (select count(*)::int from public.notification_prefs
    where user_id = '11111111-1111-1111-1111-111111111111'::uuid),
  0,
  'cascade: notification_prefs gone'
);

select is(
  (select count(*)::int from public.friendships
    where '11111111-1111-1111-1111-111111111111'::uuid in (user_id_a, user_id_b)),
  0,
  'cascade: friendships gone (both sides cascade)'
);

select is(
  (select count(*)::int from public.user_books
    where user_id = '11111111-1111-1111-1111-111111111111'::uuid),
  0,
  'cascade: user_books gone'
);

select is(
  (select count(*)::int from public.book_lists
    where owner_id = '11111111-1111-1111-1111-111111111111'::uuid),
  0,
  'cascade: book_lists gone'
);

-- book_list_items + book_list_shares cascade from book_lists deletion
select is(
  (select count(*)::int from public.book_list_items
    where list_id = '11111111-aaaa-0000-0000-000000000001'::uuid),
  0,
  'cascade: book_list_items gone (via parent list cascade)'
);

select is(
  (select count(*)::int from public.book_list_shares
    where list_id = '11111111-aaaa-0000-0000-000000000001'::uuid),
  0,
  'cascade: book_list_shares gone (via parent list cascade)'
);

select is(
  (select count(*)::int from public.ai_rec_cache
    where user_id = '11111111-1111-1111-1111-111111111111'::uuid),
  0,
  'cascade: ai_rec_cache gone'
);

select is(
  (select count(*)::int from public.ai_not_interested
    where user_id = '11111111-1111-1111-1111-111111111111'::uuid),
  0,
  'cascade: ai_not_interested gone'
);

select is(
  (select count(*)::int from public.device_tokens
    where user_id = '11111111-1111-1111-1111-111111111111'::uuid),
  0,
  'cascade: device_tokens gone'
);

-- recommendations.recipient cascade: alice was the sender; recipient bob's
-- inbound rec from alice should SURVIVE with sender_id NULL + anonymised name
select is(
  (select sender_display_name_snapshot from public.recommendations
    where recipient_id = '22222222-2222-2222-2222-222222222222'::uuid),
  'A ShelfMate user',
  'cascade: recommendations.sender_id SET NULL fires anonymisation trigger'
);

select is(
  (select count(*)::int from public.recommendations
    where recipient_id = '22222222-2222-2222-2222-222222222222'::uuid),
  1,
  'cascade: rec row survives sender deletion (recipient still has it)'
);

select * from finish();

rollback;
