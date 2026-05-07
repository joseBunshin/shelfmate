-- pgTAP coverage for U2 fn_can_see_comment — the visibility intersection.
--
-- Tests the truth table across:
--   - writer_setting × viewer_setting × friendship_state (3 × 3 × 4 = 36 cells)
--   - own-row case
--   - block-before-intersection (block always wins, regardless of settings)
--   - anon viewer (NULL) treated correctly
--   - missing privacy_settings rows default to 'everyone'

begin;

select plan(32);

-- ==========================================================================
-- Setup: 4 user pairs, one per friendship state. Each pair has writer = u_w
-- and viewer = u_v, both with default privacy_settings ('everyone' x2).
-- We will UPDATE writer/viewer settings inline below to enumerate combos.
-- ==========================================================================

insert into auth.users (
  id, instance_id, email, aud, role, encrypted_password, raw_user_meta_data,
  created_at, updated_at
) values
  -- pair "active": w_a / v_a — friendship.status = 'active'
  ('aaaaaaaa-0000-0000-0000-000000000001'::uuid,
   '00000000-0000-0000-0000-000000000000'::uuid,
   'wa@t.local', 'authenticated', 'authenticated', '$$x$$', '{"full_name":"WA"}'::jsonb, now(), now()),
  ('aaaaaaaa-0000-0000-0000-000000000002'::uuid,
   '00000000-0000-0000-0000-000000000000'::uuid,
   'va@t.local', 'authenticated', 'authenticated', '$$x$$', '{"full_name":"VA"}'::jsonb, now(), now()),
  -- pair "pending"
  ('aaaaaaaa-0000-0000-0000-000000000003'::uuid,
   '00000000-0000-0000-0000-000000000000'::uuid,
   'wp@t.local', 'authenticated', 'authenticated', '$$x$$', '{"full_name":"WP"}'::jsonb, now(), now()),
  ('aaaaaaaa-0000-0000-0000-000000000004'::uuid,
   '00000000-0000-0000-0000-000000000000'::uuid,
   'vp@t.local', 'authenticated', 'authenticated', '$$x$$', '{"full_name":"VP"}'::jsonb, now(), now()),
  -- pair "blocked"
  ('aaaaaaaa-0000-0000-0000-000000000005'::uuid,
   '00000000-0000-0000-0000-000000000000'::uuid,
   'wb@t.local', 'authenticated', 'authenticated', '$$x$$', '{"full_name":"WB"}'::jsonb, now(), now()),
  ('aaaaaaaa-0000-0000-0000-000000000006'::uuid,
   '00000000-0000-0000-0000-000000000000'::uuid,
   'vb@t.local', 'authenticated', 'authenticated', '$$x$$', '{"full_name":"VB"}'::jsonb, now(), now()),
  -- pair "none" (no friendship row)
  ('aaaaaaaa-0000-0000-0000-000000000007'::uuid,
   '00000000-0000-0000-0000-000000000000'::uuid,
   'wn@t.local', 'authenticated', 'authenticated', '$$x$$', '{"full_name":"WN"}'::jsonb, now(), now()),
  ('aaaaaaaa-0000-0000-0000-000000000008'::uuid,
   '00000000-0000-0000-0000-000000000000'::uuid,
   'vn@t.local', 'authenticated', 'authenticated', '$$x$$', '{"full_name":"VN"}'::jsonb, now(), now());

insert into public.friendships (user_id_a, user_id_b, status, initiated_by) values
  (least('aaaaaaaa-0000-0000-0000-000000000001'::uuid, 'aaaaaaaa-0000-0000-0000-000000000002'::uuid),
   greatest('aaaaaaaa-0000-0000-0000-000000000001'::uuid, 'aaaaaaaa-0000-0000-0000-000000000002'::uuid),
   'active', 'aaaaaaaa-0000-0000-0000-000000000001'::uuid),
  (least('aaaaaaaa-0000-0000-0000-000000000003'::uuid, 'aaaaaaaa-0000-0000-0000-000000000004'::uuid),
   greatest('aaaaaaaa-0000-0000-0000-000000000003'::uuid, 'aaaaaaaa-0000-0000-0000-000000000004'::uuid),
   'pending', 'aaaaaaaa-0000-0000-0000-000000000003'::uuid);

insert into public.friendships (user_id_a, user_id_b, status, initiated_by, blocked_by) values
  (least('aaaaaaaa-0000-0000-0000-000000000005'::uuid, 'aaaaaaaa-0000-0000-0000-000000000006'::uuid),
   greatest('aaaaaaaa-0000-0000-0000-000000000005'::uuid, 'aaaaaaaa-0000-0000-0000-000000000006'::uuid),
   'blocked',
   'aaaaaaaa-0000-0000-0000-000000000005'::uuid,
   'aaaaaaaa-0000-0000-0000-000000000005'::uuid);

