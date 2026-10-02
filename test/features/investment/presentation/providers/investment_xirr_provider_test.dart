import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_stats_provider.dart';

void main() {
  group('investmentXirrProvider (Bulk Calculation)', () {
    late ProviderContainer container;

    // Investment 1: +50% return over 1 year
    final cashFlows1 = [
      CashFlowEntity(
        id: 'cf1-1',
        investmentId: 'inv1',
        date: DateTime(2023, 1, 1),
        type: CashFlowType.invest,
        amount: 1000,
        createdAt: DateTime(2023, 1, 1),
      ),
      CashFlowEntity(
        id: 'cf1-2',
        investmentId: 'inv1',
        date: DateTime(2024, 1, 1),
        type: CashFlowType
            .returnFlow, // Using returnFlow to represent exit/valuation
        amount: 1500,
        createdAt: DateTime(2024, 1, 1),
      ),
    ];

    // Investment 2: +10% return over 1 year
    final cashFlows2 = [
      CashFlowEntity(
        id: 'cf2-1',
        investmentId: 'inv2',
        date: DateTime(2023, 1, 1),
        type: CashFlowType.invest,
        amount: 1000,
        createdAt: DateTime(2023, 1, 1),
      ),
      CashFlowEntity(
        id: 'cf2-2',
        investmentId: 'inv2',
        date: DateTime(2024, 1, 1),
        type: CashFlowType.returnFlow,
        amount: 1100,
        createdAt: DateTime(2024, 1, 1),
      ),
    ];

    // Investment 4: +2% in 3 days, which annualises above the solver's search
    // range, so the rate comes from the approximate fallback.
    final cashFlows4 = [
      CashFlowEntity(
        id: 'cf4-1',
        investmentId: 'inv4',
        date: DateTime(2026, 1, 1),
        type: CashFlowType.invest,
        amount: 100000,
        createdAt: DateTime(2026, 1, 1),
      ),
      CashFlowEntity(
        id: 'cf4-2',
        investmentId: 'inv4',
        date: DateTime(2026, 1, 4),
        type: CashFlowType.returnFlow,
        amount: 102000,
        createdAt: DateTime(2026, 1, 4),
      ),
    ];

    setUp(() {
      container = ProviderContainer(
        overrides: [
          // Override validCashFlowsProvider directly to bypass repository and streams
          validCashFlowsProvider.overrideWithValue(
            AsyncValue.data([...cashFlows1, ...cashFlows2, ...cashFlows4]),
          ),
          isAuthenticatedProvider.overrideWith((ref) => true),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'should calculate XIRR for multiple investments via bulk provider',
      () async {
        // Allow providers to initialize (compute is async)
        await Future.delayed(const Duration(milliseconds: 100));

        // Read XIRR for Investment 1
        final xirr1 = await container.read(
          investmentXirrProvider('inv1').future,
        );

        // Expected: 50% = 0.5
        expect(xirr1.value, closeTo(0.5, 0.001));
        expect(xirr1.method, XirrMethod.exact);

        // Read XIRR for Investment 2
        final xirr2 = await container.read(
          investmentXirrProvider('inv2').future,
        );

        // Expected: 10% = 0.1
        expect(xirr2.value, closeTo(0.1, 0.001));
        expect(xirr2.method, XirrMethod.exact);
      },
    );

    test('flags an approximate XIRR as approximate', () async {
      final xirr4 = await container.read(investmentXirrProvider('inv4').future);

      expect(xirr4.method, XirrMethod.approximate);
      expect(xirr4.value, closeTo(10.126388779444367, 1e-6));
    });

    test('active XIRR number map keeps the bare values', () async {
      final map = await container.read(activeInvestmentXirrMapProvider.future);

      expect(map['inv1'], closeTo(0.5, 0.001));
      expect(map['inv4'], closeTo(10.126388779444367, 1e-6));
    });

    test('is undefined for investment with no cash flows', () async {
      await Future.delayed(const Duration(milliseconds: 100));

      // ID that doesn't exist in cash flows
      final xirr3 = await container.read(
        investmentXirrProvider('inv-non-existent').future,
      );
      expect(xirr3.method, XirrMethod.undefined);
      expect(xirr3.value, isNull);
    });

    test('is undefined for investment with empty cash flows in bulk', () async {
      final xirr3 = await container.read(investmentXirrProvider('inv3').future);
      expect(xirr3.method, XirrMethod.undefined);
    });
  });
}
