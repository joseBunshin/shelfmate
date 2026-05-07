# AGENTS.md — ShelfMate repo conventions

This file documents conventions that any agent or human contributor should follow when working in this repo. The compound-engineering tools (`/ce-plan`, `/ce-doc-review`, `/ce-work`, etc.) auto-discover this file.

## Project tracker

```yaml
project_tracker: github
```

Issues live at https://github.com/joseBunshin/shelfmate/issues. v1 implementation issue: #1.

## Source-of-truth ordering

1. **`buildspec/`** — immutable product spec (7 .docx files: spec, personas, workflows, IA, handoffs, stories, MVP). Story acceptance criteria in `shelfmate_05_stories.docx` are the implementer-facing contract. **Do not modify.**
2. **`docs/brainstorms/`** — architectural decision documents. R-IDs (R1-R28) defined here trace from buildspec into implementation.
3. **`docs/plans/`** — phased implementation plans. U-IDs (U1-U8) defined here. Plan documents are decision artifacts; per-unit progress is derived from git, not stored in the plan.
4. **`docs/solutions/`** — institutional learnings, populated as issues emerge during implementation.
5. **`app/`, `web/`, `supabase/`** — code. Three deployables in one monorepo.

## Repo layout

- `app/` — Flutter mobile app (iOS + Android), Riverpod state
- `web/` — Next.js (App Router) on Vercel — five non-user landing pages, anon-role Supabase queries only
- `supabase/` — Postgres migrations, RLS policies, Edge Functions, pgTAP tests
- `docs/` — brainstorms, plans, solutions
- `buildspec/` — immutable product spec
- `.github/workflows/` — CI/CD for all three deployables

## Privacy-affected migration discipline (load-bearing)

The comment-visibility intersection rule (origin R7 + Phase 4 "trust seam") is enforced by Postgres RLS policies. To prevent silent visibility regressions:

**Every migration that touches one of the privacy-affected tables MUST include an accompanying RLS policy update in the same commit.**

Privacy-affected tables: `users`, `privacy_settings`, `comments`, `user_books`, `friendships`, `book_lists`, `book_list_shares`, `recommendations`, `profiles`.

Mechanism enforcement:
1. **PR template checklist** (`.github/pull_request_template.md`) — author confirms the rule
2. **CI gate** (`supabase-ci.yml` runs the pgTAP suite) — schema changes that would cause `fn_can_see_comment` to return wrong results fail at merge
3. **AGENTS.md convention** (this section) — backstop documentation

If a migration must change a privacy-affected table without an RLS update (rare, e.g., adding a non-visibility-bearing index), state the reason in the migration's `-- Note:` comment.

## File naming conventions

### Postgres migrations (`supabase/migrations/`)

- `YYYYMMDDHHMMSS_<descriptive_slug>.sql` — UTC timestamp + snake_case slug
- Sequential ordering matters — Supabase replays in lexical order
- Example: `20260601120000_add_currently_reading_visibility.sql`

### RLS policies (`supabase/policies/`)

- One file per table: `<table>.sql`
- Contains all RLS policies for that table — anon-role + authenticated + service-role
- The `policies/` directory is for documentation/review; CI applies policies via the `migrations/` directory

### Edge Functions (`supabase/functions/`)

- One directory per function: `supabase/functions/<function-name>/index.ts`
- Function names are kebab-case
- Each function declares its required JWT claims at the top of `index.ts` in a comment block

### pgTAP tests (`supabase/tests/`)

- `NN_<topic>.sql` where `NN` is a two-digit prefix for ordering
- Example: `01_visibility_intersection.sql`, `02_rls_comments.sql`

### Flutter (`app/lib/`)

- Feature-first organization: `app/lib/features/<feature>/{data,domain,presentation}/`
- Shared infrastructure under `app/lib/core/`
- File names are snake_case (Dart convention)
- Riverpod providers use code generation (`riverpod_annotation` + `riverpod_generator`)

### Tests

**Test colocation rule:** every implementation file has a corresponding test file in a parallel structure under `test/`:

- `app/lib/features/auth/data/auth_repository.dart` → `app/test/features/auth/data/auth_repository_test.dart`
- `web/app/rec/[recId]/page.tsx` → `web/tests/app/rec/[recId]/page.test.tsx`

