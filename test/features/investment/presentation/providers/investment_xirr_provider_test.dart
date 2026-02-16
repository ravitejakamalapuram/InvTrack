import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
        type: CashFlowType.returnFlow, // Using returnFlow to represent exit/valuation
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

    setUp(() {
      container = ProviderContainer(
        overrides: [
          // Override validCashFlowsProvider directly to bypass repository and streams
          validCashFlowsProvider.overrideWithValue(
             AsyncValue.data([...cashFlows1, ...cashFlows2])
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
        expect(xirr1, closeTo(0.5, 0.001));

        // Read XIRR for Investment 2
        final xirr2 = await container.read(
          investmentXirrProvider('inv2').future,
        );

        // Expected: 10% = 0.1
        expect(xirr2, closeTo(0.1, 0.001));
      },
    );

    test('should return 0.0 for investment with no cash flows', () async {
      await Future.delayed(const Duration(milliseconds: 100));

      // ID that doesn't exist in cash flows
      final xirr3 = await container.read(
        investmentXirrProvider('inv-non-existent').future,
      );
      expect(xirr3, 0.0);
    });

    test('should return 0.0 for investment with empty cash flows in bulk', () async {
      final xirr3 = await container.read(
        investmentXirrProvider('inv3').future,
      );
      expect(xirr3, 0.0);
    });
  });
}
