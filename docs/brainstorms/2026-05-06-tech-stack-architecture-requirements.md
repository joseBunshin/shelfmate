---
date: 2026-05-06
topic: tech-stack-architecture
---

# ShelfMate v1 — Tech Stack Architecture Decisions

## Summary

ShelfMate v1 will be built as a Flutter (Riverpod) mobile app for iOS and Android, a Next.js on Vercel project for the five non-user web surfaces, and Supabase (Postgres + RLS + Auth + Storage + Edge Functions) as the shared backend, with Branch.io for deferred deep linking. All three deployables live in one monorepo.

---

## Problem Frame

The product spec is fully complete: 6 phases, 68 stories (per the epic-summary table in `buildspec/shelfmate_05_stories.docx` and `buildspec/shelfmate_06_mvp.docx` — the prose narrative in those docs says "66" but the table totals are authoritative), an MVP scope contract that explicitly states "Engineering begins from here" (`buildspec/shelfmate_06_mvp.docx`). What is *not* resolved is the technical architecture. Phase 6 §7 enumerates seven cross-cutting decisions left to the architect: mobile framework, deferred deep link service, backend stack, comment visibility enforcement strategy, cover image caching, public list rendering, and Claude API spend management. None of these can be deferred — each one cascades. Picking a backend dictates how privacy enforcement is implemented, which dictates whether the spec's hardest correctness requirement (the comment visibility intersection rule) is enforceable declaratively or has to live in fragile application code. Picking a framework dictates which native plumbing exists for free vs which has to be assembled.

The team is two people: a PMP (product) and one engineer, with Flutter-only mobile experience. The project is a Bunshin Development Studios Labs build — no monetisation in v1, no paid acquisition, organic seeding, traction-gated expansion. Decisions must favor: (1) declarative enforceability on the hard correctness requirements, (2) shipping velocity for a single engineer, and (3) operational simplicity that doesn't add yak-shaving cost before the first user-facing story ships.

```
                       ┌──────────────────────────────────────┐
                       │   Active Reader (mobile, iOS+Android)│
                       │             Flutter App              │
                       │            (Riverpod state)          │
                       └────┬───────────┬──────────────┬──────┘
                            │           │              │
                ┌───────────▼─┐   ┌─────▼──────┐  ┌────▼───────┐
                │  Supabase   │   │ Branch.io  │  │ Open Library│
                │ Postgres+RLS│   │ deep links │  │ Google Books│
                │ Auth Storage│   │ deferred   │  └─────────────┘
                │ EdgeFn → Claude│ install ctx│
                └──────┬──────┘   └─────┬──────┘
                       │                │
                       │           ┌────▼───────────────────────┐
                       │           │ Invited Non-User (mobile web) │
                       └───────────► Next.js on Vercel (edge SSR)│
                                   │   5 landing pages, no login │
                                   └────────────────────────────┘
```

---

## Actors

- A1. **Flutter App** (iOS + Android) — Native client for the Active Reader. Renders all in-app surfaces.
- A2. **Next.js Web Project** (Vercel) — Renders the five non-user surfaces (rec landing, social discovery landing, inviter profile, public list, Join CTA / App Store redirect). No login wall on any.
- A3. **Supabase Backend** (Postgres + Auth + Edge Functions + Storage) — Single source of truth for user data, friend graph, recs, lists, comments, and RLS-enforced visibility.
- A4. **Branch.io** — Resolves deep links and holds deferred install context (referrer for new users) across the App Store install boundary.
- A5. **Open Library + Google Books APIs** — External book catalog, read-only and cached.
- A6. **Anthropic Claude API** — AI rec generation. Called only from a Supabase Edge Function (server-side, key never on client).

---

## Key Flows

