import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('OnboardingScreen loads and shows first page', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: OnboardingScreen(onComplete: () {}),
        ),
      ),
    );

    expect(find.text('Track Money In & Out'), findsOneWidget);
  });

  testWidgets('Onboarding dots are interactive and have correct semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: OnboardingScreen(onComplete: () {}),
        ),
      ),
    );

    // Find the first dot by semantic label
    final dot1Finder = find.bySemanticsLabel('Page 1 of 4');
    expect(dot1Finder, findsOneWidget);

    // Verify properties of the first dot
    final dot1Semantics = tester.getSemantics(dot1Finder);
    expect(dot1Semantics.flagsCollection.isSelected, equals(Tristate.isTrue));
    expect(dot1Semantics.flagsCollection.isButton, isTrue);

    // Find the second dot
    final dot2Finder = find.bySemanticsLabel('Page 2 of 4');
    expect(dot2Finder, findsOneWidget);
    final dot2Semantics = tester.getSemantics(dot2Finder);
    expect(
      dot2Semantics.flagsCollection.isSelected,
      isNot(equals(Tristate.isTrue)),
    );

    // Tap the second dot
    await tester.tap(dot2Finder);
    await tester.pumpAndSettle(); // Wait for animation

    // Verify page changed
    expect(find.text('Know Your Real Returns'), findsOneWidget);

    // Verify selection state updated
    final dot1SemanticsAfter = tester.getSemantics(
      find.bySemanticsLabel('Page 1 of 4'),
    );
    final dot2SemanticsAfter = tester.getSemantics(
      find.bySemanticsLabel('Page 2 of 4'),
    );

    expect(
      dot1SemanticsAfter.flagsCollection.isSelected,
      isNot(equals(Tristate.isTrue)),
    );
    expect(
      dot2SemanticsAfter.flagsCollection.isSelected,
      equals(Tristate.isTrue),
    );
  });
}
