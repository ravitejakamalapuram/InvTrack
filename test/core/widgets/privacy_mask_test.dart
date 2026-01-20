// Tests for privacy mask widgets.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
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

  group('PrivacyMask', () {
    testWidgets('should show child when privacy mode is off', (tester) async {
      await pumpWithPrivacyMode(
        tester,
        const PrivacyMask(child: Text('Secret Amount')),
        privacyModeEnabled: false,
      );

      expect(find.text('Secret Amount'), findsOneWidget);
    });

    testWidgets('should hide child with blur when privacy mode is on',
        (tester) async {
      await pumpWithPrivacyMode(
        tester,
        const PrivacyMask(child: Text('Secret Amount')),
        privacyModeEnabled: true,
      );
      await tester.pumpAndSettle();

      // Child is wrapped with blur, so we check for ImageFiltered
      expect(find.byType(ImageFiltered), findsOneWidget);
    });

    testWidgets('should show masked text when useTextMask is true',
        (tester) async {
      await pumpWithPrivacyMode(
        tester,
        const PrivacyMask(
          useTextMask: true,
          maskedText: '•••',
          child: Text('Secret Amount'),
        ),
        privacyModeEnabled: true,
      );
      await tester.pumpAndSettle();

      expect(find.text('•••'), findsOneWidget);
      expect(find.text('Secret Amount'), findsNothing);
    });
  });

  group('MaskedAmountText', () {
    testWidgets('should show actual text when privacy mode is off',
        (tester) async {
      await pumpWithPrivacyMode(
        tester,
        const MaskedAmountText(text: '\$1,234.56'),
        privacyModeEnabled: false,
      );

      expect(find.text('\$1,234.56'), findsOneWidget);
    });

    testWidgets('should show masked pattern when privacy mode is on',
        (tester) async {
      await pumpWithPrivacyMode(
        tester,
        const MaskedAmountText(text: '\$1,234.56'),
        privacyModeEnabled: true,
      );
      await tester.pumpAndSettle();

      // Should show dot pattern instead of actual text
      expect(find.text('\$1,234.56'), findsNothing);
      expect(find.textContaining('•'), findsOneWidget);

      // Verify expensive ShaderMask is not used
      expect(find.byType(ShaderMask), findsNothing);
    });

    testWidgets('should apply text style to masked text', (tester) async {
      const testStyle = TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.red,
      );

      await pumpWithPrivacyMode(
        tester,
        const MaskedAmountText(text: '\$1,234.56', style: testStyle),
        privacyModeEnabled: true,
      );
      await tester.pumpAndSettle();

      final maskedText = find.textContaining('•');
      expect(maskedText, findsOneWidget);

      // Verify style is applied (check text widget has correct fontSize)
      final textWidget = tester.widget<Text>(maskedText);
      expect(textWidget.style?.fontSize, 24);
      expect(textWidget.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('should show more dots for larger font sizes', (tester) async {
      await pumpWithPrivacyMode(
        tester,
        const MaskedAmountText(
          text: '\$1,234.56',
          style: TextStyle(fontSize: 36),
        ),
        privacyModeEnabled: true,
      );
      await tester.pumpAndSettle();

      expect(find.text('••••••'), findsOneWidget);
    });
  });

  group('Privacy Mode Toggle', () {
    testWidgets('should toggle privacy mode state', (tester) async {
      SharedPreferences.setMockInitialValues({'privacy_mode_enabled': false});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      // Initially privacy mode is off
      expect(container.read(privacyModeProvider), false);

      // Toggle privacy mode
      await container.read(privacyModeProvider.notifier).toggle();

      // Now should be on
      expect(container.read(privacyModeProvider), true);

      container.dispose();
    });
  });
}