- F1. **Friend invite link click (deferred deep link)**
  - **Trigger:** Recipient taps an invite link sent by an Active Reader
  - **Actors:** A4, A1 (or A2 fallback)
  - **Steps:**
    1. Branch resolves the link
    2. If app installed → opens app, friend request surfaces in Inbox
    3. If app not installed → redirects to App Store / Play Store with deferred install token holding `from_user_id`
    4. After install + first open: Branch SDK in app fires init, returns referrer token, friend connect prompt shown in onboarding (E1-006)
  - **Outcome:** Friend graph starts with one edge for the new user
  - **Covered by:** R3, R13, R14

- F2. **Friend's note rendering on book detail (privacy intersection)**
  - **Trigger:** Active Reader opens Book Detail for a book a friend has commented on
  - **Actors:** A1, A3
  - **Steps:**
    1. App queries Supabase for comments on that book
    2. RLS policy filters at query time: `Friend.status` block check first, then writer setting × viewer setting intersection
    3. App receives only the rows it is permitted to render
    4. UI renders the result with no client-side permission logic
  - **Outcome:** User sees only the comments the intersection rule permits, with zero app-code permission logic to drift out of sync with the spec
  - **Covered by:** R7, R8

- F3. **Non-user lands on rec page (2s LTE budget)**
  - **Trigger:** Non-user taps a rec link in DM, email, or text
  - **Actors:** A4, A2, A3
  - **Steps:**
    1. Branch routes to the Next.js landing page on Vercel
    2. Vercel edge SSR fetches rec content from Supabase (cover URL pre-embedded on the `Recommendation` record)
    3. HTML returned with above-fold content fully resolved
    4. Above-fold renders within 2 seconds on LTE
  - **Outcome:** Non-user reads rec + sender note without login wall, decides whether to browse the inviter's profile
  - **Covered by:** R9, R10, R12

---

## Requirements

**Mobile app**
- R1. Mobile app delivered as a single Flutter codebase building to iOS and Android.
- R2. State management via Riverpod, using code generation (`riverpod_generator`).
- R3. App must integrate the Branch.io Flutter SDK for deep link resolution covering all three link types from Phase 4 (rec links, profile links, friend invite links).

**Backend**
- R4. Backend implemented as a Supabase project: Postgres for relational data, Auth for email + Apple + Google sign-in, Storage for avatars, Edge Functions for any server-side logic that requires secrets — notably outbound Claude API calls.
- R5. Anthropic Claude API key never exposed to mobile or web clients. All AI rec calls routed through a Supabase Edge Function.
- R6. Friendship state (Pending / Active / Blocked) modeled as a single row per pair of users with status transitions enforced by RLS policy.
- R7. Comment visibility intersection rule (writer setting × viewer setting × `Friend.status`) enforced via Postgres RLS policies — not implemented in app or web client code. The RLS policy must apply the `Friend.status` block as a hard filter *before* applying the writer/viewer intersection (per Phase 4: "Block must be enforced at the query level, not the render level").
- R8. Privacy setting changes (writer setting, viewer setting, library visibility, currently-reading visibility) take effect on the very next render with no client-side cache that could serve stale state.

**Non-user web surface**
- R9. The five non-user web pages (E10-001 Direct Rec Landing, E10-002 Social Discovery Landing, E10-003 Inviter Profile, E10-004 Public List, E10-005 Join ShelfMate CTA + App Store redirect) implemented as a Next.js project deployed to Vercel. E10-005 is the web-side dependency for R13/R14 — it must attach the Branch deferred install token to the App Store / Play Store redirect URL so referrer context survives install.
- R10. Each non-user page server-side rendered at the edge — no client-side data fetch required to render above-the-fold content.
- R11. Public List page (E10-004) reflects visibility changes within a maximum 30-second window — the URL must serve the branded "no longer public" page rather than the previous list contents within 30 seconds of the visibility change, with no manual cache purge required. The implementation mechanism (on-demand revalidation via Supabase webhook, request-time SSR visibility check, or hybrid) is deferred to planning. Whichever mechanism is chosen, request-time visibility check must serve as a defense-in-depth backstop against webhook delivery failure or revalidation lag.
- R12. Cover images for the rec landing page must be proxied through Supabase Storage at rec-creation time — the `Recommendation` record holds a Supabase Storage URL, not the raw Open Library / Google Books URL. This insulates the above-fold render from third-party CDN outages, URL rot, and any compromise of upstream cover hosting. Above-fold render must not depend on any client-side fetch from Open Library, Google Books, or any other third party.

