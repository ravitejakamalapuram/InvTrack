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

void main() {
  late FakeInvestmentRepository repo;
  late FakeNotificationService notifications;
  late ProviderContainer container;

  setUp(() async {
    repo = FakeInvestmentRepository();
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

  test(
    'bulkDelete cancels the income and maturity reminders of each',
    () async {
      await notifier().bulkDelete(['a', 'b']);

      expect(notifications.cancelledIncomeReminders, containsAll(['a', 'b']));
      expect(notifications.cancelledMaturityReminders, containsAll(['a', 'b']));
      expect(notifications.cancelledIncomeReminders, isNot(contains('c')));
      expect(notifications.cancelledMaturityReminders, isNot(contains('c')));
    },
  );

  test(
    'mergeInvestments cancels the reminders of the merged sources',
    () async {
      // The app always has a screen listening to the investments stream.
      container.listen(allInvestmentsProvider, (_, _) {});
      await container.read(allInvestmentsProvider.future);

      await notifier().mergeInvestments(['a', 'b'], 'Merged FD');

      expect(notifications.cancelledIncomeReminders, containsAll(['a', 'b']));
      expect(notifications.cancelledMaturityReminders, containsAll(['a', 'b']));
      expect(notifications.cancelledIncomeReminders, isNot(contains('c')));
    },
  );
}
