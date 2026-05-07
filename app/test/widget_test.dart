// U1 smoke test — verifies the app boots inside a ProviderScope and renders
// the placeholder screen. Real feature tests land in U3+ test files under
// test/features/.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shelfmate/main.dart';

void main() {
  testWidgets('ShelfMateApp boots and renders the U1 placeholder',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ShelfMateApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('ShelfMate'), findsOneWidget);
    expect(find.textContaining('U1 scaffold'), findsOneWidget);
  });
}
