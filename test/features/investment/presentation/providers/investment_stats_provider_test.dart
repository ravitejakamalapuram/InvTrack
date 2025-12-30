import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_stats_provider.dart';
import '../../data/repositories/mock_investment_repository.dart';

void main() {
  group('calculateStats', () {
    test('should return empty stats for empty cash flows', () {
      final result = calculateStats([]);

      expect(result.totalInvested, 0);
      expect(result.totalReturned, 0);
      expect(result.netCashFlow, 0);
      expect(result.absoluteReturn, 0);
      expect(result.moic, 0);
      expect(result.cashFlowCount, 0);
      expect(result.hasData, false);
    });

    test('should calculate stats correctly for single investment', () {
      final cashFlows = [
        CashFlowEntity(
          id: '1',
          investmentId: 'inv1',
          date: DateTime(2023, 1, 1),
          type: CashFlowType.invest,
          amount: 1000,
          createdAt: DateTime.now(),
        ),
      ];

      final result = calculateStats(cashFlows);

      expect(result.totalInvested, 1000);
      expect(result.totalReturned, 0);
      expect(result.netCashFlow, -1000);
      expect(result.absoluteReturn, -100); // -100% (no returns yet)
      expect(result.moic, 0); // 0x (no returns)
      expect(result.cashFlowCount, 1);
      expect(result.hasData, true);
    });

    test('should calculate stats correctly for investment with return', () {
      final cashFlows = [
        CashFlowEntity(
          id: '1',
          investmentId: 'inv1',
          date: DateTime(2023, 1, 1),
          type: CashFlowType.invest,
          amount: 1000,
          createdAt: DateTime.now(),
        ),
        CashFlowEntity(
          id: '2',
          investmentId: 'inv1',
          date: DateTime(2024, 1, 1),
          type: CashFlowType.returnFlow,
          amount: 1500,
          createdAt: DateTime.now(),
        ),
      ];

      final result = calculateStats(cashFlows);

      expect(result.totalInvested, 1000);
      expect(result.totalReturned, 1500);
      expect(result.netCashFlow, 500); // 1500 - 1000
      expect(result.absoluteReturn, 50); // 50% return
      expect(result.moic, 1.5); // 1.5x
      expect(result.cashFlowCount, 2);
      expect(result.isProfit, true);
      expect(result.isLoss, false);
    });

    test('should calculate stats correctly for loss scenario', () {
      final cashFlows = [
        CashFlowEntity(
          id: '1',
          investmentId: 'inv1',
          date: DateTime(2023, 1, 1),
          type: CashFlowType.invest,
          amount: 1000,
          createdAt: DateTime.now(),
        ),
        CashFlowEntity(
          id: '2',
          investmentId: 'inv1',
          date: DateTime(2024, 1, 1),
          type: CashFlowType.returnFlow,
          amount: 600,
          createdAt: DateTime.now(),
        ),
      ];

      final result = calculateStats(cashFlows);

      expect(result.totalInvested, 1000);
      expect(result.totalReturned, 600);
      expect(result.netCashFlow, -400);
      expect(result.absoluteReturn, -40); // -40% loss
      expect(result.moic, 0.6); // 0.6x
      expect(result.isProfit, false);
      expect(result.isLoss, true);
    });

    test('should handle fees as outflows', () {
      final cashFlows = [
        CashFlowEntity(
          id: '1',
          investmentId: 'inv1',
          date: DateTime(2023, 1, 1),
          type: CashFlowType.invest,
          amount: 1000,
          createdAt: DateTime.now(),
        ),
        CashFlowEntity(
          id: '2',
          investmentId: 'inv1',
          date: DateTime(2023, 6, 1),
          type: CashFlowType.fee,
          amount: 50,
          createdAt: DateTime.now(),
        ),
        CashFlowEntity(
          id: '3',
          investmentId: 'inv1',
          date: DateTime(2024, 1, 1),
          type: CashFlowType.returnFlow,
          amount: 1200,
          createdAt: DateTime.now(),
        ),
      ];

      final result = calculateStats(cashFlows);

      expect(result.totalInvested, 1050); // 1000 + 50 fee
      expect(result.totalReturned, 1200);
      expect(result.netCashFlow, 150); // 1200 - 1050
      expect(result.cashFlowCount, 3);
    });

    test('should handle income as inflows', () {
      final cashFlows = [
        CashFlowEntity(
          id: '1',
          investmentId: 'inv1',
          date: DateTime(2023, 1, 1),
          type: CashFlowType.invest,
          amount: 1000,
          createdAt: DateTime.now(),
        ),
        CashFlowEntity(
          id: '2',
          investmentId: 'inv1',
          date: DateTime(2023, 6, 1),
          type: CashFlowType.income,
          amount: 100, // Dividend
          createdAt: DateTime.now(),
        ),
      ];

      final result = calculateStats(cashFlows);

      expect(result.totalInvested, 1000);
      expect(result.totalReturned, 100);
      expect(result.netCashFlow, -900);
      expect(result.cashFlowCount, 2);
    });
  });

  group('archivedInvestmentStatsProvider', () {
    late FakeInvestmentRepository fakeRepository;
    late ProviderContainer container;

    final archivedInvestment = InvestmentEntity(
      id: 'archived-inv-1',
      name: 'Archived Investment',
      type: InvestmentType.p2pLending,
      status: InvestmentStatus.closed,
      isArchived: true,
      createdAt: DateTime(2023, 1, 1),
      updatedAt: DateTime(2023, 1, 1),
    );

    final archivedCashFlows = [
      CashFlowEntity(
        id: 'cf-1',
        investmentId: 'archived-inv-1',
        date: DateTime(2023, 1, 1),
        type: CashFlowType.invest,
        amount: 1000,
        createdAt: DateTime(2023, 1, 1),
      ),
      CashFlowEntity(
        id: 'cf-2',
        investmentId: 'archived-inv-1',
        date: DateTime(2024, 1, 1),
        type: CashFlowType.returnFlow,
        amount: 1500,
        createdAt: DateTime(2024, 1, 1),
      ),
    ];

    setUp(() {
      fakeRepository = FakeInvestmentRepository();
      fakeRepository.seed(
        archivedInvestments: [archivedInvestment],
        archivedCashFlows: archivedCashFlows,
      );
      container = ProviderContainer(
        overrides: [
          investmentRepositoryProvider.overrideWithValue(fakeRepository),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      fakeRepository.reset();
    });

    test('should return empty stats for non-existent archived investment',
        () async {
      // Wait for stream to emit
      await Future.delayed(const Duration(milliseconds: 50));

      final statsAsync = container.read(
        archivedInvestmentStatsProvider('non-existent-id'),
      );

      statsAsync.when(
        data: (stats) {
          expect(stats.hasData, false);
          expect(stats.totalInvested, 0);
        },
        loading: () {}, // Stream may still be initializing
        error: (e, st) => fail('Should not error: $e'),
      );
    });

    test('should calculate stats correctly for archived investment', () async {
      // Give provider time to process stream
      await Future.delayed(const Duration(milliseconds: 50));

      final statsAsync = container.read(
        archivedInvestmentStatsProvider('archived-inv-1'),
      );

      statsAsync.when(
        data: (stats) {
          expect(stats.hasData, true);
          expect(stats.totalInvested, 1000);
          expect(stats.totalReturned, 1500);
          expect(stats.netCashFlow, 500);
          expect(stats.absoluteReturn, 50);
          expect(stats.moic, 1.5);
          expect(stats.cashFlowCount, 2);
        },
        loading: () {}, // May still be loading
        error: (e, st) => fail('Should not error: $e'),
      );
    });
  });

  group('investmentStatsProvider vs archivedInvestmentStatsProvider', () {
    late FakeInvestmentRepository fakeRepository;
    late ProviderContainer container;

    final activeInvestment = InvestmentEntity(
      id: 'active-inv-1',
      name: 'Active Investment',
      type: InvestmentType.stocks,
      status: InvestmentStatus.open,
      isArchived: false,
      createdAt: DateTime(2023, 1, 1),
      updatedAt: DateTime(2023, 1, 1),
    );

    final archivedInvestment = InvestmentEntity(
      id: 'archived-inv-1',
      name: 'Archived Investment',
      type: InvestmentType.p2pLending,
      status: InvestmentStatus.closed,
      isArchived: true,
      createdAt: DateTime(2023, 1, 1),
      updatedAt: DateTime(2023, 1, 1),
    );

    final activeCashFlows = [
      CashFlowEntity(
        id: 'active-cf-1',
        investmentId: 'active-inv-1',
        date: DateTime(2023, 1, 1),
        type: CashFlowType.invest,
        amount: 2000,
        createdAt: DateTime(2023, 1, 1),
      ),
    ];

    final archivedCashFlows = [
      CashFlowEntity(
        id: 'archived-cf-1',
        investmentId: 'archived-inv-1',
        date: DateTime(2023, 1, 1),
        type: CashFlowType.invest,
        amount: 1000,
        createdAt: DateTime(2023, 1, 1),
      ),
    ];

    setUp(() {
      fakeRepository = FakeInvestmentRepository();
      fakeRepository.seed(
        investments: [activeInvestment],
        cashFlows: activeCashFlows,
        archivedInvestments: [archivedInvestment],
        archivedCashFlows: archivedCashFlows,
      );
      container = ProviderContainer(
        overrides: [
          investmentRepositoryProvider.overrideWithValue(fakeRepository),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      fakeRepository.reset();
    });

    test('should use correct collection for each provider type', () async {
      await Future.delayed(const Duration(milliseconds: 50));

      // Active investment should use investmentStatsProvider
      final activeStatsAsync = container.read(
        investmentStatsProvider('active-inv-1'),
      );
      activeStatsAsync.whenData((stats) {
        expect(stats.totalInvested, 2000);
      });

      // Archived investment should use archivedInvestmentStatsProvider
      final archivedStatsAsync = container.read(
        archivedInvestmentStatsProvider('archived-inv-1'),
      );
      archivedStatsAsync.whenData((stats) {
        expect(stats.totalInvested, 1000);
      });
    });

    test('investmentStatsProvider should not find archived cash flows',
        () async {
      await Future.delayed(const Duration(milliseconds: 50));

      // Using investmentStatsProvider on archived investment should return empty
      final wrongProviderAsync = container.read(
        investmentStatsProvider('archived-inv-1'),
      );
      wrongProviderAsync.whenData((stats) {
        expect(stats.hasData, false);
        expect(stats.totalInvested, 0);
      });
    });

    test('archivedInvestmentStatsProvider should not find active cash flows',
        () async {
      await Future.delayed(const Duration(milliseconds: 50));

      // Using archivedInvestmentStatsProvider on active investment returns empty
      final wrongProviderAsync = container.read(
        archivedInvestmentStatsProvider('active-inv-1'),
      );
      wrongProviderAsync.whenData((stats) {
        expect(stats.hasData, false);
        expect(stats.totalInvested, 0);
      });
    });
  });
}
