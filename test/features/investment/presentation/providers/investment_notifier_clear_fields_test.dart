// A22 (#764, INV-05): editing an investment must be able to clear its
// optional fields. The edit form pre-fills every field from the stored
// investment, so a field it sends as null is one the user cleared. That null
// must be persisted, or the old value (and its reminders) come back.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import '../../data/repositories/mock_investment_repository.dart';
import '../../../../mocks/mock_analytics_service.dart';
import '../../../../mocks/mock_notification_service.dart';

/// The optional fields the edit form can clear.
const _optionalFields = [
  'notes',
  'maturityDate',
  'incomeFrequency',
  'startDate',
  'expectedRate',
  'tenureMonths',
  'platform',
  'interestPayoutMode',
  'autoRenewal',
  'riskLevel',
  'compoundingFrequency',
];

Object? _field(InvestmentEntity i, String name) => switch (name) {
  'notes' => i.notes,
  'maturityDate' => i.maturityDate,
  'incomeFrequency' => i.incomeFrequency,
  'startDate' => i.startDate,
  'expectedRate' => i.expectedRate,
  'tenureMonths' => i.tenureMonths,
  'platform' => i.platform,
  'interestPayoutMode' => i.interestPayoutMode,
  'autoRenewal' => i.autoRenewal,
  'riskLevel' => i.riskLevel,
  'compoundingFrequency' => i.compoundingFrequency,
  _ => throw ArgumentError(name),
};

InvestmentEntity _fullyPopulated({
  String id = 'inv-fd',
  bool isArchived = false,
  InvestmentStatus status = InvestmentStatus.open,
  DateTime? closedAt,
}) => InvestmentEntity(
  id: id,
  name: 'HDFC FD',
  type: InvestmentType.fixedDeposit,
  status: status,
  notes: 'Old notes',
  createdAt: DateTime(2026, 4, 1, 9, 30),
  closedAt: closedAt,
  updatedAt: DateTime(2026, 4, 1, 9, 30),
  maturityDate: DateTime(2027, 4, 1),
  incomeFrequency: IncomeFrequency.quarterly,
  isArchived: isArchived,
  startDate: DateTime(2026, 4, 1),
  expectedRate: 7.25,
  tenureMonths: 12,
  platform: 'HDFC Bank',
  interestPayoutMode: InterestPayoutMode.periodic,
  autoRenewal: true,
  riskLevel: RiskLevel.low,
  compoundingFrequency: CompoundingFrequency.quarterly,
  currency: 'EUR',
);

