// Lightweight event-logging shims. v1 ships with Vercel Web Analytics on the
// non-user web surface (R27); the in-app surface uses Sentry breadcrumbs
// + structured tags for observability. A Supabase-native event log is
// deferred to v1.1 per the plan's From 2026-05-06 plan-review subsection.

// TODO(U3): event helpers for breadcrumb + tag emission to Sentry.
