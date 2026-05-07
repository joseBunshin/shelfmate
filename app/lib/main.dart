import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(
    const ProviderScope(
      child: ShelfMateApp(),
    ),
  );
}

/// Root widget. U1 placeholder — full routing + theme land in U3.
class ShelfMateApp extends StatelessWidget {
  const ShelfMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShelfMate',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const _BootPlaceholder(),
    );
  }
}

class _BootPlaceholder extends StatelessWidget {
  const _BootPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ShelfMate')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'ShelfMate v1 — U1 scaffold.\n\n'
            'Auth, library, friends, recommendations, lists, '
            'discover, share card, and settings ship in U3–U8.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
