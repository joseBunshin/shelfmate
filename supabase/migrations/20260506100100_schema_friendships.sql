-- U2 schema: friendships.
--
-- Affected privacy tables: friendships.
-- RLS policy: see 20260506100700_rls_friendships.sql (same commit).
--
-- Canonical pair ordering: user_id_a < user_id_b always, so each pair has
-- exactly one row regardless of who initiated. The CHECK constraint enforces
-- this. Lookups use fn_friendship_status / fn_is_blocked which normalize both
-- argument orders before querying.
--
-- Status enum:
--   pending — initiator sent request, recipient has not accepted yet
--   active  — both users are friends
--   blocked — one user blocked the other; blocked_by holds which one
--
-- Block enforcement (R6 + Phase 4 trust seam): blocks must be enforced AT THE
-- DATA LAYER, not the render layer. fn_is_blocked is called inside
-- fn_can_see_comment BEFORE the intersection check so a block always wins.

create type public.friendship_status as enum ('pending', 'active', 'blocked');

create table public.friendships (
  user_id_a uuid not null references public.users(id) on delete cascade,
  user_id_b uuid not null references public.users(id) on delete cascade,
  status public.friendship_status not null,
  initiated_by uuid not null references public.users(id) on delete cascade,
  blocked_by uuid references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id_a, user_id_b),
  constraint friendships_canonical_order check (user_id_a < user_id_b),
  constraint friendships_blocked_by_consistency check (
    (status = 'blocked' and blocked_by is not null and blocked_by in (user_id_a, user_id_b))
    or (status <> 'blocked' and blocked_by is null)
  ),
  constraint friendships_initiated_by_in_pair check (
    initiated_by in (user_id_a, user_id_b)
  )
);

create index friendships_user_a_status_idx on public.friendships (user_id_a, status);
create index friendships_user_b_status_idx on public.friendships (user_id_b, status);

create trigger friendships_updated_at before update on public.friendships
  for each row execute function public.tg_set_updated_at();

comment on table public.friendships is
  'Closed friend graph. Canonical pair ordering (user_id_a < user_id_b). Status: pending | active | blocked. blocked_by holds the blocker when status=blocked.';
