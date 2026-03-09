// Tests for privacy mask semantics security.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  /// Helper to pump widget with privacy mode state.
  Future<void> pumpWithPrivacyMode(
    WidgetTester tester,
    Widget child, {
    required bool privacyModeEnabled,
  }) async {
    SharedPreferences.setMockInitialValues({
      'privacy_mode_enabled': privacyModeEnabled,
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
  }

  group('PrivacyMask Security', () {
    testWidgets('should hide child semantics when privacy mode is on', (
      tester,
    ) async {
      await pumpWithPrivacyMode(
        tester,
        const PrivacyMask(
          child: Text('Secret Amount', semanticsLabel: 'Secret'),
        ),
        privacyModeEnabled: true,
      );
      await tester.pumpAndSettle();

      // FIXED BEHAVIOR:
      // We WANT 'Hidden content'.
      expect(find.semantics.byLabel('Hidden content'), findsOneWidget);
      // We also check that the child semantics are excluded
      expect(find.semantics.byLabel('Secret'), findsNothing);
    });
  });

  group('MaskedAmountText Security', () {
    testWidgets('should announce "Hidden amount" instead of bullets', (
      tester,
    ) async {
      await pumpWithPrivacyMode(
        tester,
        const MaskedAmountText(text: '\$1,234.56'),
        privacyModeEnabled: true,
      );
      await tester.pumpAndSettle();

      // FIXED BEHAVIOR:
      // Should find "Hidden amount"
      expect(find.semantics.byLabel('Hidden amount'), findsOneWidget);

      // Should NOT find bullets in semantics (because semanticsLabel overrides it)
      expect(find.semantics.byLabel('•••••'), findsNothing);
    });
  });
}
