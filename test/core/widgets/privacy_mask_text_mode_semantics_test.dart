// Reproduction test for privacy mask text mode semantics leak.
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
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
  }

  group('PrivacyMask Text Mode Security', () {
    testWidgets('should announce "Hidden content" when useTextMask is true', (tester) async {
      await pumpWithPrivacyMode(
        tester,
        const PrivacyMask(
          useTextMask: true,
          child: Text('Secret'),
        ),
        privacyModeEnabled: true,
      );
      await tester.pumpAndSettle();

      // We verify that the "Hidden content" label is present.
      // If the fix is missing, this will likely fail because it will find "••••••" instead.
      expect(find.semantics.byLabel('Hidden content'), findsOneWidget);
    });
  });
}
