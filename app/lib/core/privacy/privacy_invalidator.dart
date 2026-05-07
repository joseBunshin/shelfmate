// PrivacyInvalidator — central broadcast for privacy-setting changes (R8).
//
// Resolves origin's deferred R8 user-decision via option (b): explicit
// invalidation broadcast. Privacy-setting writes call notifyChange() which
// fires ref.invalidate() on the registered set of dependent providers.
//
// Three-layer enforcement (per AGENTS.md):
//   1. Static lint rule on direct privacy_settings reads
//   2. Runtime registry test in supabase/tests/ (introspects pg_catalog)
//   3. AGENTS.md convention as backstop documentation
//
// Wired with real provider registrations in U2 (data layer) and U8
// (settings UI invocation).

// TODO(U2): PrivacyInvalidator class with register/notifyChange API.
// TODO(U8): SettingsRepository.update*Setting() calls notifyChange().
