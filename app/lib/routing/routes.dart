// App-wide route configuration via go_router. Auth-aware redirect:
//   not signed in → /sign-up (or /log-in via TextButton there)
//   signed in but onboarding incomplete → /onboarding/genres
//   signed in + onboarded + referrer params present → /onboarding/referrer
//   otherwise → /home (Library empty state until U4)
//
// "Onboarding incomplete" detection happens in U3 by checking
// users.genre_preferences after sign-in. For this scaffold, the genre
// picker always shows post-sign-up; future polish can short-circuit for
// users who already finished it.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_providers.dart';
import '../core/env/env.dart';
import '../features/auth/presentation/genre_picker_screen.dart';
import '../features/auth/presentation/log_in_screen.dart';
import '../features/auth/presentation/sign_up_screen.dart';
import '../features/library/presentation/library_screen.dart';

GoRouter buildRouter(WidgetRef ref) {
  // Dev-mode bypass: when running without Supabase/secrets configured,
  // skip the auth gate so the app shells past sign-up into Library/etc.
  // This is the only behavior difference between dev and prod builds —
  // U1.3 will set Env.isConfigured = true via build-time --dart-define
  // values, restoring the real auth-redirect flow.
  final devBypass = !Env.isConfigured;

  return GoRouter(
    initialLocation: devBypass ? '/home' : '/sign-up',
    refreshListenable: _GoRouterRefreshStream(
      ref.read(authServiceProvider).authStateChanges,
    ),
    redirect: (context, state) {
      if (devBypass) return null;

      final signedIn = ref.read(isSignedInProvider);
      final onAuthRoute =
          state.matchedLocation == '/sign-up' ||
          state.matchedLocation == '/log-in';

      if (!signedIn && !onAuthRoute) return '/sign-up';
      if (signedIn && onAuthRoute) return '/onboarding/genres';
      return null;
    },
    routes: [
      GoRoute(path: '/sign-up', builder: (_, _) => const SignUpScreen()),
      GoRoute(path: '/log-in', builder: (_, _) => const LogInScreen()),
      GoRoute(
        path: '/onboarding/genres',
        builder: (context, _) =>
            GenrePickerScreen(onDone: () => context.go('/home')),
      ),
      GoRoute(path: '/home', builder: (_, _) => const LibraryScreen()),
    ],
  );
}

/// Adapts a Stream to Listenable so go_router refreshes when auth state
/// changes. Standard go_router pattern.
class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
