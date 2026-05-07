// Env config + secrets surface. Wired in U1.3 with real values from
// Supabase, Branch, Sentry, Anthropic, Vercel.
//
// Until then, all getters return placeholder strings so the app boots
// without external service credentials.

class Env {
  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  static const String sentryDsn =
      String.fromEnvironment('SENTRY_DSN', defaultValue: '');
  static const String branchKey =
      String.fromEnvironment('BRANCH_KEY', defaultValue: '');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  const Env._();
}
