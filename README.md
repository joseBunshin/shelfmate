# ShelfMate

Personal book tracking + closed-friend-graph sharing mobile app for iOS + Android.

A Bunshin Development Studios Labs project. v1 in active development.

- **Product spec (immutable):** [`buildspec/`](buildspec/) — 7 .docx files covering personas, workflows, IA, handoffs, 68 stories across 11 epics, and the MVP scope contract
- **Architecture decisions:** [`docs/brainstorms/2026-05-06-tech-stack-architecture-requirements.md`](docs/brainstorms/2026-05-06-tech-stack-architecture-requirements.md) — R1-R28
- **Implementation plan:** [`docs/plans/2026-05-06-001-feat-shelfmate-v1-implementation-plan.md`](docs/plans/2026-05-06-001-feat-shelfmate-v1-implementation-plan.md) — 8 units across 3 waves
- **Repo conventions:** [`AGENTS.md`](AGENTS.md)
- **v1 implementation issue:** [#1](https://github.com/joseBunshin/shelfmate/issues/1)

## Tech stack

| Layer | Choice | Notes |
|---|---|---|
| Mobile | Flutter + Riverpod | iOS + Android, single codebase |
| Backend | Supabase | Postgres + RLS + Auth + Storage + Edge Functions |
| Non-user web | Next.js on Vercel | 5 landing pages, edge SSR, anon-role only |
| Deferred deep linking | Branch.io free tier | Survives App Store install |
| AI recs | Anthropic Claude | Server-side via Supabase Edge Function |
| CI/CD | GitHub Actions | Per-deployable workflow |
| Errors | Sentry | App + Web projects |
| Beta | TestFlight + Play Internal | Standard distribution |

## Repo layout

```
ShelfMate/
├── app/                          # Flutter mobile app (iOS + Android)
├── web/                          # Next.js for non-user landing pages
├── supabase/                     # Postgres migrations + RLS + Edge Functions
├── docs/                         # brainstorms, plans, solutions
├── buildspec/                    # immutable product spec
├── .github/workflows/            # CI/CD
├── AGENTS.md                     # repo conventions
├── README.md                     # this file
└── .gitignore
```

## Local development

### Prerequisites

- **Flutter** 3.x stable channel — install from [flutter.dev](https://flutter.dev)
- **Node.js** 20+ — install from [nodejs.org](https://nodejs.org/) or via nvm
- **Supabase CLI** — install per [supabase.com/docs/guides/local-development/cli/getting-started](https://supabase.com/docs/guides/local-development/cli/getting-started). On Windows: `scoop install supabase` (after `scoop bucket add supabase https://github.com/supabase/scoop-bucket.git`).
- **Docker Desktop** — required by `supabase start` for the local Postgres + pgTAP stack
- **Xcode** (macOS only) — for iOS builds + iOS Simulator
- **Android Studio + Android SDK** — for Android builds + emulator

### Boot the three deployables

```bash
# 1. Supabase local stack (Postgres + Auth + Storage + Edge Functions)
cd supabase
supabase start
# Records local API URL + anon key — copy into app/.env and web/.env.local

# 2. Flutter app
cd ../app
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Riverpod codegen
flutter run                                                 # picks an emulator/device

# 3. Next.js web
cd ../web
npm install
npm run dev                                                 # http://localhost:3000
```

### Run tests

```bash
# Flutter unit + widget
cd app && flutter test

# Flutter integration (needs running device)
cd app && flutter test integration_test

# Next.js
cd web && npm test

# Supabase pgTAP (RLS correctness suite)
cd supabase && supabase test db
```

## U1.2 — User-action checklist

The implementation plan's U1 unit has agent-doable scaffolding (this commit) and user-only setup. **You** need to complete the following before U1.3 wires integrations:

### Accounts to create

- [ ] **Apple Developer Program** ($99/yr) — required for TestFlight + App Store. Enroll at [developer.apple.com/programs](https://developer.apple.com/programs/)
- [ ] **Google Play Developer** ($25 one-time) — required for Play Internal Testing + Play Store. Enroll at [play.google.com/console](https://play.google.com/console/)
- [ ] **Branch.io free tier** — sign up at [branch.io](https://branch.io). Verify the actual free-tier MAU cap during signup (origin doc flagged "~250K MAU" as needing verification — actual cap may be ~10K MAU; if low, revisit build-vs-buy on a custom redirect server). Configure two link domains: `link.shelfmate.app` (prod) and `link-staging.shelfmate.app`. iOS Privacy Manifest entries should be added to `app/ios/Runner/PrivacyInfo.xcprivacy` per Branch's current docs.
- [ ] **Vercel** Hobby tier — sign up at [vercel.com](https://vercel.com). Link the repo to a new Vercel project for `web/`. Region: `iad1` (us-east, co-located with Supabase region — see below).
- [ ] **Supabase** free tier — create a new project at [supabase.com/dashboard](https://supabase.com/dashboard) in region **`us-east-1`**. Note the project URL and anon key.
- [ ] **Sentry Developer tier** — create one project per surface: `shelfmate-app` (Flutter) and `shelfmate-web` (Next.js).
- [ ] **Anthropic Console** — create a new project. **Set monthly spend cap to $50/mo before any Claude API call ships.** Production key separate from dev.

### Apple Sign In configuration (load-bearing for E1 / R3 / R4)

Apple Sign In is non-negotiable for App Store approval (Apple Review §5.1.1) since we're offering Google Sign In. Setup:

- [ ] In Apple Developer console, create a **Services ID** for ShelfMate's web-OAuth path. Return URL: `https://<supabase-project-ref>.supabase.co/auth/v1/callback`.
- [ ] Generate a **Sign In with Apple key** (`.p8`). Save the key file securely; you'll need it as a GHA secret.
- [ ] Note the **Team ID** and **Key ID**.
- [ ] In Supabase Auth dashboard → Providers → Apple, populate: team ID, key ID, `.p8` contents, Services ID, and the Bundle ID for the iOS app.
- [ ] Both the native iOS Bundle ID AND the Services ID must be associated with the same Sign In with Apple key.
- [ ] (For Android web-OAuth fallback) host an `assetlinks.json` file at `https://<your-domain>/.well-known/assetlinks.json` for Android App Links domain verification.

### Signing certificates

- [ ] iOS: provisioning profile + signing cert via Xcode or fastlane match. Export as `.p12` for GHA.
- [ ] Android: generate keystore (`keytool -genkey -v -keystore release.jks ...`). Save passphrase securely.
- [ ] Google Play upload key + service account JSON for automated publishing.

### Domains

- [ ] **Domain registration**: `shelfmate.app` (or alternative TLD if `.app` is unavailable). Verify ShelfMate name availability on Apple App Store + Google Play before submitting U8 binaries.

### GHA secrets to upload

Once accounts are created and certs are generated, upload the secrets listed in [`AGENTS.md`](AGENTS.md#secrets-management) to GitHub Actions. Use environment scoping (dev / beta / prod).

```bash
# Example for one secret:
gh secret set ANTHROPIC_API_KEY --env prod --body "sk-ant-..."
gh secret set SENTRY_DSN_APP --env prod --body "https://..."
# ... etc
```

### Supabase database secrets (for pg_net trigger)

```bash
# After supabase login + supabase link to your project:
supabase secrets set REVALIDATION_SECRET="<generate-via-openssl-rand-hex-32>"
# Same value also goes into Vercel env var as REVALIDATION_SECRET
```

## U1.3 — Wire integrations (next session)

After U1.2 is complete, the next session will:

- Wire Sentry init in `app/lib/core/sentry/` and `web/lib/sentry.ts` with the real DSNs
- Initialize Supabase client in `app/lib/core/supabase/client.dart` with project URL + anon key
- Initialize Branch SDK in `app/lib/core/branch/branch_init.dart` with the Branch key
- Wire `app/lib/core/auth/` for Supabase Auth with all 3 providers
- Wire `app-release.yml` GHA workflow with signing secrets
- Verify smoke tests still green
- Prepare to start U2 (data layer + RLS + pgTAP)

## Outstanding user decisions (deferred from `/ce-doc-review` round 1)

These items live in the plan's [`## Open Questions > ### From 2026-05-06 plan-review`](docs/plans/2026-05-06-001-feat-shelfmate-v1-implementation-plan.md#from-2026-05-06-plan-review) subsection. None block U1; some bite by U7/U8:

1. R8 invalidation pattern user-decision sign-off
2. Realistic timeline / calendar disclosure
3. `us-east-1` default vs non-US LTE budget
4. U8 split into U8a/U8b
5. Wave 1 demo value framing
6. U1 cost annotation honesty
7. GHA macOS minutes mitigation strategy
8. Branch SDK iOS match-rate falsification trigger
9. v1.1 observability path

## License

Proprietary — Bunshin Development Studios. All rights reserved.