**Deferred deep linking**
- R13. Friend invite links (E11-003) and any other deferred-context links must achieve **best-effort** referrer survival across the App Store install handshake — referrer context resolves on first app open post-install when the deferred-link service can match the install. Match rate is observed during beta and reported in launch metrics; the system must not assume 100% match rate. **Fallback path**: when the referrer cannot be resolved (user denied tracking, fingerprint match failed, install delayed past token expiry), onboarding completes normally and surfaces a manual "add the friend who invited you" prompt with a search field instead of an automatic friend-connect prompt — no error shown.
- R14. Deferred deep link service: Branch.io free tier.
- R15. Branded fallback pages — never raw 404s — for: rec link with missing/expired/anonymised rec, profile link with deleted user, public list link with revoked visibility.

**Repository, tooling, and external APIs**
- R16. Single git repository housing `app/` (Flutter), `web/` (Next.js), `supabase/` (migrations + RLS policies + edge functions), and `docs/` (the buildspec + decision docs) as separate top-level directories.
- R17. CI/CD via GitHub Actions for both mobile and web. Mobile builds produce signed iOS and Android artifacts uploadable to TestFlight and Play Internal Testing.
- R18. Error tracking via Sentry on both the Flutter app and the Next.js project.
- R19. Beta distribution via TestFlight (iOS) and Google Play Internal Testing (Android).
- R20. Open Library is the primary book catalog source; Google Books is the fallback when Open Library returns no result or no cover.
- R21. AI recs use Claude (`claude-sonnet-4-20250514` per spec — to be revalidated against current Anthropic model availability during planning); cached per user with 24h TTL; manual refresh throttled to one per 10 minutes; monthly spend cap configured in the Anthropic console before any beta distribution.

**Correctness, security, and observability**
- R22. RLS policy correctness must be gated in CI by an automated test suite (e.g., pgTAP or a dedicated Supabase test harness) that exhaustively covers all 9 writer × viewer combinations × friendship state (None / Pending / Active / Blocked) and explicitly verifies the block-before-intersection ordering. The CI gate runs against a seeded test database. RLS being the sole enforcement layer (R7) means a single policy bug is a silent trust failure with no app-code backstop — automated coverage is the backstop.
- R23. Account deletion architecture covering the spec's data lifecycle: (a) hard-delete of auth record, email, display name, avatar, friendship rows, AI rec cache, and personal notes; (b) anonymisation of the user's outbound recommendations (sender becomes "A ShelfMate user") so recipients still have the rec content; (c) Postgres foreign-key constraints chosen with deletion semantics in mind (cascade vs anonymise vs soft-delete) at schema design time, not retrofitted. Required for App Store submission (Apple Review §5.1.1, in effect since June 2023) and for GDPR / CCPA right-to-erasure.
- R24. The Supabase Edge Function that invokes Claude (per R5) must require a valid Supabase Auth JWT on the caller, reject anonymous invocations, and enforce the spec's per-user 10-minute manual-refresh throttle (R21) server-side — not trusted from the client. Protects the Anthropic monthly spend cap from being drained by an anonymous attacker who discovers the function URL.
- R25. The finish-book flow signature moment (Phase 4 "magic-moment seam") is implemented as: (a) celebration screen rendered from the Flutter widget tree with native animation; (b) share card generated as PNG via Flutter's CustomPaint / canvas pipeline (no platform-specific native plugin); (c) export through the OS share sheet (`share_plus` package or equivalent) on both iOS and Android; (d) graceful fallback when the cached cover is unavailable — text-only card on a brand-coloured background per the spec.
- R26. Branch.io referrer tokens received by the app on first open must be validated server-side via a Supabase Edge Function before any friend-graph row is created — verify the referrer `user_id` exists, is not blocked, and the token has not been replayed against another install. Branch fingerprint-matched tokens (probabilistic, not cryptographic) must be flagged as lower-confidence and trigger a confirmation step rather than automatic friend-connect.
- R27. Landing-page conversion observability for the spec's traction-gate signal (`landing-page → App Store tap rate`, named in `buildspec/shelfmate_06_mvp.docx` §9): page views and App Store / Play Store tap events on each of the five non-user pages must be captured at sufficient granularity to compute the tap-through-rate signal. Implementation must not require a dedicated analytics platform integration (Mixpanel / Amplitude are deferred to v1.1 per spec) — Vercel Web Analytics, a Plausible self-host, or a single Supabase Edge Function event log is sufficient.
- R28. Secrets used in CI/CD (Anthropic API key, Supabase service-role key, Apple signing certs, Google Play upload key, Sentry DSN) stored only in GitHub Actions encrypted secrets with environment scoping — secrets must not be accessible to workflow runs from forked-repo PRs. Build logs configured to mask secret values. Each secret is scoped to its environment (dev / beta / prod) so a beta key cannot be used in a production build.

