import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('OnboardingScreen loads and shows first page', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: OnboardingScreen(onComplete: () {}),
        ),
      ),
    );

    expect(find.text('Track Money In & Out'), findsOneWidget);
  });

  testWidgets('Onboarding dots are interactive and have correct semantics', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: OnboardingScreen(onComplete: () {}),
        ),
      ),
    );

    // Find the first dot by semantic label
    final dot1Finder = find.bySemanticsLabel('Page 1 of 4');
    expect(dot1Finder, findsOneWidget);

    // Verify properties of the first dot
    final dot1Semantics = tester.getSemantics(dot1Finder);
    expect(dot1Semantics.hasFlag(SemanticsFlag.isSelected), isTrue);
    expect(dot1Semantics.hasFlag(SemanticsFlag.isButton), isTrue);

    // Find the second dot
    final dot2Finder = find.bySemanticsLabel('Page 2 of 4');
    expect(dot2Finder, findsOneWidget);
    final dot2Semantics = tester.getSemantics(dot2Finder);
    expect(dot2Semantics.hasFlag(SemanticsFlag.isSelected), isFalse);

    // Tap the second dot
    await tester.tap(dot2Finder);
    await tester.pumpAndSettle(); // Wait for animation

    // Verify page changed
    expect(find.text('Know Your Real Returns'), findsOneWidget);

    // Verify selection state updated
    final dot1SemanticsAfter = tester.getSemantics(find.bySemanticsLabel('Page 1 of 4'));
    final dot2SemanticsAfter = tester.getSemantics(find.bySemanticsLabel('Page 2 of 4'));

    expect(dot1SemanticsAfter.hasFlag(SemanticsFlag.isSelected), isFalse);
    expect(dot2SemanticsAfter.hasFlag(SemanticsFlag.isSelected), isTrue);
  });
}
