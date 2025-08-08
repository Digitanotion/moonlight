import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // <-- REQUIRED entry point
  test('Basic arithmetic test', () {
    expect(1 + 1, equals(2)); // Simple verification
  });

  // Optional widget test
  testWidgets('Widget rendering test', (WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox()); // Minimal widget
    expect(find.byType(SizedBox), findsOneWidget);
  });
}
