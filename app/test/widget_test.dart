// Smoke test stubs — proper widget tests for U3 auth flow live in
// app/test/features/auth/ once the auth providers can be cleanly faked
// without a live Supabase instance. Until then, this single test just
// guards the build (catches syntax errors, missing exports, etc.).
//
// A real integration test of sign-up → genre picker → home would need
// either a hermetic Supabase test container or a mock-injected
// AuthService at the provider override layer. Both are scoped to a U3
// test pass after secrets exist.

import 'package:flutter_test/flutter_test.dart';
import 'package:shelfmate/main.dart';

void main() {
  test('ShelfMateApp class is defined and constructible', () {
    const app = ShelfMateApp();
    expect(app, isNotNull);
  });
}
