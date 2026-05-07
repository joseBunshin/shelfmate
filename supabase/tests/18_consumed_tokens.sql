-- pgTAP coverage for U3 consumed_tokens table — R26 replay-protection model.
--
-- Verifies:
--   - INSERT ON CONFLICT DO NOTHING is the atomic claim
--   - second INSERT with same token_hash returns 0 rows (replay rejection)
--   - invalidated=true rows pre-written by delete-account block subsequent
--     consumption attempts
--   - RLS: clients (anon, authenticated) cannot read or write — service_role only

begin;

select plan(8);

-- ==========================================================================
-- service_role can insert a fresh token claim
-- ==========================================================================

set local role service_role;

select lives_ok(
  $$insert into public.consumed_tokens (token_hash, install_id)
    values ('hash-aaa', 'install-1')$$,
  'consumed_tokens: service_role can claim a fresh token'
);

-- Second insert with same token_hash uses ON CONFLICT DO NOTHING — does not
-- error, no row created. Verify by checking only one row exists for the hash.
insert into public.consumed_tokens (token_hash, install_id)
values ('hash-aaa', 'install-2')
on conflict (token_hash) do nothing;

select is(
  (select count(*)::int from public.consumed_tokens where token_hash = 'hash-aaa'),
  1,
  'consumed_tokens: replay (second INSERT with same token_hash) was a no-op — still one row'
);

-- Verify the original install_id is preserved (replay didn't overwrite)
select is(
  (select install_id from public.consumed_tokens where token_hash = 'hash-aaa'),
  'install-1',
  'consumed_tokens: replay attempt did not overwrite original install_id'
);

-- Pre-invalidated row blocks consumption (delete-account path).
insert into public.consumed_tokens (token_hash, install_id, invalidated, invalidated_reason)
values ('hash-bbb', 'pre-invalidated-marker', true, 'sender_deleted');

insert into public.consumed_tokens (token_hash, install_id)
values ('hash-bbb', 'install-3')
on conflict (token_hash) do nothing;

select is(
  (select install_id from public.consumed_tokens where token_hash = 'hash-bbb'),
  'pre-invalidated-marker',
  'consumed_tokens: pre-invalidated token cannot be consumed (install_id unchanged)'
);

-- The Edge Function distinguishes replay vs invalidation via a follow-up
-- SELECT — verify that read works.
select is(
  (select invalidated from public.consumed_tokens where token_hash = 'hash-bbb'),
  true,
  'consumed_tokens: post-failure SELECT can distinguish invalidated rows'
);

-- ==========================================================================
-- RLS: anon cannot read consumed_tokens
-- ==========================================================================

reset role;
set local role anon;

select is(
  (select count(*)::int from public.consumed_tokens),
  0,
  'consumed_tokens RLS (anon): no rows visible'
);

-- ==========================================================================
-- RLS: authenticated cannot read or write
-- ==========================================================================

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated')::text,
  true
);

select is(
  (select count(*)::int from public.consumed_tokens),
  0,
  'consumed_tokens RLS (authenticated): no rows visible — service_role only'
);

select throws_ok(
  $$insert into public.consumed_tokens (token_hash, install_id)
    values ('hash-ccc', 'forged')$$,
  '42501',
  null,
  'consumed_tokens RLS (authenticated): INSERT rejected'
);

select * from finish();

rollback;