---

## Privacy Enforcement Seam

The spec names privacy enforcement as the highest-stakes correctness requirement (Phase 4 "trust seam" + "permission seam"). Pushing all enforcement into RLS (R7) means a single policy bug is a silent trust failure. RLS does not get every case automatically — the implementation must explicitly handle the four scenarios where naive RLS leaks:

- **Edge SSR auth (non-user web reads).** Vercel edge SSR for E10 pages serves unauthenticated callers, so `auth.uid()` is null and an authenticated-only RLS policy will never match. The Next.js project must connect to Supabase using the **anon role** (not the service-role key, which would bypass RLS entirely), and the `comments`, `book_lists`, `profiles`, and `recommendations` tables must each carry an explicit anon-role RLS policy that permits read of rows where the writer's setting = `Everyone` (and, for `book_lists`, where visibility = `Public`). The exact policy SQL is deferred to planning, but the role choice is locked here.
- **Realtime subscription invalidation on policy/setting change.** Supabase Realtime applies RLS at subscription start but does not re-evaluate policies on subscribed rows when the underlying privacy setting changes. A viewer who flips their setting after subscribing keeps receiving rows they should no longer see. The implementation must invalidate and re-subscribe affected channels on any privacy-setting write — the trigger pattern (Postgres trigger fires `pg_notify`, app re-subscribes; or app-side broadcast on settings write) is deferred to planning, but the invariant is locked here.
- **RLS join composition.** RLS policies apply to base-table reads, but joined views can return rows visible per the joined view's policies even when the base-table policy would have hidden them. Any view that reads from `comments` or `user_books` must either (a) carry its own RLS policy aligned with the base table, (b) be defined as `security_invoker` / `security_definer` with the matching predicate, or (c) be replaced by an explicit base-table query in the SDK. No raw `SELECT * FROM comments JOIN ...` from a join view without an aligned policy.
- **RLS-policy-migration discipline.** Every Postgres migration that adds a column to a privacy-affected table (`comments`, `user_books`, `friendships`, `book_lists`), renames a status enum value, or changes the writer/viewer setting representation must include an accompanying RLS policy update in the same migration commit. A schema change without a policy update is a regression-shaped trust failure. Enforce via PR-template checklist plus the R22 test suite running against the proposed schema before merge.

---

## Acceptance Examples

