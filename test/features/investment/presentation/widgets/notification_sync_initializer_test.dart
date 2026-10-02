import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/notifications/notification_settings_provider.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/notification_sync_initializer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import '../../../../mocks/mock_notification_service.dart';

// A08 (#751): the initializer keeps per-investment reminders in step with
// the data and clears every scheduled alarm when the signed-in user goes away.
void main() {
  late FakeFlutterLocalNotificationsPlugin fakePlugin;
  late NotificationService service;
  late StreamController<UserEntity?> auth;
  late StreamController<List<InvestmentEntity>> investments;
  late StreamController<List<CashFlowEntity>> cashFlows;

  setUp(() async {
    tz_data.initializeTimeZones();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    fakePlugin = FakeFlutterLocalNotificationsPlugin();
    service = NotificationService(
      fakePlugin,
      prefs,
      clock: () => DateTime(2026, 10, 2, 10),
    );
    // Initialise outside the widget test's fake-async zone, where the
    // timezone platform call can complete.
    await service.initialize();
    auth = StreamController<UserEntity?>.broadcast();
    investments = StreamController<List<InvestmentEntity>>.broadcast();
    cashFlows = StreamController<List<CashFlowEntity>>.broadcast();
  });

  tearDown(() async {
    await auth.close();
    await investments.close();
    await cashFlows.close();
  });

  UserEntity user(String id, {bool isAnonymous = false}) =>
      UserEntity(id: id, email: '$id@example.com', isAnonymous: isAnonymous);

  final p2p = InvestmentEntity(
    id: 'inv-p2p',
    name: 'P2P Monthly',
    type: InvestmentType.p2pLending,
    status: InvestmentStatus.open,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    startDate: DateTime(2026, 1, 15),
    incomeFrequency: IncomeFrequency.monthly,
  );

  Future<ProviderContainer> pumpInitializer(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => auth.stream),
          notificationServiceProvider.overrideWithValue(service),
          allInvestmentsProvider.overrideWith((ref) => investments.stream),
          allCashFlowsStreamProvider.overrideWith((ref) => cashFlows.stream),
        ],
        child: const NotificationSyncInitializer(child: SizedBox()),
      ),
    );
    return ProviderScope.containerOf(tester.element(find.byType(SizedBox)));
  }

  /// Let streams deliver, debounce timers expire and async work finish.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 3));
    }
  }

  DateTime? incomeReminderDate() {
    final matches = fakePlugin.scheduledNotifications.where(
      (n) => n.id == NotificationIds.incomeReminder('inv-p2p'),
    );
    if (matches.isEmpty) return null;
    // Plain local DateTime (TZDateTime never equals a DateTime).
    return DateTime.fromMillisecondsSinceEpoch(
      matches.single.scheduledDate.millisecondsSinceEpoch,
    );
  }

  group('NotificationSyncInitializer - account changes', () {
    testWidgets(
      'sign-out or account deletion (user becomes null) cancels all',
      (tester) async {
        await pumpInitializer(tester);
        auth.add(user('uid-a'));
        await settle(tester);
        expect(fakePlugin.allCancelled, isFalse);

        auth.add(null);
        await settle(tester);

        expect(fakePlugin.allCancelled, isTrue);
      },
    );

    testWidgets('switching to a different account cancels all', (tester) async {
      await pumpInitializer(tester);
      auth.add(user('uid-a'));
      await settle(tester);

      auth.add(user('uid-b'));
      await settle(tester);

      expect(fakePlugin.allCancelled, isTrue);
    });

    testWidgets('linking a guest account (same uid) keeps alarms', (
      tester,
    ) async {
      await pumpInitializer(tester);
      auth.add(user('uid-a', isAnonymous: true));
      await settle(tester);

      auth.add(user('uid-a'));
      await settle(tester);

      expect(fakePlugin.allCancelled, isFalse);
    });

    testWidgets('signing in after a sign-out restores app-wide reminders', (
      tester,
    ) async {
      await pumpInitializer(tester);
      auth.add(user('uid-a'));
      await settle(tester);
      auth.add(null);
      await settle(tester);
      expect(fakePlugin.scheduledNotifications, isEmpty);

      auth.add(user('uid-b'));
      await settle(tester);

      final ids = fakePlugin.scheduledNotifications.map((n) => n.id);
      expect(ids, contains(NotificationIds.weeklyCheckIn));
      expect(ids, contains(NotificationIds.fySummary));
    });
  });

  group('NotificationSyncInitializer - income reminders', () {
    testWidgets(
      'anchors on startDate, then follows INCOME flows being added and deleted',
      (tester) async {
        await pumpInitializer(tester);
        auth.add(user('uid-a'));
        investments.add([p2p]);
        cashFlows.add(const []);
        await settle(tester);

        // No income yet: startDate (15 Jan) + k months, first after 2 Oct.
        expect(incomeReminderDate(), DateTime(2026, 10, 15, 9));

        cashFlows.add([
          CashFlowEntity(
            id: 'cf-1',
            investmentId: 'inv-p2p',
            date: DateTime(2026, 10, 1),
            type: CashFlowType.income,
            amount: 4500,
            createdAt: DateTime(2026, 10, 1),
            currency: 'INR',
          ),
        ]);
        await settle(tester);

        expect(incomeReminderDate(), DateTime(2026, 11, 1, 9));

        // Deleting that INCOME flow moves the anchor back to startDate.
        cashFlows.add(const []);
        await settle(tester);

        expect(incomeReminderDate(), DateTime(2026, 10, 15, 9));
      },
    );

    testWidgets('turning income reminders back on reschedules them', (
      tester,
    ) async {
      final container = await pumpInitializer(tester);
      auth.add(user('uid-a'));
      investments.add([p2p]);
      cashFlows.add(const []);
      await settle(tester);
      expect(incomeReminderDate(), isNotNull);

      final settings = container.read(notificationSettingsProvider.notifier);
      await settings.setSetting(NotificationSettingType.incomeReminders, false);
      await settle(tester);
      expect(incomeReminderDate(), isNull);

      await settings.setSetting(NotificationSettingType.incomeReminders, true);
      await settle(tester);

      expect(incomeReminderDate(), DateTime(2026, 10, 15, 9));
    });

    testWidgets(
      'deleting the last investment cancels its income and maturity reminders',
      (tester) async {
        final bond = InvestmentEntity(
          id: 'inv-bond',
          name: 'Bond',
          type: InvestmentType.bonds,
          status: InvestmentStatus.open,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
          startDate: DateTime(2026, 1, 15),
          maturityDate: DateTime(2027, 1, 15),
          incomeFrequency: IncomeFrequency.monthly,
        );
        final bondIds = {
          NotificationIds.incomeReminder('inv-bond'),
          NotificationIds.maturityReminder7Days('inv-bond'),
          NotificationIds.maturityReminder1Day('inv-bond'),
        };
        Set<int> pendingIds() =>
            fakePlugin.scheduledNotifications.map((n) => n.id).toSet();

        await pumpInitializer(tester);
        auth.add(user('uid-a'));
        investments.add([bond]);
        cashFlows.add(const []);
        await settle(tester);
        expect(pendingIds(), containsAll(bondIds));

        // Bulk delete, clearing sample data, or a delete on another device.
        investments.add(const []);
        await settle(tester);

        expect(pendingIds().intersection(bondIds), isEmpty);
      },
    );
  });
}
