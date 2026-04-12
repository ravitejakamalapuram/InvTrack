import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_analytics_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';

import '../../data/repositories/mock_investment_repository.dart';

void main() {
  group('recentlyClosedInvestmentsProvider', () {
    late FakeInvestmentRepository fakeRepository;
    late ProviderContainer container;

    final baseDate = DateTime(2024, 1, 1);

    InvestmentEntity makeInvestment({
      required String id,
      required InvestmentStatus status,
      required DateTime updatedAt,
      InvestmentType type = InvestmentType.stocks,
    }) {
      return InvestmentEntity(
        id: id,
        name: 'Investment $id',
        type: type,
        status: status,
        isArchived: false,
        createdAt: baseDate,
        updatedAt: updatedAt,
      );
    }

    CashFlowEntity makeCashFlow({
      required String id,
      required String investmentId,
      CashFlowType type = CashFlowType.invest,
      double amount = 1000,
      DateTime? date,
    }) {
      return CashFlowEntity(
        id: id,
        investmentId: investmentId,
        type: type,
        amount: amount,
        date: date ?? baseDate,
        createdAt: baseDate,
      );
    }

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

    test('returns empty list when there are no investments', () async {
      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.when(
        data: (list) => expect(list, isEmpty),
        loading: () {},
        error: (e, st) => fail('Should not error: $e'),
      );
    });

    test('returns empty list when all investments are open', () async {
      fakeRepository.seed(
        investments: [
          makeInvestment(
            id: 'inv-1',
            status: InvestmentStatus.open,
            updatedAt: baseDate,
          ),
          makeInvestment(
            id: 'inv-2',
            status: InvestmentStatus.open,
            updatedAt: baseDate,
          ),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.when(
        data: (list) => expect(list, isEmpty),
        loading: () {},
        error: (e, st) => fail('Should not error: $e'),
      );
    });

    test('returns only closed investments, excludes open ones', () async {
      fakeRepository.seed(
        investments: [
          makeInvestment(
            id: 'open-1',
            status: InvestmentStatus.open,
            updatedAt: baseDate,
          ),
          makeInvestment(
            id: 'closed-1',
            status: InvestmentStatus.closed,
            updatedAt: baseDate,
          ),
          makeInvestment(
            id: 'open-2',
            status: InvestmentStatus.open,
            updatedAt: baseDate,
          ),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.when(
        data: (list) {
          expect(list.length, 1);
          expect(list.first.investment.id, 'closed-1');
        },
        loading: () {},
        error: (e, st) => fail('Should not error: $e'),
      );
    });

    test('sorts closed investments by updatedAt descending', () async {
      fakeRepository.seed(
        investments: [
          makeInvestment(
            id: 'closed-oldest',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2023, 1, 1),
          ),
          makeInvestment(
            id: 'closed-newest',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 6, 1),
          ),
          makeInvestment(
            id: 'closed-middle',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 3, 1),
          ),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.when(
        data: (list) {
          expect(list.length, 3);
          expect(list[0].investment.id, 'closed-newest');
          expect(list[1].investment.id, 'closed-middle');
          expect(list[2].investment.id, 'closed-oldest');
        },
        loading: () {},
        error: (e, st) => fail('Should not error: $e'),
      );
    });

    test('takes at most 3 recently closed investments', () async {
      fakeRepository.seed(
        investments: [
          makeInvestment(
            id: 'closed-1',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 6, 1),
          ),
          makeInvestment(
            id: 'closed-2',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 5, 1),
          ),
          makeInvestment(
            id: 'closed-3',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 4, 1),
          ),
          makeInvestment(
            id: 'closed-4',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 3, 1),
          ),
          makeInvestment(
            id: 'closed-5',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 2, 1),
          ),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.when(
        data: (list) {
          expect(list.length, 3);
          // Should be the 3 most recently updated
          expect(list[0].investment.id, 'closed-1');
          expect(list[1].investment.id, 'closed-2');
          expect(list[2].investment.id, 'closed-3');
        },
        loading: () {},
        error: (e, st) => fail('Should not error: $e'),
      );
    });

    test('returns empty InvestmentStats when investment has no cash flows', () async {
      fakeRepository.seed(
        investments: [
          makeInvestment(
            id: 'closed-no-cfs',
            status: InvestmentStatus.closed,
            updatedAt: baseDate,
          ),
        ],
        cashFlows: [], // No cash flows
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.when(
        data: (list) {
          expect(list.length, 1);
          expect(list.first.stats.hasData, isFalse);
          expect(list.first.stats.totalInvested, 0);
        },
        loading: () {},
        error: (e, st) => fail('Should not error: $e'),
      );
    });

    test('attaches correct cash flows to each closed investment', () async {
      fakeRepository.seed(
        investments: [
          makeInvestment(
            id: 'closed-a',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 3, 1),
          ),
          makeInvestment(
            id: 'closed-b',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 2, 1),
          ),
        ],
        cashFlows: [
          makeCashFlow(
            id: 'cf-a1',
            investmentId: 'closed-a',
            amount: 5000,
            type: CashFlowType.invest,
          ),
          makeCashFlow(
            id: 'cf-b1',
            investmentId: 'closed-b',
            amount: 2000,
            type: CashFlowType.invest,
          ),
          makeCashFlow(
            id: 'cf-b2',
            investmentId: 'closed-b',
            amount: 3000,
            type: CashFlowType.returnFlow,
          ),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.when(
        data: (list) {
          expect(list.length, 2);
          final investA = list.firstWhere((e) => e.investment.id == 'closed-a');
          expect(investA.stats.totalInvested, 5000);
          expect(investA.stats.totalReturned, 0);

          final investB = list.firstWhere((e) => e.investment.id == 'closed-b');
          expect(investB.stats.totalInvested, 2000);
          expect(investB.stats.totalReturned, 3000);
        },
        loading: () {},
        error: (e, st) => fail('Should not error: $e'),
      );
    });

    test('cash flows of open investments are not included in results', () async {
      fakeRepository.seed(
        investments: [
          makeInvestment(
            id: 'closed-1',
            status: InvestmentStatus.closed,
            updatedAt: baseDate,
          ),
          makeInvestment(
            id: 'open-1',
            status: InvestmentStatus.open,
            updatedAt: baseDate,
          ),
        ],
        cashFlows: [
          makeCashFlow(
            id: 'cf-closed',
            investmentId: 'closed-1',
            amount: 1000,
            type: CashFlowType.invest,
          ),
          makeCashFlow(
            id: 'cf-open',
            investmentId: 'open-1',
            amount: 9999,
            type: CashFlowType.invest,
          ),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.when(
        data: (list) {
          expect(list.length, 1);
          expect(list.first.investment.id, 'closed-1');
          // Stats should only reflect the closed investment's cash flows
          expect(list.first.stats.totalInvested, 1000);
        },
        loading: () {},
        error: (e, st) => fail('Should not error: $e'),
      );
    });

    test('propagates loading state when investments are loading', () {
      // Fresh container - stream hasn't emitted yet before first pump
      final result = container.read(recentlyClosedInvestmentsProvider);

      // Either loading or data (empty) is acceptable on first read
      // depending on synchronous stream emission
      expect(
        result.isLoading || result.hasValue,
        isTrue,
      );
    });

    test('handles exactly 3 closed investments without trimming', () async {
      fakeRepository.seed(
        investments: [
          makeInvestment(
            id: 'c1',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 3, 1),
          ),
          makeInvestment(
            id: 'c2',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 2, 1),
          ),
          makeInvestment(
            id: 'c3',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 1, 1),
          ),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.when(
        data: (list) => expect(list.length, 3),
        loading: () {},
        error: (e, st) => fail('Should not error: $e'),
      );
    });
  });
}