- AE1. **Covers R7.** Given user A wrote a comment with writer setting = "Friends only", and user B has viewer setting = "Everyone" but is NOT friends with A, when B opens the book detail page for that book, B's render does not include A's comment — and the omission is enforced because the SQL query did not return the row, not because the client filtered it.
- AE2. **Covers R7.** Given user A blocked user B (Friendship.status = Blocked), and user A's writer setting = "Everyone", when B opens any book detail page that includes one of A's comments, A's comment does not appear — even though the writer setting alone would normally permit it. The block runs before the intersection.
- AE3. **Covers R8.** Given user A has 5 comments visible to friends, when A changes their writer setting to "Only me", user B (a friend) refreshes any book detail page containing one of A's comments within seconds and no longer sees them.
- AE4. **Covers R11.** Given user A made list L public and shared the URL externally, when A flips L to private, the next request for L's public URL renders the branded "no longer public" page rather than the previous list contents — without manual cache purge.
- AE5. **Covers R10, R12.** Given a non-user receives a rec link, when they open it on a slow LTE connection, the book cover, sender name, and first line of the sender note are visible above the fold within 2 seconds — measured via Vercel edge SSR with the cover URL pre-embedded on the `Recommendation` record.
- AE6. **Covers R5.** Given a user opens the Discover tab and triggers an AI rec refresh, when the request is in flight, no Anthropic API key appears in the network inspector on the device or browser — the call is routed via a Supabase Edge Function that holds the key.
- AE7. **Covers R3, R13.** Given a non-user taps a friend invite link and proceeds through the App Store install, when they open the app for the first time and the deferred-link service successfully matches the install, the referrer's `user_id` is resolved by the Branch SDK on first init and surfaced as the automatic friend-connect prompt in onboarding (E1-006).
- AE8. **Covers R13.** Given a non-user taps a friend invite link, denies tracking permissions during the install, and the deferred-link match fails on first open, when they reach the friend-connect step in onboarding, the app surfaces a manual "add the friend who invited you" prompt with a search field instead of an automatic prompt — and onboarding completes without an error message attributing the unmatched referrer.
- AE9. **Covers R25.** Given a user marks a book as Read on a slow or offline network where the cached cover image is unavailable, when the share card render fires from the finish-book celebration screen, a text-only card is generated (book title + author on a brand-coloured background) and exported to the OS share sheet — the share flow does not block on the missing cover.
- AE10. **Covers R24.** Given an unauthenticated HTTP client discovers the Claude-invocation Edge Function URL, when the client POSTs a request without a valid Supabase Auth JWT, the function returns 401 / 403 within milliseconds without making any outbound Anthropic call — protecting the monthly spend cap from anonymous drain.
- AE11. **Covers R26.** Given an attacker captures a valid Branch referrer token from one install attempt, when they replay the same token on a second device's first-open, the server-side validation step (Supabase Edge Function) rejects the second use as already-consumed and the friend-graph row is not created — the legitimate first install retains its referrer linkage.

---

## Success Criteria

- The architect can begin `/ce-plan` over the 68 stories in `buildspec/shelfmate_05_stories.docx` without re-litigating any of these decisions.
- A new contributor (or a future Claude session loading this repo cold) can read this doc and understand which technologies are chosen, why, and where each lives in the repo layout.
- The hardest correctness requirements from the spec — comment visibility intersection (Phase 4 "trust seam"), block enforcement (Phase 4 "permission seam"), 2s LTE landing pages (Phase 4 "conversion seam"), deferred deep linking referrer survival (Phase 4 "referral seam") — each have an explicit implementation seam called out in this doc, not left for planning to invent.

---

## Scope Boundaries

