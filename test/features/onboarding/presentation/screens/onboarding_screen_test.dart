import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inv_tracker/features/onboarding/presentation/screens/onboarding_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Onboarding dots should be interactive and have proper semantics', (tester) async {
    // Build the widget
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: OnboardingScreen(
            onComplete: () {},
          ),
        ),
      ),
    );

    // Verify initial state (Page 1)
    expect(find.text('Track Money In & Out'), findsOneWidget);

    // Verify semantics of the dots
    // We expect 4 dots, each with a semantic label
    for (int i = 1; i <= 4; i++) {
      final dot = find.bySemanticsLabel('Page $i of 4');
      expect(dot, findsOneWidget, reason: 'Dot for page $i should exist');

      // Verify button semantics
      final semantics = tester.getSemantics(dot);
      expect(semantics.isButton, isTrue, reason: 'Dot $i should be a button');

      // First page dot should be selected initially
      if (i == 1) {
        expect(semantics.isSelected, isTrue, reason: 'Dot 1 should be selected');
      } else {
        expect(semantics.isSelected, isFalse, reason: 'Dot $i should not be selected');
      }
    }

    // Tap on the 3rd dot to navigate to page 3
    final thirdDot = find.bySemanticsLabel('Page 3 of 4');
    await tester.tap(thirdDot);
    await tester.pumpAndSettle();

    // Verify we are on page 3
    expect(find.text('Set Goals & Get Reminders'), findsOneWidget);

    // Verify dot 3 selection state
    final semantics3 = tester.getSemantics(thirdDot);
    expect(semantics3.isSelected, isTrue, reason: 'Dot 3 should be selected after tap');

    // Tap on the 1st dot to go back
    final firstDot = find.bySemanticsLabel('Page 1 of 4');
    await tester.tap(firstDot);
    await tester.pumpAndSettle();

    // Verify we are back on page 1
    expect(find.text('Track Money In & Out'), findsOneWidget);
  });
}
