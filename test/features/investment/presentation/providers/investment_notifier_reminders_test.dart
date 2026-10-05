// A117 (#891): editing a closed or archived investment must not bring back
// its income and maturity reminders; only an open, active investment has
// them. A17 (#762, GAP1-11): the same holds when a closed investment is
// unarchived.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_notifier.dart';

import '../../data/repositories/mock_investment_repository.dart';
import '../../../../mocks/mock_analytics_service.dart';
import '../../../../mocks/mock_notification_service.dart';

InvestmentEntity _fd({
  InvestmentStatus status = InvestmentStatus.open,
  bool isArchived = false,
}) => InvestmentEntity(
  id: 'inv-fd',
  name: 'HDFC FD',
  type: InvestmentType.fixedDeposit,
  status: status,
  notes: 'Old notes',
  createdAt: DateTime(2026, 1, 1),
  closedAt: status == InvestmentStatus.closed ? DateTime(2026, 9, 30) : null,
  updatedAt: DateTime(2026, 1, 1),
  maturityDate: DateTime(2027, 1, 1),
  incomeFrequency: IncomeFrequency.monthly,
  isArchived: isArchived,
  startDate: DateTime(2026, 1, 1),
  currency: 'INR',
);

void main() {
  late FakeInvestmentRepository repository;
  late FakeNotificationService notifications;
  late ProviderContainer container;
  late InvestmentNotifier notifier;

  setUp(() {
    repository = FakeInvestmentRepository();
    notifications = FakeNotificationService();
    container = ProviderContainer(
      overrides: [
        investmentRepositoryProvider.overrideWithValue(repository),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        notificationServiceProvider.overrideWithValue(notifications),
        currencyCodeProvider.overrideWithValue('INR'),
      ],
    );
    notifier = container.read(investmentNotifierProvider.notifier);
  });

  tearDown(() => container.dispose());

  /// Edits only the notes, sending every other field as stored.
  Future<void> editNotes(InvestmentEntity from) => notifier.updateInvestment(
    id: from.id,
    name: from.name,
    type: from.type,
    notes: 'Fixed a typo',
    maturityDate: from.maturityDate,
    incomeFrequency: from.incomeFrequency,
    startDate: from.startDate,
    currency: from.currency,
  );

  group('updateInvestment reminders', () {
    test(
      'a closed investment gets no reminders, and both are cancelled',
      () async {
        final closed = _fd(status: InvestmentStatus.closed);
        repository.seed(investments: [closed]);

        await editNotes(closed);

        expect(notifications.scheduledIncomeReminders, isEmpty);
        expect(notifications.scheduledMaturityReminders, isEmpty);
        expect(notifications.cancelledIncomeReminders, ['inv-fd']);
        expect(notifications.cancelledMaturityReminders, ['inv-fd']);
        expect(repository.investments.single.notes, 'Fixed a typo');
      },
    );

    test('an archived open investment gets no reminders', () async {
      final archived = _fd(isArchived: true);
      repository.seed(archivedInvestments: [archived]);

      await editNotes(archived);

      expect(notifications.scheduledIncomeReminders, isEmpty);
      expect(notifications.scheduledMaturityReminders, isEmpty);
      expect(notifications.cancelledIncomeReminders, ['inv-fd']);
      expect(notifications.cancelledMaturityReminders, ['inv-fd']);
      expect(repository.archivedInvestments.single.notes, 'Fixed a typo');
    });

    test('control: an open investment keeps both reminders', () async {
      final open = _fd();
      repository.seed(investments: [open]);

      await editNotes(open);

      expect(notifications.scheduledIncomeReminders, ['inv-fd']);
      expect(notifications.scheduledMaturityReminders, ['inv-fd']);
      expect(notifications.cancelledIncomeReminders, isEmpty);
      expect(notifications.cancelledMaturityReminders, isEmpty);
    });
  });

  group('unarchiveInvestment reminders (A17, GAP1-11)', () {
    test('unarchiving a closed investment schedules no reminders', () async {
      repository.seed(
        archivedInvestments: [
          _fd(status: InvestmentStatus.closed, isArchived: true),
        ],
      );

      await notifier.unarchiveInvestment('inv-fd');

      expect(notifications.scheduledIncomeReminders, isEmpty);
      expect(notifications.scheduledMaturityReminders, isEmpty);
      expect(repository.investments.single.isArchived, isFalse);
    });

    test('control: unarchiving an open investment schedules both', () async {
      repository.seed(archivedInvestments: [_fd(isArchived: true)]);

      await notifier.unarchiveInvestment('inv-fd');

      expect(notifications.scheduledIncomeReminders, ['inv-fd']);
      expect(notifications.scheduledMaturityReminders, ['inv-fd']);
    });
  });
}
