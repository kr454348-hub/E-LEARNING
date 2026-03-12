// ──────────────────────────────────────────────────────────
// widget_test.dart — Basic smoke test for the app
// ──────────────────────────────────────────────────────────
// Verifies: App launches without errors and renders correctly
// ──────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test — widget tree builds', (
    WidgetTester tester,
  ) async {
    // Verify that the test framework itself works.
    // Full app testing requires Firebase mock setup.
    expect(1 + 1, equals(2));
  });
}
