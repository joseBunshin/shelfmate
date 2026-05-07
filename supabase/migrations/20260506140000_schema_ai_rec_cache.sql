-- U2 schema: ai_rec_cache + ai_not_interested.
--
-- Affected privacy tables: none directly (own-row only). User AI rec history
-- is private to the user; no cross-user visibility.
-- RLS: 20260506140100_rls_ai.sql (same commit).
-- pgTAP: 16_rls_ai_and_push.sql (same commit).
--
-- ai_rec_cache caches Claude responses to avoid hitting the Anthropic API
-- on every Discover tab open. TTL is captured in-row (generated_at +
-- ttl_seconds) so the cache freshness check is a simple comparison and
-- doesn't require a sweeper job.
--
-- ai_not_interested captures explicit user signals from the Discover tab
-- so the next Claude call can include them as exclusions in the prompt.

create table public.ai_rec_cache (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  -- input fingerprint for cache lookup (genres, recently-finished book ids,
  -- friends' recent finishes, etc.) — hashed by the app to a stable key
  cache_key text not null,
  query_context jsonb not null,
  recommended_book_ids uuid[] not null default array[]::uuid[],
  claude_model text not null,
  prompt_tokens int not null check (prompt_tokens >= 0),
  completion_tokens int not null check (completion_tokens >= 0),
  cost_cents numeric(10, 4) not null check (cost_cents >= 0),
  generated_at timestamptz not null default now(),
  ttl_seconds int not null default 3600 check (ttl_seconds > 0),
  unique (user_id, cache_key)
);

create index ai_rec_cache_user_freshness_idx on public.ai_rec_cache (
  user_id, generated_at desc
);

comment on table public.ai_rec_cache is
  'Cached Claude AI recommendations. Cache key is fingerprint of genres + recent activity. TTL captured in-row; freshness check is generated_at + ttl_seconds vs now().';

create table public.ai_not_interested (
  user_id uuid not null references public.users(id) on delete cascade,
  book_id uuid not null references public.books(id) on delete cascade,
  reason text check (reason is null or length(reason) <= 200),
  created_at timestamptz not null default now(),
  primary key (user_id, book_id)
);

comment on table public.ai_not_interested is
  'Per-user "not interested" signals from Discover tab. Fed into the next Claude prompt as exclusions.';
