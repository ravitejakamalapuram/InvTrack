// Tests for QuickStatCard widget with privacy mode support.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/quick_stat_card.dart';
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

  group('QuickStatCard', () {
    testWidgets('should display value when privacy mode is off',
        (tester) async {
      await pumpWithPrivacyMode(
        tester,
        const QuickStatCard(
          icon: Icons.trending_up,
          label: 'MOIC',
          value: '2.5x',
          color: Colors.green,
        ),
        privacyModeEnabled: false,
      );

      expect(find.text('MOIC'), findsOneWidget);
      expect(find.text('2.5x'), findsOneWidget);
    });

    testWidgets('should mask sensitive value when privacy mode is on',
        (tester) async {
      await pumpWithPrivacyMode(
        tester,
        const QuickStatCard(
          icon: Icons.trending_up,
          label: 'Net Returns',
          value: '\$10,000',
          color: Colors.green,
          isSensitive: true, // default
        ),
        privacyModeEnabled: true,
      );
      await tester.pumpAndSettle();

      // Label should still be visible
      expect(find.text('Net Returns'), findsOneWidget);
      // Value should be masked
      expect(find.text('\$10,000'), findsNothing);
      expect(find.textContaining('•'), findsOneWidget);
    });

    testWidgets('should NOT mask value when isSensitive is false',
        (tester) async {
      await pumpWithPrivacyMode(
        tester,
        const QuickStatCard(
          icon: Icons.receipt_long,
          label: 'Cash Flows',
          value: '42',
          color: Colors.blue,
          isSensitive: false, // Not sensitive
        ),
        privacyModeEnabled: true,
      );
      await tester.pumpAndSettle();

      // Both label and value should be visible
      expect(find.text('Cash Flows'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('should hide subtitle when privacy mode is on and sensitive',
        (tester) async {
      await pumpWithPrivacyMode(
        tester,
        const QuickStatCard(
          icon: Icons.trending_up,
          label: 'MOIC',
          value: '2.5x',
          color: Colors.green,
          subtitle: 'over 24 months',
          isSensitive: true,
        ),
        privacyModeEnabled: true,
      );
      await tester.pumpAndSettle();

      // Subtitle should have opacity 0 (hidden via AnimatedOpacity)
      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.text('over 24 months'),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(animatedOpacity.opacity, 0.0);
    });

    testWidgets('should show subtitle when privacy mode is off',
        (tester) async {
      await pumpWithPrivacyMode(
        tester,
        const QuickStatCard(
          icon: Icons.trending_up,
          label: 'MOIC',
          value: '2.5x',
          color: Colors.green,
          subtitle: 'over 24 months',
        ),
        privacyModeEnabled: false,
      );

      expect(find.text('over 24 months'), findsOneWidget);
      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.text('over 24 months'),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(animatedOpacity.opacity, 1.0);
    });
  });
}
