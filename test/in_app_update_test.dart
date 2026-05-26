import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/widgets/in_app_update_initializer.dart';
import 'package:inv_tracker/core/providers/in_app_update_provider.dart';
import 'package:inv_tracker/core/services/in_app_update_service.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class MockUpdateService extends InAppUpdateService {
  final InstallStatus customInstallStatus;

  MockUpdateService({this.customInstallStatus = InstallStatus.unknown});

  @override
  Future<AppUpdateInfo> checkForUpdate() async {
    return AppUpdateInfo(
      updateAvailability: UpdateAvailability.updateAvailable,
      immediateUpdateAllowed: false,
      flexibleUpdateAllowed: true,
      availableVersionCode: 2,
      installStatus: customInstallStatus,
      packageName: 'com.example',
      clientVersionStalenessDays: 1,
      updatePriority: 1,
      immediateAllowedPreconditions: [],
      flexibleAllowedPreconditions: [],
    );
  }

  @override
  Stream<InstallStatus> get installUpdateListener => const Stream.empty();
}

void main() {
  testWidgets('InAppUpdateInitializer handles missing AppLocalizations without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inAppUpdateServiceProvider.overrideWithValue(MockUpdateService(customInstallStatus: InstallStatus.unknown)),
        ],
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          // Deliberately omit localizationsDelegates to force AppLocalizations.of(context) to return null
          home: const InAppUpdateInitializer(
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

  testWidgets('InAppUpdateInitializer displays Update Ready dialog when update is already downloaded', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inAppUpdateServiceProvider.overrideWithValue(MockUpdateService(customInstallStatus: InstallStatus.downloaded)),
        ],
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const InAppUpdateInitializer(
            child: Scaffold(body: Text('Home')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify that the "Update Ready" / "Restart" dialog is shown with localized strings
    final BuildContext context = rootNavigatorKey.currentContext!;
    final l10n = AppLocalizations.of(context);

    expect(find.text(l10n.updateReady), findsOneWidget);
    expect(find.text(l10n.updateReadyMessage), findsOneWidget);
    expect(find.text(l10n.later), findsOneWidget);
    expect(find.text(l10n.restart), findsOneWidget);
  });
}
