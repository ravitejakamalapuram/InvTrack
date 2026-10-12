// A117 (#891): editing a closed or archived investment must not bring back
// its income and maturity reminders; only an open, active investment has
// them. A17 (#762, GAP1-11): the same holds when a closed investment is
// unarchived, and when an archived one is reopened.
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
  InterestPayoutMode? payoutMode,
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
  interestPayoutMode: payoutMode,
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
    interestPayoutMode: from.interestPayoutMode,
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

  group('reopenInvestment reminders', () {
    // The fake, like an offline write, leaves the archived investment
    // closed; reopening must still not schedule for it.
    test('reopening an archived investment schedules no reminders', () async {
      repository.seed(
        archivedInvestments: [
          _fd(status: InvestmentStatus.closed, isArchived: true),
        ],
      );

      await notifier.reopenInvestment('inv-fd');

      expect(notifications.scheduledIncomeReminders, isEmpty);
      expect(notifications.scheduledMaturityReminders, isEmpty);
    });

    test('control: reopening a closed investment schedules both', () async {
      repository.seed(investments: [_fd(status: InvestmentStatus.closed)]);

      await notifier.reopenInvestment('inv-fd');

      expect(notifications.scheduledIncomeReminders, ['inv-fd']);
      expect(notifications.scheduledMaturityReminders, ['inv-fd']);
      expect(repository.investments.single.isOpen, isTrue);
    });
  });

  // #1001: the FD template is cumulative but carries a quarterly income
  // frequency; a payout mode that pays nothing before maturity means no
  // income reminder, on create, edit, unarchive and reopen alike.
  group('income reminders follow the payout mode (#1001)', () {
    Future<void> addFd(InterestPayoutMode? mode) => notifier.addInvestment(
      name: 'Bank FD',
      type: InvestmentType.fixedDeposit,
      incomeFrequency: IncomeFrequency.quarterly,
      interestPayoutMode: mode,
      startDate: DateTime(2026, 3, 10),
      currency: 'INR',
    );

    test(
      'creating a cumulative FD with a quarterly frequency schedules no income reminder',
      () async {
        await addFd(InterestPayoutMode.cumulative);
        await Future<void>.delayed(Duration.zero);

        expect(notifications.scheduledIncomeReminders, isEmpty);
      },
    );

    test(
      'a retried create with the same id cancels a reminder left by the record it replaces',
      () async {
        await notifier.addInvestment(
          id: 'inv-retry',
          name: 'Bank FD',
          type: InvestmentType.fixedDeposit,
          incomeFrequency: IncomeFrequency.quarterly,
          interestPayoutMode: InterestPayoutMode.cumulative,
          startDate: DateTime(2026, 3, 10),
          currency: 'INR',
        );
        await Future<void>.delayed(Duration.zero);

        expect(notifications.scheduledIncomeReminders, isEmpty);
        expect(notifications.cancelledIncomeReminders, ['inv-retry']);
      },
    );

    test('creating an at-maturity FD schedules no income reminder', () async {
      await addFd(InterestPayoutMode.atMaturity);
      await Future<void>.delayed(Duration.zero);

      expect(notifications.scheduledIncomeReminders, isEmpty);
    });

    test(
      'control: creating a periodic FD schedules its income reminder',
      () async {
        await addFd(InterestPayoutMode.periodic);
        await Future<void>.delayed(Duration.zero);

        expect(notifications.scheduledIncomeReminders, hasLength(1));
      },
    );

    test(
      'editing a cumulative FD schedules no income reminder and cancels any pending one',
      () async {
        final cumulative = _fd(payoutMode: InterestPayoutMode.cumulative);
        repository.seed(investments: [cumulative]);

        await editNotes(cumulative);

        expect(notifications.scheduledIncomeReminders, isEmpty);
        expect(notifications.cancelledIncomeReminders, ['inv-fd']);
        expect(notifications.scheduledMaturityReminders, ['inv-fd']);
      },
    );

    test('unarchiving a cumulative FD schedules no income reminder', () async {
      repository.seed(
        archivedInvestments: [
          _fd(isArchived: true, payoutMode: InterestPayoutMode.cumulative),
        ],
      );

      await notifier.unarchiveInvestment('inv-fd');

      expect(notifications.scheduledIncomeReminders, isEmpty);
    });

    test('control: editing a periodic FD keeps its income reminder', () async {
      final periodic = _fd(payoutMode: InterestPayoutMode.periodic);
      repository.seed(investments: [periodic]);

      await editNotes(periodic);

      expect(notifications.scheduledIncomeReminders, ['inv-fd']);
    });
  });
}
