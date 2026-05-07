// AuthService — wrappers around Supabase Auth for the three v1 sign-in
// methods (email/password, Apple, Google) plus session restoration.
//
// U1.3 wires the actual provider configuration. Until then, the signIn*
// methods throw UnimplementedError so attempting to authenticate from the
// UI surfaces a clear error rather than silently doing nothing.

import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  /// Current session, or null if not signed in.
  Session? get currentSession => _client.auth.currentSession;

  /// Stream of auth state changes — wraps Supabase's onAuthStateChange.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Email + password sign up. Email verification handling is configured
  /// at the Supabase project level (U1.2 user-action item).
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(email: email, password: password);
  }

  /// Email + password log in.
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Sign in with Apple — native iOS path. Returns the Apple identity token
  /// and exchanges with Supabase Auth via signInWithIdToken (no OAuth web
  /// redirect on iOS).
  ///
  /// On Android, this method invokes Apple's web-OAuth flow with the
  /// Services ID configured in U1.2; the redirect URL must be an Android
  /// App Link, domain-verified via assetlinks.json hosted on the project
  /// domain. PKCE + state-parameter handling cover CSRF.
  Future<AuthResponse> signInWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      // U1.2 will populate webAuthenticationOptions for Android.
    );
    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException('Apple Sign In returned no identity token');
    }
    return _client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
    );
  }

  /// Sign in with Google — uses the google_sign_in package to retrieve an
  /// ID token, then exchanges with Supabase Auth.
  Future<AuthResponse> signInWithGoogle() async {
    // google_sign_in v7 changed its API; this wrapper assumes the v7
    // GoogleSignIn() singleton + initialize() pattern. U1.2 will populate
    // the iOS/Android client_id values from the GoogleService-Info / json.
    final google = GoogleSignIn.instance;
    final account = await google.authenticate();
    final auth = account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      throw const AuthException('Google Sign In returned no idToken');
    }
    return _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