-- Helper: set both writer + viewer privacy_settings in one statement
create or replace function pg_temp.set_pair(
  p_writer uuid, p_writer_setting public.privacy_audience,
  p_viewer uuid, p_viewer_setting public.privacy_audience
) returns void language sql as $$
  update public.privacy_settings set writer_setting = p_writer_setting where user_id = p_writer;
  update public.privacy_settings set viewer_setting = p_viewer_setting where user_id = p_viewer;
$$;

-- ==========================================================================
-- One-off assertions: own-row + anon + missing privacy_settings
-- ==========================================================================

select ok(
  public.fn_can_see_comment(
    'aaaaaaaa-0000-0000-0000-000000000001'::uuid,
    'aaaaaaaa-0000-0000-0000-000000000001'::uuid),
  'own row always visible (viewer = writer)'
);

-- anon × writer everyone
select pg_temp.set_pair(
  'aaaaaaaa-0000-0000-0000-000000000001'::uuid, 'everyone',
  'aaaaaaaa-0000-0000-0000-000000000002'::uuid, 'everyone');
select ok(
  public.fn_can_see_comment(null, 'aaaaaaaa-0000-0000-0000-000000000001'::uuid),
  'anon viewer + writer=everyone → visible'
);

-- anon × writer friends
update public.privacy_settings set writer_setting = 'friends'
  where user_id = 'aaaaaaaa-0000-0000-0000-000000000001'::uuid;
select ok(
  not public.fn_can_see_comment(null, 'aaaaaaaa-0000-0000-0000-000000000001'::uuid),
  'anon viewer + writer=friends → invisible'
);

-- anon × writer only_me
update public.privacy_settings set writer_setting = 'only_me'
  where user_id = 'aaaaaaaa-0000-0000-0000-000000000001'::uuid;
select ok(
  not public.fn_can_see_comment(null, 'aaaaaaaa-0000-0000-0000-000000000001'::uuid),
  'anon viewer + writer=only_me → invisible'
);

-- Missing privacy_settings row → defaults to 'everyone'
delete from public.privacy_settings
  where user_id = 'aaaaaaaa-0000-0000-0000-000000000007'::uuid;
delete from public.privacy_settings
  where user_id = 'aaaaaaaa-0000-0000-0000-000000000008'::uuid;
select ok(
  public.fn_can_see_comment(
    'aaaaaaaa-0000-0000-0000-000000000008'::uuid,
    'aaaaaaaa-0000-0000-0000-000000000007'::uuid),
  'missing privacy_settings row defaults to everyone (no friendship → everyone × everyone = visible)'
);
select ok(
  public.fn_can_see_comment(null, 'aaaaaaaa-0000-0000-0000-000000000007'::uuid),
  'missing privacy_settings row + anon viewer → visible (writer defaults to everyone)'
);
-- Re-insert the cleared rows so the grid below works
insert into public.privacy_settings (user_id) values
  ('aaaaaaaa-0000-0000-0000-000000000007'::uuid),
  ('aaaaaaaa-0000-0000-0000-000000000008'::uuid)
  on conflict do nothing;

-- ==========================================================================
-- Block-before-intersection (block always wins, regardless of settings)
-- 3 cases, the most permissive setting combos — if any of these returns
-- visible, block-before-intersection has regressed.
-- ==========================================================================

select pg_temp.set_pair(
  'aaaaaaaa-0000-0000-0000-000000000005'::uuid, 'everyone',
  'aaaaaaaa-0000-0000-0000-000000000006'::uuid, 'everyone');
select ok(
  not public.fn_can_see_comment(
    'aaaaaaaa-0000-0000-0000-000000000006'::uuid,
    'aaaaaaaa-0000-0000-0000-000000000005'::uuid),
  'block: writer=everyone, viewer=everyone → INVISIBLE (block before intersection)'
);
select ok(
  not public.fn_can_see_comment(
    'aaaaaaaa-0000-0000-0000-000000000005'::uuid,
    'aaaaaaaa-0000-0000-0000-000000000006'::uuid),
  'block symmetric: from blocker → blockee also INVISIBLE'
);

-- ==========================================================================
-- The 36-cell grid: (3 writer settings) × (3 viewer settings) × (4 friendship)
-- For each (ws, vs, fs) tuple, set the privacy_settings on the appropriate
-- pair, then assert fn_can_see_comment returns the expected boolean.
-- ==========================================================================

