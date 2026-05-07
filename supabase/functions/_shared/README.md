# Shared Edge Function helpers

Per Supabase convention, code shared across Edge Functions lives in
`functions/_shared/`. The leading underscore prevents Supabase from
treating this directory as its own deployable function.

Edge Functions land in U2 onward:
- `verify-referrer/` — U3 — Branch token validation with INSERT ON CONFLICT
- `claude-rec/` — U6 — JWT-gated Claude API proxy
- `proxy-cover/` — U4/U5 — Open Library cover → Supabase Storage
- `delete-account/` — U2 — account deletion orchestration
- `revalidate-list/` — U7 — Vercel revalidation webhook target
- `monitor-pg-net/` — U7 — pg_net failure detection cron
- `upload-avatar/` — U8 — magic-bytes validation for avatar uploads
