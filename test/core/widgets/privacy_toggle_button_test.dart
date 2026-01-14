import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/privacy_toggle_button.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildTestWidget(Widget child) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(child: child),
        ),
      ),
    );
  }

  group('PrivacyToggleButton', () {
    testWidgets('has semantic label', (tester) async {
      await tester.pumpWidget(buildTestWidget(const PrivacyToggleButton()));

      // Initial state is false (privacy mode off), so amounts are shown.
      // Button should say "Hide amounts" because clicking it hides them?
      // Wait, let's check logic:
      // isPrivacyMode = false. Icon is visibility_rounded (eye open).
      // Logic: toggle() -> sets isPrivacyMode = true.
      // If isPrivacyMode is false (visible), action is to "Hide amounts" (make them invisible).
      // If isPrivacyMode is true (hidden), action is to "Show amounts".

      // Let's verify existing CompactPrivacyToggle logic:
      // tooltip: isPrivacyMode ? 'Show amounts' : 'Hide amounts'
      // If isPrivacyMode is true (hidden), button shows 'Show amounts'. Correct.
      // If isPrivacyMode is false (visible), button shows 'Hide amounts'. Correct.

      expect(find.bySemanticsLabel('Hide amounts'), findsOneWidget);
    });

    testWidgets('toggles semantics when tapped', (tester) async {
      await tester.pumpWidget(buildTestWidget(const PrivacyToggleButton()));

      // Initially "Hide amounts"
      expect(find.bySemanticsLabel('Hide amounts'), findsOneWidget);

      // Tap to toggle
      await tester.tap(find.byType(PrivacyToggleButton));
      await tester.pumpAndSettle();

      // Now "Show amounts"
      expect(find.bySemanticsLabel('Show amounts'), findsOneWidget);
    });

    testWidgets('is identified as a button', (tester) async {
      await tester.pumpWidget(buildTestWidget(const PrivacyToggleButton()));

      final semantics = tester.getSemantics(find.byType(PrivacyToggleButton));
      expect(semantics.isButton, isTrue);
    });
  });

  group('CompactPrivacyToggle', () {
    testWidgets('has semantic label via tooltip', (tester) async {
      await tester.pumpWidget(buildTestWidget(const CompactPrivacyToggle()));

      expect(find.byTooltip('Hide amounts'), findsOneWidget);
      // IconButton uses tooltip as semantic label
      expect(find.bySemanticsLabel('Hide amounts'), findsOneWidget);
    });
  });
}
