import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_notifier.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import '../../data/repositories/mock_investment_repository.dart';
import '../../../../mocks/mock_analytics_service.dart';
import '../../../../mocks/mock_notification_service.dart';

/// A missing currency must become the user's base currency (INR here), never
/// USD; otherwise INR amounts are converted as dollars (about 88x too high).
void main() {
  late FakeInvestmentRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeInvestmentRepository();
    container = ProviderContainer(
      overrides: [
        investmentRepositoryProvider.overrideWithValue(repo),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        isAuthenticatedProvider.overrideWithValue(true),
        currencyCodeProvider.overrideWithValue('INR'),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    repo.reset();
  });

  InvestmentNotifier notifier() =>
      container.read(investmentNotifierProvider.notifier);

  group('missing currency falls back to the base currency', () {
    test('addInvestment without a currency uses the base currency', () async {
      final inv = await notifier().addInvestment(
        name: 'HDFC FD',
        type: InvestmentType.fixedDeposit,
      );

      expect(inv.currency, 'INR');
      expect(repo.investments.single.currency, 'INR');
    });

    test('addCashFlow without a currency uses the base currency', () async {
      await notifier().addCashFlow(
        investmentId: 'inv-1',
        type: CashFlowType.invest,
        amount: 100000,
        date: DateTime(2024, 1, 15),
      );

      expect(repo.cashFlows.single.currency, 'INR');
    });

    test('addCashFlow rounds using the selected currency precision', () async {
      await notifier().addCashFlow(
        investmentId: 'inv-1',
        type: CashFlowType.income,
        amount: 1.005,
        date: DateTime(2024, 1, 15),
        currency: 'INR',
      );

      expect(repo.cashFlows.single.amount, 1.01);
    });

    test('updateCashFlow without a currency uses the base currency', () async {
      await repo.addCashFlow(
        CashFlowEntity(
          id: 'cf-1',
          investmentId: 'inv-1',
          type: CashFlowType.invest,
          amount: 50000,
          date: DateTime(2024, 1, 15),
          createdAt: DateTime(2024, 1, 15),
          currency: 'INR',
        ),
      );

      await notifier().updateCashFlow(
        id: 'cf-1',
        investmentId: 'inv-1',
        type: CashFlowType.invest,
        amount: 100000,
        date: DateTime(2024, 1, 15),
        createdAt: DateTime(2024, 1, 15),
      );

      expect(repo.cashFlows.single.currency, 'INR');
    });
  });

    test('updateCashFlow rounds zero-decimal currencies to whole units', () async {
      await repo.addCashFlow(
        CashFlowEntity(
          id: 'jpy-flow',
          investmentId: 'inv-1',
          type: CashFlowType.income,
          amount: 100,
          date: DateTime(2024, 1, 15),
          createdAt: DateTime(2024, 1, 15),
          currency: 'JPY',
        ),
      );

      await notifier().updateCashFlow(
        id: 'jpy-flow',
        investmentId: 'inv-1',
        type: CashFlowType.income,
        amount: 125.6,
        date: DateTime(2024, 1, 15),
        createdAt: DateTime(2024, 1, 15),
        currency: 'JPY',
      );

      expect(repo.cashFlows.single.amount, 126);
      expect(repo.cashFlows.single.currency, 'JPY');
    });

  group('mergeInvestments', () {
    Future<void> merge(List<String> ids, String name) {
      // The app always has a screen listening to the investments stream;
      // mirror that (after seeding) so mergeInvestments can read it.
      container.listen(allInvestmentsProvider, (_, _) {});
      return notifier().mergeInvestments(ids, name);
    }

    Future<void> seed({
      required String id,
      required String currency,
      required List<double> amounts,
      DateTime? startDate,
      DateTime? maturityDate,
    }) async {
      await repo.createInvestment(
        InvestmentEntity(
          id: id,
          name: 'FD $id',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
          currency: currency,
          startDate: startDate,
          maturityDate: maturityDate,
          expectedRate: 7.1,
          incomeFrequency: IncomeFrequency.quarterly,
          platform: 'HDFC Bank',
        ),
      );
      for (var i = 0; i < amounts.length; i++) {
        await repo.addCashFlow(
          CashFlowEntity(
            id: '$id-cf-$i',
            investmentId: id,
            type: CashFlowType.invest,
            amount: amounts[i],
            date: DateTime(2024, 1, 15 + i),
            createdAt: DateTime(2024, 1, 15),
            currency: currency,
          ),
        );
      }
    }

    test(
      'merging two INR investments keeps currency, sum and metadata',
      () async {
        await seed(
          id: 'a',
          currency: 'INR',
          amounts: [500000],
          startDate: DateTime(2024, 1, 15),
          maturityDate: DateTime(2026, 1, 15),
        );
        await seed(
          id: 'b',
          currency: 'INR',
          amounts: [300000],
          startDate: DateTime(2023, 6, 1),
          maturityDate: DateTime(2027, 3, 1),
        );

        await merge(['a', 'b'], 'Merged FDs');

        final merged = repo.investments.single;
        expect(merged.name, 'Merged FDs');
        expect(merged.currency, 'INR');
        expect(merged.startDate, DateTime(2023, 6, 1));
        expect(merged.maturityDate, DateTime(2027, 3, 1));
        expect(merged.expectedRate, 7.1);
        expect(merged.incomeFrequency, IncomeFrequency.quarterly);
        expect(merged.platform, 'HDFC Bank');

        final flows = repo.cashFlows;
        expect(flows, hasLength(2));
        expect(flows.every((cf) => cf.investmentId == merged.id), isTrue);
        expect(flows.map((cf) => cf.currency).toSet(), {'INR'});
        expect(flows.fold<double>(0, (sum, cf) => sum + cf.amount), 800000.0);
      },
    );

    test('merging mixed currencies keeps each flow currency', () async {
      await seed(id: 'usd', currency: 'USD', amounts: [1000]);
      await seed(id: 'inr', currency: 'INR', amounts: [100000]);

      await merge(['usd', 'inr'], 'Mixed');

      final merged = repo.investments.single;
      // Sources disagree, so the merged investment uses the base currency
      expect(merged.currency, 'INR');
      final byAmount = {
        for (final cf in repo.cashFlows) cf.amount: cf.currency,
      };
      expect(byAmount, {1000.0: 'USD', 100000.0: 'INR'});
    });
  });
}
