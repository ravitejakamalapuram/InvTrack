// A29 part 4 (#780): Settings > Notifications has a switch for every type,
// including the ones that used to be on with no way to turn them off.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/features/settings/presentation/screens/notifications_settings_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/mock_notification_service.dart';

void main() {
  const titles = [
    'Weekly Summary',
    'Monthly Summary',
    'Income Reminders',
    'Maturity Reminders',
    'Investment Milestones',
    'Tax Reminders',
    'Weekly Check-In',
    'Financial Year Summary',
    'Goal Milestones',
    'Goals At Risk',
    'Stale Goals',
  ];

  testWidgets('every notification type has a switch, and one persists', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final service = NotificationService(
      FakeFlutterLocalNotificationsPlugin(),
      await SharedPreferences.getInstance(),
    )..preferencesUid = 'a';
    await tester.binding.setSurfaceSize(const Size(800, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NotificationsSettingsScreen(),
        ),
      ),
    );

    for (final title in titles) {
      expect(find.text(title), findsOneWidget, reason: title);
    }

    await tester.tap(find.text('Goals At Risk'));
    await tester.pump();

    expect(service.goalAtRiskEnabled, isFalse);
    service.preferencesUid = 'b';
    expect(service.goalAtRiskEnabled, isTrue);
  });
}