- Native iOS (Swift) and native Android (Kotlin) — explicitly rejected for team-size and scope-fit reasons; not a deferral.
- React Native — explicitly rejected; learning cost unjustified for a fixed-scope Labs build with a Flutter-experienced engineer.
- Firebase / Firestore — explicitly rejected for the backend role; the relational data model (Friendship junction with state, ordered BookList contents, Recommendation with sender/recipient/book/note/status) and the comment-visibility intersection rule both fit Postgres RLS far better than Firestore + security rules. Firebase Dynamic Links sunset is a separate concern (covered in the deep-linking section), not a reason to reject Firebase as a backend.
- Custom backend (Node, Go, Rails, etc.) — explicitly rejected; Labs scope cannot absorb the months of plumbing.
- Flutter Web for the non-user surfaces — would fail the 2s LTE budget.
- PWA / webview wrapper — ruled out by spec.
- Bloc, Provider, GetX (Flutter state alternatives considered and rejected).
- Astro, Supabase Edge Functions returning HTML directly (web rendering alternatives considered and rejected).
- Adjust, AppsFlyer (deferred deep linking alternatives — too attribution-focused, paid, overkill).
- Codemagic for mobile CI — defer until GitHub Actions becomes painful.
- Push notifications infrastructure — v1.1 per spec.
- In-product analytics platforms (Mixpanel, Amplitude) — v1.1 per spec.
- Admin dashboard, moderation tools, user reporting — v1.1 per spec.
- Full web app (desktop or PWA experience) — only mobile-web landing pages in scope per spec.

---

## Key Decisions

- **Flutter for mobile.** Engineer has Flutter-only experience. The spec's signature moments (finish-book celebration, share card generation, ISBN scan, OS share sheet) are all well-supported in mature Flutter packages with no compromises that materially affect UX. Native (Swift + Kotlin) was the engineer's first instinct but rejected on team-size grounds (1 engineer, 68 stories, no deferral) and because the spec asks for nothing platform-specific (no Live Activities, App Intents, widgets, or Siri integration). React Native was equivalent in capability but the learning cost was unjustified.
- **Supabase for backend.** Chosen on positive grounds: (a) Postgres + RLS lets the comment-visibility intersection rule live in the data layer as a declarative SQL function called by policy — making the spec's hardest correctness requirement testable rather than fragile app code; (b) the data shape is fundamentally relational (Friendship junction with state, ordered BookList contents, Recommendation with sender/recipient/book/note/status) and Postgres fits without denormalisation; (c) Auth, Storage, Edge Functions, and database all come from the same vendor in one project, reducing operational surface for a 1-engineer team; (d) Postgres + standard RLS keeps the data layer portable — Auth, Storage, Edge Functions, and webhooks are Supabase-specific and would need re-platforming if we ever leave, but the data and the hardest correctness logic stay in standard SQL. **Runner-up if Supabase proves a poor fit:** managed Postgres (Neon, Render, or Railway) plus a thin custom Node/TypeScript layer for auth proxy and Edge Function equivalent — preserves Postgres + RLS, replaces Supabase-specific surface. Custom backend from scratch was rejected for Labs scope.
- **Next.js on Vercel for non-user web.** The spec mandates a 2-second LTE above-fold render for E10-001 and E10-002. Edge SSR on Vercel meets this without effort. Astro and hand-rolled HTML in Edge Functions would meet it too but lose component reuse and design system reuse across the five pages. Direct Supabase queries via the Supabase JS SDK keep the architecture simple. *Whether component reuse is meaningful at this page count is itself an open question — see "From 2026-05-06 review" in Outstanding Questions.*
- **Branch.io for deferred deep linking.** Spec recommends it. Original draft cited "~250K MAU" on the free tier; that number is flagged for verification (see Outstanding Questions — actual current free cap may be ~10K MAU, in which case the build-vs-buy calculus deserves a second look). iOS-specific deferred deep linking post-IDFA is genuinely hard — URL params get stripped by the App Store redirect; Branch handles the install-time matching via fingerprinting + clipboard fallback (probabilistic, not cryptographic — R13 reflects this with best-effort framing). Custom redirect server is technically possible but represents 2-3 weeks of iOS-specific yak-shaving Branch productised years ago. Firebase Dynamic Links sunset (2025) takes that option off the table entirely.
- **Riverpod for Flutter state management.** 2026 industry default. Code generation gives compile-time safety. Bloc considered but ceremony is high for a 1-engineer team. Provider insufficient for the privacy-intersection state derivation. GetX rejected for fighting idiomatic Flutter patterns.
- **Monorepo with three deployables.** One git repo containing `app/`, `web/`, `supabase/`, and `docs/`. Avoids cross-repo coordination tax: changing the shared `Recommendation` shape touches all three deployables. A 1-engineer team gets no benefit from multi-repo isolation.
- **Final app name: ShelfMate.** Confirmed 2026-05-06 (was flagged as placeholder in `buildspec/shelfmate_06_mvp.docx` §9). Domain TLD selection and App Store name-conflict verification are operational tasks, not naming decisions — both still need to happen before App Store submission.

