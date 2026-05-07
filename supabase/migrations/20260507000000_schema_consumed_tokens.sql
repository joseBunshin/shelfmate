-- U3 schema: consumed_tokens — Branch deferred-deep-link replay protection (R26).
--
-- Affected privacy tables: none directly. consumed_tokens is internal
-- bookkeeping for the verify-referrer Edge Function; it never carries
-- user-readable content.
--
-- Mechanism (R26 + plan U3):
--   1. Friend A generates an invite link; Branch.io issues a token.
--   2. Friend B installs the app, Branch returns the referrer token on
--      first run.
--   3. Flutter calls verify-referrer Edge Function with token + install_id.
--   4. The Edge Function does:
--        INSERT INTO consumed_tokens (token_hash, install_id, consumed_at)
--          VALUES (sha256($1), $2, now())
--          ON CONFLICT (token_hash) DO NOTHING
--          RETURNING id;
--      A NULL return means the token was already consumed (replay) OR was
--      pre-invalidated by delete-account. Either way: reject the friend
--      connect and fall through to manual-add path.
--
-- Account-deletion race (R23): when a user deletes their account, any
-- outstanding referrer tokens they issued must NOT subsequently match a
-- new install. The delete-account Edge Function pre-writes invalidated=
-- true rows for every unconsumed token tied to the deleted user. The
-- ON CONFLICT in step 4 above will then return NULL because a row with
-- the matching token_hash already exists.

create table public.consumed_tokens (
  token_hash text primary key,
  install_id text not null,
  consumed_at timestamptz not null default now(),
  invalidated boolean not null default false,
  invalidated_reason text check (
    invalidated_reason is null
    or invalidated_reason in ('sender_deleted', 'manual')
  )
);

create index consumed_tokens_install_idx on public.consumed_tokens (install_id);

comment on table public.consumed_tokens is
  'R26 replay-protection table for Branch referrer tokens. INSERT ON CONFLICT DO NOTHING is the atomic claim; a NULL return means replay or pre-invalidation. Rows with invalidated=true are pre-written by delete-account.';

-- ==========================================================================
-- RLS — internal table; no client access. service_role only.
-- ==========================================================================

alter table public.consumed_tokens enable row level security;

create policy consumed_tokens_service_all on public.consumed_tokens
  for all to service_role
  using (true)
  with check (true);

-- No authenticated or anon policies — clients never read or write directly.
-- The verify-referrer Edge Function uses service_role to claim tokens.