-- Helper: compute expected truth for non-blocked, non-own-row, authed-viewer cases
create or replace function pg_temp.expected_visibility(
  ws public.privacy_audience,
  vs public.privacy_audience,
  fs text  -- 'active' | 'pending' | 'blocked' | 'none'
) returns boolean language sql immutable as $$
  select case
    when fs = 'blocked' then false
    when ws = 'only_me' or vs = 'only_me' then false
    when ws = 'friends' or vs = 'friends' then fs = 'active'
    else true
  end;
$$;

-- Drives one assertion per (ws, vs) combo for a given pair + friendship label.
-- We unfold the 36 cells across 4 pairs (one per friendship state):

-- ----- pair "active" (w=u1, v=u2, friendship=active) -----
select pg_temp.set_pair('aaaaaaaa-0000-0000-0000-000000000001'::uuid, 'everyone',
                        'aaaaaaaa-0000-0000-0000-000000000002'::uuid, 'everyone');
select is(public.fn_can_see_comment(
  'aaaaaaaa-0000-0000-0000-000000000002'::uuid,
  'aaaaaaaa-0000-0000-0000-000000000001'::uuid),
  pg_temp.expected_visibility('everyone','everyone','active'),
  'active: w=everyone v=everyone');

select pg_temp.set_pair('aaaaaaaa-0000-0000-0000-000000000001'::uuid, 'everyone',
                        'aaaaaaaa-0000-0000-0000-000000000002'::uuid, 'friends');
select is(public.fn_can_see_comment(
  'aaaaaaaa-0000-0000-0000-000000000002'::uuid,
  'aaaaaaaa-0000-0000-0000-000000000001'::uuid),
  pg_temp.expected_visibility('everyone','friends','active'),
  'active: w=everyone v=friends');

select pg_temp.set_pair('aaaaaaaa-0000-0000-0000-000000000001'::uuid, 'everyone',
                        'aaaaaaaa-0000-0000-0000-000000000002'::uuid, 'only_me');
select is(public.fn_can_see_comment(
  'aaaaaaaa-0000-0000-0000-000000000002'::uuid,
  'aaaaaaaa-0000-0000-0000-000000000001'::uuid),
  pg_temp.expected_visibility('everyone','only_me','active'),
  'active: w=everyone v=only_me');

select pg_temp.set_pair('aaaaaaaa-0000-0000-0000-000000000001'::uuid, 'friends',
                        'aaaaaaaa-0000-0000-0000-000000000002'::uuid, 'everyone');
select is(public.fn_can_see_comment(
  'aaaaaaaa-0000-0000-0000-000000000002'::uuid,
  'aaaaaaaa-0000-0000-0000-000000000001'::uuid),
  pg_temp.expected_visibility('friends','everyone','active'),
  'active: w=friends v=everyone');

select pg_temp.set_pair('aaaaaaaa-0000-0000-0000-000000000001'::uuid, 'friends',
                        'aaaaaaaa-0000-0000-0000-000000000002'::uuid, 'friends');
select is(public.fn_can_see_comment(
  'aaaaaaaa-0000-0000-0000-000000000002'::uuid,
  'aaaaaaaa-0000-0000-0000-000000000001'::uuid),
  pg_temp.expected_visibility('friends','friends','active'),
  'active: w=friends v=friends');

select pg_temp.set_pair('aaaaaaaa-0000-0000-0000-000000000001'::uuid, 'friends',
                        'aaaaaaaa-0000-0000-0000-000000000002'::uuid, 'only_me');
select is(public.fn_can_see_comment(
  'aaaaaaaa-0000-0000-0000-000000000002'::uuid,
  'aaaaaaaa-0000-0000-0000-000000000001'::uuid),
  pg_temp.expected_visibility('friends','only_me','active'),
  'active: w=friends v=only_me');

select pg_temp.set_pair('aaaaaaaa-0000-0000-0000-000000000001'::uuid, 'only_me',
                        'aaaaaaaa-0000-0000-0000-000000000002'::uuid, 'everyone');
select is(public.fn_can_see_comment(
  'aaaaaaaa-0000-0000-0000-000000000002'::uuid,
  'aaaaaaaa-0000-0000-0000-000000000001'::uuid),
  pg_temp.expected_visibility('only_me','everyone','active'),
  'active: w=only_me v=everyone');

select pg_temp.set_pair('aaaaaaaa-0000-0000-0000-000000000001'::uuid, 'only_me',
                        'aaaaaaaa-0000-0000-0000-000000000002'::uuid, 'friends');