---

## Dependencies / Assumptions

- Anthropic API key with paid plan and a configured monthly spend cap (set in Anthropic console before any beta distribution).
- Apple Developer Program membership ($99/yr) for TestFlight and App Store distribution.
- Google Play Developer account ($25 one-time) for Play Internal Testing and Play Store distribution.
- Branch.io account on free tier.
- Vercel account on Hobby tier (upgrade to Pro if landing-page traffic exceeds Hobby limits during seeding).
- Supabase project on free tier (consider Pro at ~$25/mo if storage or bandwidth crosses thresholds).
- Sentry account on Developer tier (free for 5K errors/mo per project).
- GitHub repository under the team's existing organisation.
- Domain registration for `shelfmate.app` (or alternative TLD if `.app` is unavailable) — verification and registration to happen before App Store submission.
- App Store name-conflict check on "ShelfMate" for both Apple App Store and Google Play before submission.
- **GitHub Actions macOS minutes budget.** GHA charges macOS runners at a 10× multiplier; the private-repo free tier provides ~200 macOS minutes/mo and a signed Flutter iOS build runs ~15-25 minutes (~8-13 builds before paid). Mitigations to weigh during planning: (a) make the repo public for unlimited minutes, (b) budget for paid GHA minutes (~$0.08/macOS minute), (c) move iOS CI to Codemagic earlier than the "until GHA becomes painful" rule allows, or (d) batch iOS builds (e.g., only on `main` push, not every PR).
- **Apple Sign In configuration.** Required Supabase Auth provider config: Apple Developer Services ID, Sign In with Apple key (.p8), team ID and key ID populated in Supabase. The native iOS sign-in path must use Supabase `signInWithIdToken` (handing over Apple's identity token) rather than the OAuth web redirect flow, which Apple discourages on iOS. Apple requires Sign In with Apple for App Store approval whenever any other third-party OAuth (Google) is offered — non-negotiable.
- **v1.1 push notifications primitive.** Supabase has no first-party push service. v1.1 push (`buildspec/shelfmate_06_mvp.docx` Epic Summary, deferred from v1) will require integrating APNs / FCM directly or via OneSignal. v1 schema should preemptively reserve `device_tokens` and `notification_prefs` columns / tables to avoid retrofit churn during the v1.1 work.

---

## Outstanding Questions

### Deferred to Planning

- [Affects R7, R8][Technical] Exact RLS policy SQL implementation including the helper SQL function for the intersection rule — to be designed during planning when the Postgres schema is laid out alongside the migration sequence.
- [Affects R10, R11][Technical] Whether to use Vercel ISR with on-demand revalidation, full SSR, or a hybrid for the non-user pages — measure with realistic data shapes during planning.
- [Affects R3, R13, R14][Needs research] Branch.io's current Flutter SDK behavior on iOS 18+ and Android 15+ — verify against latest Branch docs and current OS-level changes (Apple's Privacy Manifest requirements in particular) during planning.
- [Affects R21][Needs research] Confirm `claude-sonnet-4-20250514` (named in `buildspec/shelfmate_06_mvp.docx`) against the currently-available Claude model lineup at planning time — model IDs may have rolled forward.
- [Affects R14][Needs research] Verify Branch.io's current free / Starter tier MAU cap and overage pricing against 2026 published terms. The original draft cited "~250K MAU" but reviewer evidence suggests the actual current free cap may be closer to ~10K MAU. If the lower number is correct, revisit the build-vs-buy calculus on Branch — at Labs scale a custom redirect server may now win.