Integration / E2E tests (multi-layer scenarios that mocks alone won't prove):

- Flutter: `app/integration_test/<flow>_e2e_test.dart`
- Web: `web/tests/e2e/<flow>.spec.ts` (Playwright)

## Privacy invalidator discipline (Riverpod)

Per origin R8 + the plan's Key Technical Decisions, every Riverpod provider that reads from a privacy-affected table must register with `PrivacyInvalidator` so privacy-setting changes invalidate the cache.

Three-layer enforcement:
1. **Static lint rule** (`app/analysis_options.yaml`) — flags providers reading `privacy_settings` directly without `PrivacyInvalidator.register()`
2. **Runtime registry test** in `supabase/tests/` — introspects `pg_catalog` for tables in the privacy-affected set and verifies all Riverpod providers querying them are registered (catches join-based reads the lint rule misses)
3. **AGENTS.md convention** (this section)

## Cover image proxy invariant

URLs embedded in `Recommendation` records (R12) and rendered on non-user landing pages (R10/R12) MUST be Supabase Storage URLs, never raw Open Library / Google Books URLs. The `proxy-cover` Edge Function fetches and re-hosts at rec-creation time. Raw third-party URLs in landing-page payloads are a security gap (third-party CDN compromise → ShelfMate landing-page injection) and an availability gap (3rd-party outage → broken cover above the fold).

## Code style

### Dart

- `dart format` is the formatter; CI enforces.
- `flutter analyze` must be green; CI enforces.
- Riverpod codegen: run `dart run build_runner watch -d` during development; CI runs `build_runner build` before `flutter analyze`.

### TypeScript

- ESLint + Prettier configured per `web/.eslintrc.json` + `web/.prettierrc.json`.
- Strict TypeScript (`"strict": true` in `tsconfig.json`).
- `web/lib/supabase.ts` uses the **anon role** key only — never `SUPABASE_SERVICE_ROLE_KEY`. ESLint rule blocks any import path matching `service.role` / `service_role`. Primary control: `SUPABASE_SERVICE_ROLE_KEY` is never configured in the Vercel project's environment variables.

### SQL

- Lower-case keywords (`select`, `from`, `where`, `update`).
- Snake-case identifiers.
- Comment-block at top of every migration file with: purpose, affected tables, related RLS policy file (if applicable).

## Secrets management

Per origin R28: secrets stored only in GitHub Actions encrypted secrets with environment scoping. Never accessible to fork-PR workflow runs. Build logs configured to mask secret values. Each secret scoped to dev / beta / prod environments.

Production secrets (managed externally to the repo):
- `ANTHROPIC_API_KEY` (production), `ANTHROPIC_API_KEY_DEV` (development)
- `SUPABASE_PROJECT_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` (per-env)
- `BRANCH_KEY`, `BRANCH_SECRET` (per-env)
- `SENTRY_DSN_APP`, `SENTRY_DSN_WEB` (per-env)
- `APPLE_SIGNING_CERT_P12`, `APPLE_SIGNING_CERT_PASSWORD`, `APPLE_PROVISIONING_PROFILE`, `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_SIGN_IN_KEY_P8`, `APPLE_SERVICES_ID`
- `GOOGLE_PLAY_KEYSTORE_JKS`, `GOOGLE_PLAY_KEYSTORE_PASSWORD`, `GOOGLE_PLAY_KEY_ALIAS`, `GOOGLE_PLAY_KEY_PASSWORD`, `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`
- `REVALIDATION_SECRET` (shared between Vercel env var and Supabase Database Secret)
- `VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID`

## Conventional commits

Use [conventional commits](https://www.conventionalcommits.org/) format:

- `feat(scope): ...` — new feature
- `fix(scope): ...` — bug fix
- `chore(scope): ...` — tooling, deps, repo plumbing
- `docs(scope): ...` — documentation only
- `test(scope): ...` — tests only
- `refactor(scope): ...` — refactor without behavior change

Scopes mirror feature directories: `auth`, `library`, `book-detail`, `friends`, `recommendations`, `lists`, `discover`, `share-card`, `settings`, `web`, `supabase`, `ci`.

## Branch naming

- `feat/<descriptive-name>` for features (e.g., `feat/u1-foundation`)
- `fix/<descriptive-name>` for bug fixes
- `refactor/<descriptive-name>` for refactors
- Auto-generated worktree names get renamed before the first commit lands

## When in doubt

Read `docs/plans/` for the current implementation plan and `docs/brainstorms/` for the architectural decisions that shaped it. The buildspec is the spec of record.
