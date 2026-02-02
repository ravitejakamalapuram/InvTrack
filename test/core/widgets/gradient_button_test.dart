import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/gradient_button.dart';

void main() {
  testWidgets('GradientButton semantics test', (WidgetTester tester) async {
    // 1. Test normal state
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GradientButton(onPressed: () {}, label: 'Save'),
        ),
      ),
    );

    // Verify label is present
    expect(find.text('Save'), findsOneWidget);

    // Check semantics
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Save'), findsOneWidget);

    // 2. Test loading state
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GradientButton(
            onPressed: () {},
            label: 'Save',
            isLoading: true,
          ),
        ),
      ),
    );

    // Verify label text widget is GONE (replaced by spinner)
    expect(find.text('Save'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Verify semantics - currently expected to FAIL or find nothing useful
    // This part asserts the *current* behavior (which is bad) or the *desired* behavior?
    // I'll check what it finds. If I expect "Loading Save", it will fail now.
    // So I will write the test to expect the IMPROVED behavior, and see it fail first.

    // We want to find a semantic node that says "Loading Save"
    expect(find.bySemanticsLabel('Loading Save'), findsOneWidget);

    handle.dispose();
  });
}