### From 2026-05-06 review

Deferred from `/ce-doc-review` round 1 (2026-05-06). Each item is a real product/architecture decision that warrants the user's judgment rather than an agent default.

- [Affects R7, R9, R10][User decision] **Non-user SSR auth context — anon role with explicit RLS, or service-role with SSR-side filtering?** The Privacy Enforcement Seam section above commits to anon-role; this item carries the deferred validation that the anon-role policy surface for `comments`, `book_lists`, `profiles`, and `recommendations` is expressible without leaking authenticated-only fields. If anon-role policies prove too restrictive or too permissive in practice, the alternative (service-role + SSR-side filter, with R7 carved out for the non-user surface) becomes the fallback. Resolve before the first Next.js Supabase query is written.
- [Affects R8][User decision] **Cache invalidation strategy on privacy-setting change.** Three candidate patterns: (a) every privacy-affected Riverpod provider declared `autoDispose` without `keepAlive`, accepting a network round-trip on every navigation; (b) explicit invalidation broadcast — privacy-setting writes fire `ref.invalidate()` against a known set of providers; (c) Supabase Realtime subscriptions to `friendships` and `privacy_settings` rows that drive invalidations in the app. Each has different cycle-time, complexity, and traffic profiles. Pick during planning when the Riverpod provider tree is laid out.
- [Affects R10, F3, AE5][User decision] **Supabase region selection + Vercel deployment co-location.** The 2s LTE budget assumes the edge SSR query to Postgres is fast. If users are global but Postgres lives in `us-east`, far-region edge nodes pay 200-400ms cross-region latency that eats into the budget. Either (a) accept the budget is only met for users near the chosen region, (b) commit to Supabase Pro for read-replica access in additional regions, or (c) cache rec landing-page payloads at the Vercel edge with on-demand revalidation so the cross-region hop is amortised.
- [Affects Key Decisions][User decision] **React Native rejection rationale.** The current rationale ("learning cost unjustified") sits in tension with the Next.js + RLS + Edge Functions learning curve the same engineer is being asked to absorb. Either (a) reframe the RN rejection on substantive grounds (Flutter's CustomPaint share-card story, OS share-sheet ergonomics, build-pipeline simplicity) and drop "learning cost" from the rationale, or (b) honestly tally the engineer-week budget across the chosen stack and confirm it is materially smaller than the RN learning curve would have been. Resolve so the rationale survives later scrutiny.
- [Affects Key Decisions, R9-R12][User decision] **Justification for Next.js-on-Vercel vs simpler alternatives.** Adding Next.js commits a single engineer to two frontend stacks, two CI pipelines, and two deploy targets to serve five read-only landing pages. Quantify the engineer-week delta against (a) a single Supabase Edge Function rendering templated HTML for all five pages with shared CSS and (b) Astro on Vercel/Netlify, then confirm the chosen path's cost is justified by the component-reuse benefit at this scale. If the simpler path holds up, demote Next.js to an alternative.
- [Affects R17, R18, R19][User decision] **Should CI/CD, error tracking, and beta distribution be numbered requirements, or split into a "Pre-distribution setup" non-numbered section?** R17, R18, R19 don't map to any buildspec story but impose real engineering work. Numbered alongside product requirements, they inflate apparent scope; in a separate section, they're clearly scope-adjacent setup tasks. Pick during planning when the dependency graph for the 68 stories is being sequenced.
- [Affects R15][User decision + needs research] **Narrow R15 to the visibility-revoked case only, or retain all three branded fallback pages?** E10-004 covers the public-list-revoked case explicitly. The expired-rec and deleted-user-profile cases are architecture-additions beyond the buildspec story set. Verify against `buildspec/shelfmate_04_handoff.docx` Phase 4 failure modes ("Rec deep link 404s or rec record not found", etc.) — if the spec only requires graceful degradation, narrow R15 to the revoked-list case; if branded pages are required for all three, cite the spec source so a future contributor can trace it.
