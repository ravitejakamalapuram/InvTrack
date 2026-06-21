/// Regression tests for Crashlytics in-app update null check crashes
///
/// Crashlytics Issues Fixed:
/// - 7c46c24b7ce305a1b5781c5e3b22884f
/// - c8f980cd37a050d99b236193ef9ea583
///
/// Bug: Null check operator used on a null value in _showFlexibleUpdateDialog
/// Root Cause: AppLocalizations (l10n) was null when showing update dialogs
/// Solution: Added explicit null check for l10n, returns early with error logging
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/in_app_update_initializer.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

void main() {
  group('In-App Update Null Check Regression Tests', () {
    testWidgets(
        'InAppUpdateInitializer does not crash when localizations missing',
        (tester) async {
      // Regression test for Crashlytics issues:
      // - 7c46c24b7ce305a1b5781c5e3b22884f
      // - c8f980cd37a050d99b236193ef9ea583

      // Create a widget WITHOUT proper localization setup
      // This simulates the crash scenario where l10n is null
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            // Intentionally NOT providing AppLocalizations
            // to simulate the crash scenario
            home: InAppUpdateInitializer(
              child: Scaffold(
                body: Center(child: Text('Test')),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should NOT crash - widget should handle missing localizations gracefully
      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets(
        'InAppUpdateInitializer works correctly with proper localization',
        (tester) async {
      // Test the happy path - when localizations are properly set up
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: InAppUpdateInitializer(
              child: Scaffold(
                body: Center(child: Text('Test with l10n')),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should work normally with localizations
      expect(find.text('Test with l10n'), findsOneWidget);
    });

    testWidgets('InAppUpdateInitializer child renders regardless of l10n',
        (tester) async {
      // Verify that the child widget is always rendered,
      // even if update dialogs can't be shown due to missing l10n
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: InAppUpdateInitializer(
              child: Scaffold(
                body: Column(
                  children: [
                    Text('Child Widget 1'),
                    Text('Child Widget 2'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Child widgets should always render
      expect(find.text('Child Widget 1'), findsOneWidget);
      expect(find.text('Child Widget 2'), findsOneWidget);
    });

    testWidgets('InAppUpdateInitializer disposes properly', (tester) async {
      // Test that the widget disposes without errors
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: InAppUpdateInitializer(
              child: Scaffold(
                body: Text('Dispose Test'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Dispose Test'), findsOneWidget);

      // Navigate away to trigger dispose
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text('New Screen'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should dispose without errors
      expect(find.text('New Screen'), findsOneWidget);
      expect(find.text('Dispose Test'), findsNothing);
    });
  });
}
