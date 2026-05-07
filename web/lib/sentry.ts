// Sentry init helper for the Next.js web project.
//
// Per AGENTS.md secrets policy: sendDefaultPii: false, tracesSampleRate: 0.1,
// beforeSend strips PII patterns + dedups by error_signature in 60s window.
//
// U1.3 wires SENTRY_DSN_WEB from Vercel env vars. The actual sentry.server.config.ts
// and sentry.client.config.ts files land in U1.3 alongside the @sentry/nextjs
// instrumentation hooks.

// TODO(U1.3): create sentry.server.config.ts + sentry.client.config.ts.
// TODO(U1.3): wire instrumentation.ts per @sentry/nextjs docs.
// TODO(U1.3): beforeSend dedup helper mirroring the Flutter side.
