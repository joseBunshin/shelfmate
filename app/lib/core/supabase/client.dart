// Supabase client surface. main() calls bootstrapSupabase before runApp;
// the supabaseClientProvider then returns the singleton client to the
// rest of the app.
//
// Until U1.2 secrets are configured, the bootstrap initialises against a
// localhost-shaped placeholder URL + a placeholder anon key. Initialisation
// succeeds (the SDK doesn't validate the URL at init time), and downstream
// queries fail with normal network errors rather than the app crashing
// at provider-construction time. This lets the widget tree boot in dev
// builds without forcing every developer to stand up a real Supabase
// project before they can see any UI.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _placeholderUrl = 'http://127.0.0.1:54321';
// Empty-payload anon-shape JWT — accepted by the supabase-dart client at
// init time; any actual API call will return a clear unauthorised error.
const _placeholderAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiJ9.placeholder';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Initialise Supabase. Idempotent at the SDK layer.
///
/// When `url` or `anonKey` is empty (no U1.2 secrets present), falls back
/// to placeholder values so initialisation still succeeds. Real queries
/// will fail at request time, not at app boot.
Future<void> bootstrapSupabase({
  required String url,
  required String anonKey,
}) async {
  final effectiveUrl = url.isNotEmpty ? url : _placeholderUrl;
  final effectiveKey = anonKey.isNotEmpty ? anonKey : _placeholderAnonKey;
  await Supabase.initialize(url: effectiveUrl, anonKey: effectiveKey);
}
