// App entry point. U3 wires the full Riverpod provider scope, Supabase
// initialisation, theme, and go_router configuration.
//
// Real auth, Branch, Sentry init happen here once U1.2 secrets exist.
// Until then, the app boots into the auth screen and authentication
// against an unconfigured Supabase project will surface a clear error.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/env/env.dart';
import 'core/supabase/client.dart';
import 'routing/routes.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapSupabase(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);
  runApp(const ProviderScope(child: ShelfMateApp()));
}

class ShelfMateApp extends ConsumerWidget {
  const ShelfMateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = buildRouter(ref);
    return MaterialApp.router(
      title: 'ShelfMate',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      routerConfig: router,
    );
  }
}
