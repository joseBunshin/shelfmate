-- U2 visibility intersection function: fn_can_see_comment.
--
-- The trust seam. Resolves whether a viewer can see a writer's comment/note
-- given:
--   - writer's writer_setting (looked up server-side from privacy_settings)
--   - viewer's viewer_setting (looked up server-side from privacy_settings)
--   - friendship state between them
--   - block state (block-before-intersection per R6)
--
-- SECURITY DEFINER + server-side lookups: viewer_id is set by RLS callers via
-- auth.uid() (which reads from the JWT, not the client). The client cannot
-- spoof writer_setting or viewer_setting because we never read them from
-- session state (no current_setting or set_config calls).
--
-- Logic:
--   1. viewer = writer → true (always see own)
--   2. blocked → false (block always wins, before intersection)
--   3. anon viewer (NULL) → true iff writer_setting = 'everyone'
--   4. authed viewer → effective = MAX_RESTRICT(writer_setting, viewer_setting)
--      — only_me → false (own case already handled in step 1)
--      — friends → true iff friendship.status = 'active'
--      — everyone → true
--
-- Restrictiveness ordering (most → least): only_me > friends > everyone.

create or replace function public.fn_can_see_comment(viewer uuid, writer uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_writer_setting public.privacy_audience;
  v_viewer_setting public.privacy_audience;
  v_effective public.privacy_audience;
begin
  if writer is null then
    return false;
  end if;

  -- 1. own row
  if viewer is not null and viewer = writer then
    return true;
  end if;

  -- 2. block-before-intersection (R6, non-negotiable)
  if viewer is not null and public.fn_is_blocked(viewer, writer) then
    return false;
  end if;

  -- 3. resolve writer setting (default everyone when no row)
  select writer_setting into v_writer_setting
    from public.privacy_settings where user_id = writer;
  v_writer_setting := coalesce(v_writer_setting, 'everyone'::public.privacy_audience);

  -- 4. anon path
  if viewer is null then
    return v_writer_setting = 'everyone';
  end if;

  -- 5. resolve viewer setting (default everyone when no row)
  select viewer_setting into v_viewer_setting
    from public.privacy_settings where user_id = viewer;
  v_viewer_setting := coalesce(v_viewer_setting, 'everyone'::public.privacy_audience);

  -- 6. most-restrictive-wins intersection
  v_effective := case
    when v_writer_setting = 'only_me' or v_viewer_setting = 'only_me' then 'only_me'
    when v_writer_setting = 'friends' or v_viewer_setting = 'friends' then 'friends'
    else 'everyone'
  end::public.privacy_audience;

  -- 7. apply effective to friendship state. fn_friendship_status returns
  -- NULL when no friendship row exists; coalesce so the function returns
  -- a clean boolean rather than NULL (RLS treats NULL as false anyway,
  -- but direct callers expect a non-NULL boolean).
  if v_effective = 'only_me' then
    return false;
  elsif v_effective = 'friends' then
    return coalesce(public.fn_friendship_status(viewer, writer) = 'active', false);
  else
    return true;
  end if;
end;
$$;

comment on function public.fn_can_see_comment(uuid, uuid) is
  'The trust seam. Returns whether viewer can see writer''s comment/note. SECURITY DEFINER — both privacy settings looked up server-side; never reads client-controllable session state.';