void main() {
  late FakeInvestmentRepository fakeRepository;
  late FakeNotificationService fakeNotificationService;
  late ProviderContainer container;
  late InvestmentNotifier notifier;

  setUp(() {
    fakeRepository = FakeInvestmentRepository();
    fakeNotificationService = FakeNotificationService();
    container = ProviderContainer(
      overrides: [
        investmentRepositoryProvider.overrideWithValue(fakeRepository),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        notificationServiceProvider.overrideWithValue(fakeNotificationService),
        currencyCodeProvider.overrideWithValue('INR'),
      ],
    );
    notifier = container.read(investmentNotifierProvider.notifier);
  });

  tearDown(() {
    container.dispose();
    fakeRepository.reset();
    fakeNotificationService.reset();
  });

  /// Saves the edit form for [from] the way AddInvestmentScreen does: every
  /// field carries its pre-filled value, except the [cleared] ones, which the
  /// user emptied and the form therefore sends as null.
  Future<void> saveEdit(
    InvestmentEntity from, {
    Set<String> cleared = const {},
    bool sendCurrency = true,
  }) {
    T? keep<T>(String field, T? value) =>
        cleared.contains(field) ? null : value;
    return notifier.updateInvestment(
      id: from.id,
      name: from.name,
      type: from.type,
      notes: keep('notes', from.notes),
      maturityDate: keep('maturityDate', from.maturityDate),
      incomeFrequency: keep('incomeFrequency', from.incomeFrequency),
      startDate: keep('startDate', from.startDate),
      expectedRate: keep('expectedRate', from.expectedRate),
      tenureMonths: keep('tenureMonths', from.tenureMonths),
      platform: keep('platform', from.platform),
      interestPayoutMode: keep('interestPayoutMode', from.interestPayoutMode),
      autoRenewal: keep('autoRenewal', from.autoRenewal),
      riskLevel: keep('riskLevel', from.riskLevel),
      compoundingFrequency: keep(
        'compoundingFrequency',
        from.compoundingFrequency,
      ),
      currency: sendCurrency ? from.currency : null,
    );
  }

  group('InvestmentNotifier.updateInvestment - clearing optional fields', () {
    for (final field in _optionalFields) {
      test(
        'clearing $field persists null and keeps every other field',
        () async {
          final original = _fullyPopulated();
          fakeRepository.seed(investments: [original]);

          await saveEdit(original, cleared: {field});

          final stored = fakeRepository.investments.single;
          expect(_field(stored, field), isNull, reason: '$field was cleared');
          for (final other in _optionalFields.where((f) => f != field)) {
            expect(
              _field(stored, other),
              _field(original, other),
              reason: '$other was not touched',
            );
          }
        },
      );
    }

    test('clearing every optional field at once persists all nulls', () async {
      final original = _fullyPopulated();
      fakeRepository.seed(investments: [original]);

      await saveEdit(original, cleared: _optionalFields.toSet());

      final stored = fakeRepository.investments.single;
      for (final field in _optionalFields) {
        expect(_field(stored, field), isNull, reason: field);
      }
    });

    test(
      'keeps identity and lifecycle fields the form does not edit',
      () async {
        final closedAt = DateTime(2026, 9, 30);
        final original = _fullyPopulated(
          status: InvestmentStatus.closed,
          closedAt: closedAt,
        );
        fakeRepository.seed(investments: [original]);

        await saveEdit(
          original,
          cleared: {'maturityDate', 'notes'},
          sendCurrency: false,
        );

        final stored = fakeRepository.investments.single;
        expect(stored.id, 'inv-fd');
        expect(stored.name, 'HDFC FD');
        expect(stored.type, InvestmentType.fixedDeposit);
        expect(stored.status, InvestmentStatus.closed);
        expect(stored.closedAt, closedAt);
        expect(stored.createdAt, DateTime(2026, 4, 1, 9, 30));
        expect(stored.isArchived, isFalse);
        // No currency from the form keeps the stored one, never USD or base.
        expect(stored.currency, 'EUR');
        expect(stored.updatedAt.isAfter(original.updatedAt), isTrue);
      },
    );

    test('clearing a field on an archived investment persists null', () async {
      final original = _fullyPopulated(isArchived: true);
      fakeRepository.seed(archivedInvestments: [original]);

      await saveEdit(
        original,
        cleared: {'maturityDate', 'incomeFrequency', 'expectedRate'},
      );

      expect(fakeRepository.investments, isEmpty);
      final stored = fakeRepository.archivedInvestments.single;
      expect(stored.isArchived, isTrue);
      expect(stored.maturityDate, isNull);
      expect(stored.incomeFrequency, isNull);
      expect(stored.expectedRate, isNull);
      expect(stored.platform, 'HDFC Bank');
    });
  });

  group('Cleared reminders stay cleared on the next launch', () {
    late FakeFlutterLocalNotificationsPlugin fakePlugin;
    late NotificationService launchService;

    setUp(() async {
      tz_data.initializeTimeZones();
      fakePlugin = FakeFlutterLocalNotificationsPlugin();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      launchService = NotificationService(
        fakePlugin,
        prefs,
        clock: () => DateTime(2026, 10, 3, 10),
      );
    });

    tearDown(() => fakePlugin.reset());

    Future<Set<int>> rescheduleFromStore() async {
      // What NotificationSyncInitializer does on launch: reschedule from
      // the stored investments.
      await launchService.rescheduleAllNotifications(
        fakeRepository.investments,
        lastIncomeDates: const {},
      );
      return (await fakePlugin.pendingNotificationRequests())
          .map((p) => p.id)
          .toSet();
    }

    final reminderIds = {
      NotificationIds.maturityReminder7Days('inv-fd'),
      NotificationIds.maturityReminder1Day('inv-fd'),
      NotificationIds.incomeReminder('inv-fd'),
    };

    test('control: the stored investment schedules its reminders', () async {
      fakeRepository.seed(investments: [_fullyPopulated()]);

      expect(await rescheduleFromStore(), containsAll(reminderIds));
    });

    test('clearing maturity date and income frequency removes the reminders '
        'now and after a restart', () async {
      final original = _fullyPopulated();
      fakeRepository.seed(investments: [original]);

      await saveEdit(original, cleared: {'maturityDate', 'incomeFrequency'});

      expect(fakeNotificationService.cancelledMaturityReminders, ['inv-fd']);
      expect(fakeNotificationService.cancelledIncomeReminders, ['inv-fd']);
      expect(fakeNotificationService.scheduledMaturityReminders, isEmpty);
      expect(fakeNotificationService.scheduledIncomeReminders, isEmpty);

      final pending = await rescheduleFromStore();
      for (final id in reminderIds) {
        expect(pending, isNot(contains(id)));
      }
    });
  });
}
