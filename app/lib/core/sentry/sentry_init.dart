// Sentry init. Per AGENTS.md secrets policy + plan U1 Approach:
// - sendDefaultPii: false
// - tracesSampleRate: 0.1
// - maxBreadcrumbs: 30
// - beforeSend: strip PII patterns + dedup-by-error-signature in 60s window
//
// Wired in U1.3 once SENTRY_DSN_APP is uploaded to GHA secrets and
// surfaced via Env.

// TODO(U1.3): SentryFlutter.init(...) wrapping runApp(); see plan U1.
// TODO(U1.3): beforeSend dedup helper in core/sentry/dedup.dart.
