-- pgTAP coverage for U2 ai_rec_cache, ai_not_interested, device_tokens,
-- notification_prefs. All four are own-row only.

begin;

select plan(14);

-- ==========================================================================
-- Setup: alice + bob
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
   'b@t.local', 'authenticated', 'authenticated', '$$x$$', '{"full_name":"B"}'::jsonb, now(), now());

insert into public.books (id, external_id, title, source) values
  ('bbbbbbbb-1111-0000-0000-000000000001'::uuid, 'openlibrary:OLAI1', 'AI Test Book', 'openlibrary');

-- Auth trigger should have created notification_prefs for both users
select is(
  (select count(*)::int from public.notification_prefs
    where user_id in ('11111111-1111-1111-1111-111111111111'::uuid,
                      '22222222-2222-2222-2222-222222222222'::uuid)),
  2,
  'notification_prefs: auth trigger provisioned a row per user'
);

select is(
  (select recs_enabled from public.notification_prefs
    where user_id = '11111111-1111-1111-1111-111111111111'::uuid),
  true,
  'notification_prefs: defaults all-enabled (recs_enabled = true)'
);

-- ==========================================================================
-- ACT AS ALICE
-- ==========================================================================

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated')::text,
  true
);

-- alice can INSERT own ai_rec_cache row
select lives_ok(
  $$insert into public.ai_rec_cache
      (user_id, cache_key, query_context, claude_model, prompt_tokens,
       completion_tokens, cost_cents)
    values (
      '11111111-1111-1111-1111-111111111111'::uuid,
      'genres=fantasy,scifi&recent=...',
      '{"genres":["fantasy","scifi"]}'::jsonb,
      'claude-sonnet-4-7',
      1500, 400, 0.0095
    )$$,
  'ai_rec_cache RLS: authenticated INSERT own row'
);

-- alice cannot INSERT for bob
select throws_ok(
  $$insert into public.ai_rec_cache
      (user_id, cache_key, query_context, claude_model, prompt_tokens,
       completion_tokens, cost_cents)
    values (
      '22222222-2222-2222-2222-222222222222'::uuid,
      'forged-key',
      '{}'::jsonb, 'x', 0, 0, 0
    )$$,
  '42501',
  null,
  'ai_rec_cache RLS: cannot INSERT for another user'
);

-- alice can INSERT own ai_not_interested
select lives_ok(
  $$insert into public.ai_not_interested (user_id, book_id, reason)
    values (
      '11111111-1111-1111-1111-111111111111'::uuid,
      'bbbbbbbb-1111-0000-0000-000000000001'::uuid,
      'too long'
    )$$,
  'ai_not_interested RLS: authenticated INSERT own row'
);

-- alice can register own device_token
select lives_ok(
  $$insert into public.device_tokens (user_id, token, platform)
    values (
      '11111111-1111-1111-1111-111111111111'::uuid,
      'apns-token-abc-123',
      'ios'
    )$$,
  'device_tokens RLS: authenticated INSERT own row'
);

-- alice can update own notification_prefs
select lives_ok(
  $$update public.notification_prefs
       set recs_enabled = false
     where user_id = '11111111-1111-1111-1111-111111111111'::uuid$$,
  'notification_prefs RLS: authenticated UPDATE own row'
);

select is(
  (select recs_enabled from public.notification_prefs
    where user_id = '11111111-1111-1111-1111-111111111111'::uuid),
  false,
  'notification_prefs: own UPDATE persisted'
);

-- alice cannot read bob's data
select is(
  (select count(*)::int from public.ai_rec_cache
    where user_id = '22222222-2222-2222-2222-222222222222'::uuid),
  0,
  'ai_rec_cache RLS: alice cannot SELECT bob''s rows'
);

select is(
  (select count(*)::int from public.notification_prefs
    where user_id = '22222222-2222-2222-2222-222222222222'::uuid),
  0,
  'notification_prefs RLS: alice cannot SELECT bob''s row'
);

-- ==========================================================================
-- ACT AS ANON — none of these tables expose anything to anon
-- ==========================================================================

reset role;
select set_config('request.jwt.claims', '', true);
set local role anon;

select is(
  (select count(*)::int from public.ai_rec_cache),
  0,
  'ai_rec_cache RLS (anon): no rows visible'
);

select is(
  (select count(*)::int from public.ai_not_interested),
  0,
  'ai_not_interested RLS (anon): no rows visible'
);

select is(
  (select count(*)::int from public.device_tokens),
  0,
  'device_tokens RLS (anon): no rows visible'
);

select is(
  (select count(*)::int from public.notification_prefs),
  0,
  'notification_prefs RLS (anon): no rows visible'
);

select * from finish();

rollback;
