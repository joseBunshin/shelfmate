// Repository façade over AuthService — gives the UI a stable interface
// independent of Supabase's auth client surface and provides hooks for
// post-auth side effects (genre prefs read, referrer claim, etc.).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/supabase_auth.dart';

class AuthRepository {
  AuthRepository(this._service);

  final AuthService _service;

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) {
    return _service.signUpWithEmail(email: email, password: password);
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _service.signInWithEmail(email: email, password: password);
  }

  Future<AuthResponse> signInWithApple() => _service.signInWithApple();

  Future<AuthResponse> signInWithGoogle() => _service.signInWithGoogle();

  Future<void> signOut() => _service.signOut();
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(authServiceProvider));
});
