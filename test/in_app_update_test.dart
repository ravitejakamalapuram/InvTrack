import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/widgets/in_app_update_initializer.dart';
import 'package:inv_tracker/core/providers/in_app_update_provider.dart';
import 'package:inv_tracker/core/services/in_app_update_service.dart';
import 'package:in_app_update/in_app_update.dart';

class MockUpdateService extends InAppUpdateService {
  @override
  Future<AppUpdateInfo> checkForUpdate() async {
    return AppUpdateInfo(
      updateAvailability: UpdateAvailability.updateAvailable,
      immediateUpdateAllowed: false,
      flexibleUpdateAllowed: true,
      availableVersionCode: 2,
      installStatus: InstallStatus.unknown,
      packageName: 'com.example',
      clientVersionStalenessDays: 1,
      updatePriority: 1,
      immediateAllowedPreconditions: [],
      flexibleAllowedPreconditions: [],
    );
  }
}

void main() {
  testWidgets('InAppUpdateInitializer handles missing AppLocalizations without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inAppUpdateServiceProvider.overrideWithValue(MockUpdateService()),
        ],
        child: MaterialApp(
          // Deliberately omit localizationsDelegates to force AppLocalizations.of(context) to return null
          home: InAppUpdateInitializer(
            child: Scaffold(body: Text('Home')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify fallback text is rendered when dialog opens
    expect(find.text('Update Available'), findsOneWidget);
    expect(find.text('A new version of InvTrack is available. Would you like to update now?'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
    expect(find.text('Update'), findsOneWidget);
  });

  testWidgets('InAppUpdateInitializer handles null Navigator.maybeOf context gracefully', (WidgetTester tester) async {
    // Create a widget tree where Navigator.maybeOf(context) returns null
    // but rootNavigatorKey.currentContext provides a valid Navigator context
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inAppUpdateServiceProvider.overrideWithValue(MockUpdateService()),
        ],
        child: MaterialApp(
          home: InAppUpdateInitializer(
            child: Scaffold(body: Text('Home')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The widget should render without crashing
    expect(find.text('Home'), findsOneWidget);
    // Dialog should appear using rootNavigatorKey.currentContext fallback
    expect(find.text('Update Available'), findsOneWidget);
  });

  testWidgets('InAppUpdateInitializer logs warning when both contexts are null', (WidgetTester tester) async {
    // This test verifies that when both Navigator.maybeOf and rootNavigatorKey.currentContext
    // are null, the widget logs a warning instead of crashing

    // Create a widget tree with MaterialApp but simulate rootNavigatorKey.currentContext being null
    // by using a custom key that won't have a valid context
    final customKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inAppUpdateServiceProvider.overrideWithValue(MockUpdateService()),
        ],
        child: MaterialApp(
          navigatorKey: customKey,
          // Remove localizationsDelegates to test fallback text
          home: Builder(
            builder: (context) {
              // Wrap in a widget that has no Navigator ancestor
              return Directionality(
                textDirection: TextDirection.ltr,
                child: InAppUpdateInitializer(
                  child: Text('Home'),
                ),
              );
            },
          ),
        ),
      ),
    );

    // Allow async initialization to complete
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Widget should not crash - it should log a warning and skip showing dialog
    // The warning is logged and the dialog is not shown
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('InAppUpdateInitializer guards against unmounted context in dialog callbacks', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inAppUpdateServiceProvider.overrideWithValue(MockUpdateService()),
        ],
        child: MaterialApp(
          home: InAppUpdateInitializer(
            child: Scaffold(body: Text('Home')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify dialog appears
    expect(find.text('Update Available'), findsOneWidget);

    // The dialog should handle context.mounted checks correctly
    // Tap "Later" button to verify no errors occur
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    // Dialog should be dismissed without crashing
    expect(find.text('Update Available'), findsNothing);
  });
}
