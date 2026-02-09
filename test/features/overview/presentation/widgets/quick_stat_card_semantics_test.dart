// Tests for QuickStatCard semantics.
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

  group('QuickStatCard Semantics', () {
    testWidgets('should announce cohesive label when visible', (tester) async {
      await pumpWithPrivacyMode(
        tester,
        const QuickStatCard(
          icon: Icons.trending_up,
          label: 'Total Returns',
          value: '\$5,000',
          subtitle: 'Year to date',
          color: Colors.green,
          isSensitive: true,
        ),
        privacyModeEnabled: false,
      );

      // Verify the cohesive label is present
      expect(
        find.semantics.byLabel('Total Returns: \$5,000, Year to date'),
        findsOneWidget,
      );

      // Verify individual text semantics are excluded (not reachable as separate nodes)
      // Note: find.text finds widgets, find.semantics finds semantic nodes.
      // Since we used excludeSemantics: true, the children shouldn't have their own nodes exposed
      // BUT Semantics(excludeSemantics: true) replaces them.
      // So looking for 'Total Returns' as a semantic label should FAIL if it's merged into the parent.
      expect(find.semantics.byLabel('Total Returns'), findsNothing);
    });

    testWidgets('should announce hidden amount (and hide subtitle) when masked',
        (tester) async {
      await pumpWithPrivacyMode(
        tester,
        const QuickStatCard(
          icon: Icons.trending_up,
          label: 'Total Returns',
          value: '\$5,000',
          subtitle: 'Year to date',
          color: Colors.green,
          isSensitive: true,
        ),
        privacyModeEnabled: true,
      );
      await tester.pumpAndSettle();

      // Verify masked label contains ONLY label and "Hidden amount".
      // Subtitle should be excluded to match visual hiding and prevent data leakage.
      expect(
        find.semantics.byLabel('Total Returns: Hidden amount'),
        findsOneWidget,
      );

      // Verify original value is NOT exposed
      expect(find.semantics.byLabel('\$5,000'), findsNothing);
      // Verify subtitle is NOT exposed
      expect(find.semantics.byLabel(RegExp(r'Year to date')), findsNothing);
    });

    testWidgets('should handle missing subtitle gracefully', (tester) async {
      await pumpWithPrivacyMode(
        tester,
        const QuickStatCard(
          icon: Icons.trending_up,
          label: 'MOIC',
          value: '1.5x',
          color: Colors.blue,
          isSensitive: false,
        ),
        privacyModeEnabled: false,
      );

      expect(
        find.semantics.byLabel('MOIC: 1.5x'),
        findsOneWidget,
      );
    });
  });
}