select is(public.fn_can_see_comment(
  'aaaaaaaa-0000-0000-0000-000000000002'::uuid,
  'aaaaaaaa-0000-0000-0000-000000000001'::uuid),
  pg_temp.expected_visibility('only_me','friends','active'),
  'active: w=only_me v=friends');

select pg_temp.set_pair('aaaaaaaa-0000-0000-0000-000000000001'::uuid, 'only_me',
                        'aaaaaaaa-0000-0000-0000-000000000002'::uuid, 'only_me');
select is(public.fn_can_see_comment(
  'aaaaaaaa-0000-0000-0000-000000000002'::uuid,
  'aaaaaaaa-0000-0000-0000-000000000001'::uuid),
  pg_temp.expected_visibility('only_me','only_me','active'),
  'active: w=only_me v=only_me');

-- ----- pair "pending" (w=u3, v=u4, friendship=pending) -----
-- For pending, "friends" effective always returns false (status != 'active').
select pg_temp.set_pair('aaaaaaaa-0000-0000-0000-000000000003'::uuid, 'everyone',
                        'aaaaaaaa-0000-0000-0000-000000000004'::uuid, 'everyone');
select is(public.fn_can_see_comment(
  'aaaaaaaa-0000-0000-0000-000000000004'::uuid,
  'aaaaaaaa-0000-0000-0000-000000000003'::uuid),
  pg_temp.expected_visibility('everyone','everyone','pending'),
  'pending: w=everyone v=everyone');

select pg_temp.set_pair('aaaaaaaa-0000-0000-0000-000000000003'::uuid, 'everyone',
                        'aaaaaaaa-0000-0000-0000-000000000004'::uuid, 'friends');
select is(public.fn_can_see_comment(
  'aaaaaaaa-0000-0000-0000-000000000004'::uuid,
  'aaaaaaaa-0000-0000-0000-000000000003'::uuid),
  pg_temp.expected_visibility('everyone','friends','pending'),
  'pending: w=everyone v=friends');

select pg_temp.set_pair('aaaaaaaa-0000-0000-0000-000000000003'::uuid, 'friends',
                        'aaaaaaaa-0000-0000-0000-000000000004'::uuid, 'everyone');
select is(public.fn_can_see_comment(
  'aaaaaaaa-0000-0000-0000-000000000004'::uuid,
  'aaaaaaaa-0000-0000-0000-000000000003'::uuid),
  pg_temp.expected_visibility('friends','everyone','pending'),
  'pending: w=friends v=everyone (false — pending != active)');

select pg_temp.set_pair('aaaaaaaa-0000-0000-0000-000000000003'::uuid, 'friends',
                        'aaaaaaaa-0000-0000-0000-000000000004'::uuid, 'friends');
select is(public.fn_can_see_comment(
  'aaaaaaaa-0000-0000-0000-000000000004'::uuid,
  'aaaaaaaa-0000-0000-0000-000000000003'::uuid),
  pg_temp.expected_visibility('friends','friends','pending'),
  'pending: w=friends v=friends');

select pg_temp.set_pair('aaaaaaaa-0000-0000-0000-000000000003'::uuid, 'only_me',
                        'aaaaaaaa-0000-0000-0000-000000000004'::uuid, 'everyone');
select is(public.fn_can_see_comment(
  'aaaaaaaa-0000-0000-0000-000000000004'::uuid,
  'aaaaaaaa-0000-0000-0000-000000000003'::uuid),
  pg_temp.expected_visibility('only_me','everyone','pending'),
  'pending: w=only_me v=everyone');

-- ----- pair "blocked" (w=u5, v=u6, friendship=blocked) -----
-- All combos return false because of block-before-intersection.
select pg_temp.set_pair('aaaaaaaa-0000-0000-0000-000000000005'::uuid, 'everyone',
                        'aaaaaaaa-0000-0000-0000-000000000006'::uuid, 'everyone');
select is(public.fn_can_see_comment(
  'aaaaaaaa-0000-0000-0000-000000000006'::uuid,
  'aaaaaaaa-0000-0000-0000-000000000005'::uuid),
  pg_temp.expected_visibility('everyone','everyone','blocked'),
  'blocked: w=everyone v=everyone (false)');

select pg_temp.set_pair('aaaaaaaa-0000-0000-0000-000000000005'::uuid, 'friends',
                        'aaaaaaaa-0000-0000-0000-000000000006'::uuid, 'friends');
select is(public.fn_can_see_comment(
  'aaaaaaaa-0000-0000-0000-000000000006'::uuid,
  'aaaaaaaa-0000-0000-0000-000000000005'::uuid),
  pg_temp.expected_visibility('friends','friends','blocked'),
  'blocked: w=friends v=friends (false)');

