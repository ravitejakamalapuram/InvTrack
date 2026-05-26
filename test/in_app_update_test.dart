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
      installStatus: InstallStatus.downloaded,
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
}
