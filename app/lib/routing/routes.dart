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
import '../features/auth/presentation/first_book_prompt_screen.dart';
import '../features/auth/presentation/genre_picker_screen.dart';
import '../features/auth/presentation/log_in_screen.dart';
import '../features/auth/presentation/sign_up_screen.dart';

GoRouter buildRouter(WidgetRef ref) {
  return GoRouter(
    initialLocation: '/sign-up',
    refreshListenable: _GoRouterRefreshStream(
      ref.read(authServiceProvider).authStateChanges,
    ),
    redirect: (context, state) {
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
      GoRoute(
        path: '/home',
        builder: (context, _) => FirstBookPromptScreen(
          onAdd: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add Book flow lands in U4')),
          ),
        ),
      ),
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
