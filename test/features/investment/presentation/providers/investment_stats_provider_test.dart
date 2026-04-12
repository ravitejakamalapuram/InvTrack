import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_stats_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/multi_currency_providers.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/mock_investment_repository.dart';
import '../../../../mocks/mock_currency_conversion_service.dart';

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

    test(
      'should return empty stats for non-existent archived investment',
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
      },
    );

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
        currency: 'USD',
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
        currency: 'USD',
        createdAt: DateTime(2023, 1, 1),
      ),
    ];

    setUp(() async {
      fakeRepository = FakeInvestmentRepository();
      fakeRepository.seed(
        investments: [activeInvestment],
        cashFlows: activeCashFlows,
        archivedInvestments: [archivedInvestment],
        archivedCashFlows: archivedCashFlows,
      );

      // Initialize SharedPreferences for currency settings
      SharedPreferences.setMockInitialValues({'currency': 'USD'});
      final prefs = await SharedPreferences.getInstance();

      // Mock currency conversion service (no conversion needed for single currency)
      final mockConversionService = MockCurrencyConversionService();

      container = ProviderContainer(
        overrides: [
          investmentRepositoryProvider.overrideWithValue(fakeRepository),
          sharedPreferencesProvider.overrideWithValue(prefs),
          currencyConversionServiceProvider.overrideWithValue(mockConversionService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      fakeRepository.reset();
    });

    // TODO(raviteja369.k@gmail.com): Fix async stream-to-future timing issue
    // The test fails because multiCurrencyInvestmentStatsProvider watches
    // cashFlowsByInvestmentProvider.future, which needs the stream to emit first.
    // FakeInvestmentRepository uses Stream.value() which completes immediately,
    // but the .future conversion happens asynchronously in the provider.
    // Possible fixes:
    // 1. Override cashFlowsByInvestmentProvider directly in test
    // 2. Use container.listen to await provider state changes
    // 3. Modify FakeInvestmentRepository to use StreamController
    test('should use correct collection for each provider type', () async {
      // Wait for streams to emit by giving time for async operations
      await Future.delayed(const Duration(milliseconds: 100));

      // Read active stats - should calculate from active cash flows
      final activeStatsAsync = container.read(
        multiCurrencyInvestmentStatsProvider('active-inv-1'),
      );

      // Since this is a FutureProvider based on StreamProvider,
      // we need to check if it has a value after the delay
      activeStatsAsync.when(
        data: (stats) {
          expect(stats.totalInvested, 2000);
        },
        loading: () => fail('Active stats should have loaded after delay'),
        error: (e, st) => fail('Active stats errored: $e'),
      );

      // Read archived stats - should calculate from archived cash flows
      final archivedStatsAsync = container.read(
        archivedInvestmentStatsProvider('archived-inv-1'),
      );
      archivedStatsAsync.when(
        data: (stats) {
          expect(stats.totalInvested, 1000);
        },
        loading: () {}, // StreamProvider may still be loading
        error: (e, st) => fail('Archived stats errored: $e'),
      );
    }, skip: 'TODO: Fix async stream-to-future timing issue');

    // TODO(raviteja369.k@gmail.com): Fix async stream-to-future timing issue (same as above)
    test('multiCurrencyInvestmentStatsProvider should not find archived cash flows', () async {
      // Wait for streams to emit
      await Future.delayed(const Duration(milliseconds: 100));

      // Read provider (should return empty since archived cashflows aren't in active collection)
      final wrongProviderAsync = container.read(
        multiCurrencyInvestmentStatsProvider('archived-inv-1'),
      );

      // Using multiCurrencyInvestmentStatsProvider on archived investment should return empty
      wrongProviderAsync.when(
        data: (stats) {
          expect(stats.hasData, false);
          expect(stats.totalInvested, 0);
        },
        loading: () => fail('Should have loaded after delay'),
        error: (e, st) => fail('Should not error: $e'),
      );
    }, skip: 'TODO: Fix async stream-to-future timing issue');

    // TODO(raviteja369.k@gmail.com): Fix async stream-to-future timing issue (same as above)
    test(
      'archivedInvestmentStatsProvider should not find active cash flows',
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
      },
      skip: 'TODO: Fix async stream-to-future timing issue',
    );
  });

  // ignore: deprecated_member_use
  group('investmentStatsProvider (deprecated) - cash flow filter', () {
    late FakeInvestmentRepository fakeRepository;
    late ProviderContainer container;

    final baseDate = DateTime(2024, 1, 1);

    final activeInvestmentA = InvestmentEntity(
      id: 'active-a',
      name: 'Investment A',
      type: InvestmentType.stocks,
      status: InvestmentStatus.open,
      isArchived: false,
      createdAt: baseDate,
      updatedAt: baseDate,
    );

    final activeInvestmentB = InvestmentEntity(
      id: 'active-b',
      name: 'Investment B',
      type: InvestmentType.bonds,
      status: InvestmentStatus.open,
      isArchived: false,
      createdAt: baseDate,
      updatedAt: baseDate,
    );

    setUp(() {
      fakeRepository = FakeInvestmentRepository();
      container = ProviderContainer(
        overrides: [
          investmentRepositoryProvider.overrideWithValue(fakeRepository),
          isAuthenticatedProvider.overrideWithValue(true),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      fakeRepository.reset();
    });

    test('returns empty stats when no cash flows exist for the investment', () async {
      fakeRepository.seed(investments: [activeInvestmentA]);

      await Future.delayed(const Duration(milliseconds: 50));

      // ignore: deprecated_member_use
      final result = container.read(investmentStatsProvider('active-a'));

      result.when(
        data: (stats) {
          expect(stats.hasData, isFalse);
          expect(stats.totalInvested, 0);
          expect(stats.cashFlowCount, 0);
        },
        loading: () {},
        error: (e, st) => fail('Should not error: $e'),
      );
    });

    test('only includes cash flows matching the given investmentId', () async {
      fakeRepository.seed(
        investments: [activeInvestmentA, activeInvestmentB],
        cashFlows: [
          CashFlowEntity(
            id: 'cf-a1',
            investmentId: 'active-a',
            type: CashFlowType.invest,
            amount: 3000,
            date: baseDate,
            createdAt: baseDate,
          ),
          CashFlowEntity(
            id: 'cf-b1',
            investmentId: 'active-b',
            type: CashFlowType.invest,
            amount: 9999,
            date: baseDate,
            createdAt: baseDate,
          ),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      // ignore: deprecated_member_use
      final statsA = container.read(investmentStatsProvider('active-a'));
      statsA.when(
        data: (stats) {
          expect(stats.totalInvested, 3000);
          expect(stats.cashFlowCount, 1);
        },
        loading: () {},
        error: (e, st) => fail('Should not error: $e'),
      );
    });

    test('cash flows of other investments do not appear in stats', () async {
      fakeRepository.seed(
        investments: [activeInvestmentA, activeInvestmentB],
        cashFlows: [
          CashFlowEntity(
            id: 'cf-b1',
            investmentId: 'active-b',
            type: CashFlowType.invest,
            amount: 5000,
            date: baseDate,
            createdAt: baseDate,
          ),
          CashFlowEntity(
            id: 'cf-b2',
            investmentId: 'active-b',
            type: CashFlowType.returnFlow,
            amount: 6000,
            date: baseDate,
            createdAt: baseDate,
          ),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      // Reading stats for investment A (which has no cash flows)
      // ignore: deprecated_member_use
      final statsA = container.read(investmentStatsProvider('active-a'));
      statsA.when(
        data: (stats) {
          // Investment A has no cash flows; B's cash flows must not bleed in
          expect(stats.hasData, isFalse);
          expect(stats.totalInvested, 0);
          expect(stats.totalReturned, 0);
        },
        loading: () {},
        error: (e, st) => fail('Should not error: $e'),
      );
    });

    test('includes all cash flow types for the matching investmentId', () async {
      fakeRepository.seed(
        investments: [activeInvestmentA],
        cashFlows: [
          CashFlowEntity(
            id: 'cf-1',
            investmentId: 'active-a',
            type: CashFlowType.invest,
            amount: 1000,
            date: baseDate,
            createdAt: baseDate,
          ),
          CashFlowEntity(
            id: 'cf-2',
            investmentId: 'active-a',
            type: CashFlowType.fee,
            amount: 50,
            date: baseDate,
            createdAt: baseDate,
          ),
          CashFlowEntity(
            id: 'cf-3',
            investmentId: 'active-a',
            type: CashFlowType.income,
            amount: 100,
            date: baseDate,
            createdAt: baseDate,
          ),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      // ignore: deprecated_member_use
      final result = container.read(investmentStatsProvider('active-a'));
      result.when(
        data: (stats) {
          expect(stats.cashFlowCount, 3);
          expect(stats.totalInvested, 1050); // invest + fee
          expect(stats.totalReturned, 100); // income
        },
        loading: () {},
        error: (e, st) => fail('Should not error: $e'),
      );
    });

    test('returns empty stats for an unknown investmentId', () async {
      fakeRepository.seed(
        investments: [activeInvestmentA],
        cashFlows: [
          CashFlowEntity(
            id: 'cf-a1',
            investmentId: 'active-a',
            type: CashFlowType.invest,
            amount: 1000,
            date: baseDate,
            createdAt: baseDate,
          ),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      // ignore: deprecated_member_use
      final result = container.read(investmentStatsProvider('does-not-exist'));
      result.when(
        data: (stats) {
          expect(stats.hasData, isFalse);
          expect(stats.totalInvested, 0);
        },
        loading: () {},
        error: (e, st) => fail('Should not error: $e'),
      );
    });
  });
}