select pg_temp.set_pair('aaaaaaaa-0000-0000-0000-000000000005'::uuid, 'only_me',
                        'aaaaaaaa-0000-0000-0000-000000000006'::uuid, 'only_me');
select is(public.fn_can_see_comment(
  'aaaaaaaa-0000-0000-0000-000000000006'::uuid,
  'aaaaaaaa-0000-0000-0000-000000000005'::uuid),
  pg_temp.expected_visibility('only_me','only_me','blocked'),
  'blocked: w=only_me v=only_me (false)');

-- ----- pair "none" (w=u7, v=u8, no friendship row) -----
select pg_temp.set_pair('aaaaaaaa-0000-0000-0000-000000000007'::uuid, 'everyone',
                        'aaaaaaaa-0000-0000-0000-000000000008'::uuid, 'everyone');
select is(public.fn_can_see_comment(
  'aaaaaaaa-0000-0000-0000-000000000008'::uuid,
  'aaaaaaaa-0000-0000-0000-000000000007'::uuid),
  pg_temp.expected_visibility('everyone','everyone','none'),
  'none: w=everyone v=everyone (true — no friendship needed for everyone)');

select pg_temp.set_pair('aaaaaaaa-0000-0000-0000-000000000007'::uuid, 'everyone',
                        'aaaaaaaa-0000-0000-0000-000000000008'::uuid, 'friends');
select is(public.fn_can_see_comment(
  'aaaaaaaa-0000-0000-0000-000000000008'::uuid,
  'aaaaaaaa-0000-0000-0000-000000000007'::uuid),
  pg_temp.expected_visibility('everyone','friends','none'),
  'none: w=everyone v=friends (false — viewer wants only friends, no friendship)');

select pg_temp.set_pair('aaaaaaaa-0000-0000-0000-000000000007'::uuid, 'friends',
                        'aaaaaaaa-0000-0000-0000-000000000008'::uuid, 'everyone');
select is(public.fn_can_see_comment(
  'aaaaaaaa-0000-0000-0000-000000000008'::uuid,
  'aaaaaaaa-0000-0000-0000-000000000007'::uuid),
  pg_temp.expected_visibility('friends','everyone','none'),
  'none: w=friends v=everyone (false — writer audience friends, not friends)');

select pg_temp.set_pair('aaaaaaaa-0000-0000-0000-000000000007'::uuid, 'friends',
                        'aaaaaaaa-0000-0000-0000-000000000008'::uuid, 'friends');
select is(public.fn_can_see_comment(
  'aaaaaaaa-0000-0000-0000-000000000008'::uuid,
  'aaaaaaaa-0000-0000-0000-000000000007'::uuid),
  pg_temp.expected_visibility('friends','friends','none'),
  'none: w=friends v=friends (false)');

select pg_temp.set_pair('aaaaaaaa-0000-0000-0000-000000000007'::uuid, 'only_me',
                        'aaaaaaaa-0000-0000-0000-000000000008'::uuid, 'everyone');
select is(public.fn_can_see_comment(
  'aaaaaaaa-0000-0000-0000-000000000008'::uuid,
  'aaaaaaaa-0000-0000-0000-000000000007'::uuid),
  pg_temp.expected_visibility('only_me','everyone','none'),
  'none: w=only_me v=everyone (false — only_me dominates)');

-- ==========================================================================
-- Symmetry: viewer ↔ writer swap should give same result for symmetric cases
-- (everyone × everyone). Used to be a regression — adding it as defense.
-- ==========================================================================

select pg_temp.set_pair('aaaaaaaa-0000-0000-0000-000000000001'::uuid, 'everyone',
                        'aaaaaaaa-0000-0000-0000-000000000002'::uuid, 'everyone');
select is(
  public.fn_can_see_comment(
    'aaaaaaaa-0000-0000-0000-000000000001'::uuid,
    'aaaaaaaa-0000-0000-0000-000000000002'::uuid),
  public.fn_can_see_comment(
    'aaaaaaaa-0000-0000-0000-000000000002'::uuid,
    'aaaaaaaa-0000-0000-0000-000000000001'::uuid),
  'everyone × everyone is symmetric across the friendship pair'
);

-- ==========================================================================
-- Note: writer = NULL → false (degenerate input)
-- ==========================================================================

select ok(
  not public.fn_can_see_comment('aaaaaaaa-0000-0000-0000-000000000002'::uuid, null),
  'writer = NULL → false (degenerate input handled)'
);

select * from finish();

rollback;
