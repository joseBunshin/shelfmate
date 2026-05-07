// Supabase client surface. U1.3 will replace the lazy bootstrap with a
// real Supabase.initialize() call in main() against Env values + a
// straight provider that returns Supabase.instance.client.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Returns the singleton SupabaseClient. Throws if Supabase has not been
/// initialised; main() must call [bootstrapSupabase] before runApp.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Initialise Supabase. Safe to call multiple times — the SDK is a singleton.
///
/// In U1.3, this will be invoked from main() with real credentials from
/// Env.supabaseUrl / Env.supabaseAnonKey. Calling with empty strings is a
/// no-op (the SDK throws on actual queries) so dev builds without secrets
/// can still construct the widget tree.
Future<void> bootstrapSupabase({
  required String url,
  required String anonKey,
}) async {
  if (url.isEmpty || anonKey.isEmpty) return;
  await Supabase.initialize(url: url, anonKey: anonKey);
}
