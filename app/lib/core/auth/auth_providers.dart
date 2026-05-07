// Riverpod providers for auth state. UI listens to authStateProvider and
// the router redirects based on the session presence.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/client.dart';
import 'supabase_auth.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseClientProvider));
});

/// Stream of Supabase auth state events. Used by the router redirect
/// listener to push to /auth on sign-out and to /home on sign-in.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Synchronous current-session accessor. NULL when signed out.
final currentSessionProvider = Provider<Session?>((ref) {
  // Re-read on every auth state event so providers depending on session
  // identity get invalidated.
  ref.watch(authStateChangesProvider);
  return ref.watch(authServiceProvider).currentSession;
});

/// Convenience: true when a session exists.
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(currentSessionProvider) != null;
});
