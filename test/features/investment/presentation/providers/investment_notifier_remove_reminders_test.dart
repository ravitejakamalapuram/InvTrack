// A23 / INV-07: bulk-deleting or merging investments removes them, so their
// income and maturity reminders must be cancelled too; before, only a single
// delete did, and "FD X matures in 7 days" kept firing for gone investments.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_notifier.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';

import '../../../../mocks/mock_analytics_service.dart';
import '../../../../mocks/mock_notification_service.dart';
import '../../data/repositories/mock_investment_repository.dart';

InvestmentEntity _fd(String id) => InvestmentEntity(
  id: id,
  name: 'FD $id',
  type: InvestmentType.fixedDeposit,
  status: InvestmentStatus.open,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  maturityDate: DateTime(2027, 1, 1),
  incomeFrequency: IncomeFrequency.monthly,
  startDate: DateTime(2026, 1, 1),
  currency: 'INR',
);

/// Fails the deletes it is told to, so reminders of survivors can be checked.
class _FailingRepository extends FakeInvestmentRepository {
  Set<String> failDeleteOf = {};
  bool failBulkDelete = false;

  @override
  Future<void> deleteInvestment(String id) async {
    if (failDeleteOf.contains(id)) throw Exception('delete failed');
    return super.deleteInvestment(id);
  }

  @override
  Future<int> bulkDelete(List<String> investmentIds) async {
    if (failBulkDelete) throw Exception('bulk delete failed');
    return super.bulkDelete(investmentIds);
  }
}

void main() {
  late _FailingRepository repo;
  late FakeNotificationService notifications;
  late ProviderContainer container;

  setUp(() async {
    repo = _FailingRepository();
    notifications = FakeNotificationService();
    container = ProviderContainer(
      overrides: [
        investmentRepositoryProvider.overrideWithValue(repo),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        notificationServiceProvider.overrideWithValue(notifications),
        isAuthenticatedProvider.overrideWithValue(true),
        currencyCodeProvider.overrideWithValue('INR'),
      ],
    );
    for (final id in ['a', 'b', 'c']) {
      await repo.createInvestment(_fd(id));
    }
  });

  tearDown(() {
    container.dispose();
    repo.reset();
  });

  InvestmentNotifier notifier() =>
      container.read(investmentNotifierProvider.notifier);

  group('bulkDelete', () {
    test(
      'bulkDelete cancels the income and maturity reminders of each',
      () async {
        await notifier().bulkDelete(['a', 'b']);

        expect(notifications.cancelledIncomeReminders, containsAll(['a', 'b']));
        expect(
          notifications.cancelledMaturityReminders,
          containsAll(['a', 'b']),
        );
        expect(notifications.cancelledIncomeReminders, isNot(contains('c')));
        expect(notifications.cancelledMaturityReminders, isNot(contains('c')));
      },
    );

    test('a failed bulkDelete keeps every reminder', () async {
      repo.failBulkDelete = true;

      await expectLater(notifier().bulkDelete(['a', 'b']), throwsException);

      expect(notifications.cancelledIncomeReminders, isEmpty);
      expect(notifications.cancelledMaturityReminders, isEmpty);
    });
  });

  group('mergeInvestments', () {
    test(
      'mergeInvestments cancels the reminders of the merged sources',
      () async {
        // The app always has a screen listening to the investments stream.
        container.listen(allInvestmentsProvider, (_, _) {});
        await container.read(allInvestmentsProvider.future);

        await notifier().mergeInvestments(['a', 'b'], 'Merged FD');

        expect(notifications.cancelledIncomeReminders, containsAll(['a', 'b']));
        expect(
          notifications.cancelledMaturityReminders,
          containsAll(['a', 'b']),
        );
        expect(notifications.cancelledIncomeReminders, isNot(contains('c')));
      },
    );

    test('a merge that fails on one source cancels only the sources already '
        'deleted', () async {
      container.listen(allInvestmentsProvider, (_, _) {});
      await container.read(allInvestmentsProvider.future);
      repo.failDeleteOf = {'b'};

      await expectLater(
        notifier().mergeInvestments(['a', 'b'], 'Merged FD'),
        throwsException,
      );

      expect(notifications.cancelledIncomeReminders, ['a']);
      expect(notifications.cancelledMaturityReminders, ['a']);
    });
  });
}
