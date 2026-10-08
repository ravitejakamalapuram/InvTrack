// A127: a failed navigation from a report notification is one failure, so it
// must reach Crashlytics once, not once from the log and again from a direct
// recordError.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/notifications/notification_navigator.dart';
import 'package:inv_tracker/core/notifications/notification_payload.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';

import '../../mocks/crashlytics_recorder.dart';

class _Unlocked extends SecurityNotifier {
  @override
  SecurityState build() => const SecurityState();
}

void main() {
  testWidgets('a failed report navigation is recorded exactly once', (
    tester,
  ) async {
    final records = recordCrashReports();
    // No GoRouter above the root navigator, so the push throws.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [securityProvider.overrideWith(_Unlocked.new)],
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          home: const SizedBox(),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SizedBox)),
    );

    final opened = await container
        .read(notificationNavigatorProvider)
        .handleNotificationTap(NotificationPayload.weeklySummary);
    await tester.pump();

    expect(opened, isFalse);
    expect(records, hasLength(1));
    expect(records.single.fatal, isFalse);
    expect(
      records.single.reason,
      'Failed to navigate to dynamic report | Metadata: '
      'reportType=weekly_summary',
    );
  });
}
