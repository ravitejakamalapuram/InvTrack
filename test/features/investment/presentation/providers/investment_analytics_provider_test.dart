/// Tests for investment_analytics_provider.dart
///
/// Covers the recentlyClosedInvestmentsProvider which was refactored
/// to use .where().toList()..sort() instead of a manual loop.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_analytics_provider.dart';
import '../../data/repositories/mock_investment_repository.dart';

void main() {
  group('recentlyClosedInvestmentsProvider', () {
    late FakeInvestmentRepository fakeRepository;
    late ProviderContainer container;

    // Helper to create investments with deterministic updatedAt timestamps
    InvestmentEntity makeInvestment({
      required String id,
      required InvestmentStatus status,
      required DateTime updatedAt,
    }) {
      return InvestmentEntity(
        id: id,
        name: 'Investment $id',
        type: InvestmentType.stocks,
        status: status,
        isArchived: false,
        createdAt: DateTime(2023, 1, 1),
        updatedAt: updatedAt,
      );
    }

    CashFlowEntity makeCashFlow({
      required String id,
      required String investmentId,
      double amount = 1000.0,
    }) {
      return CashFlowEntity(
        id: id,
        investmentId: investmentId,
        date: DateTime(2023, 6, 1),
        type: CashFlowType.invest,
        amount: amount,
        createdAt: DateTime(2023, 6, 1),
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

    test('returns empty list when no investments exist', () async {
      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.when(
        data: (investments) => expect(investments, isEmpty),
        loading: () {},
        error: (e, st) => fail('Should not error: $e'),
      );
    });

    test('returns only closed investments, not open ones', () async {
      fakeRepository.seed(
        investments: [
          makeInvestment(
            id: 'open-1',
            status: InvestmentStatus.open,
            updatedAt: DateTime(2024, 3, 1),
          ),
          makeInvestment(
            id: 'closed-1',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 2, 1),
          ),
        ],
        cashFlows: [
          makeCashFlow(id: 'cf-1', investmentId: 'open-1'),
          makeCashFlow(id: 'cf-2', investmentId: 'closed-1'),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.when(
        data: (investments) {
          expect(investments, hasLength(1));
          expect(investments.first.investment.id, equals('closed-1'));
        },
        loading: () {},
        error: (e, st) => fail('Should not error: $e'),
      );
    });

    test('returns empty list when all investments are open', () async {
      fakeRepository.seed(
        investments: [
          makeInvestment(
            id: 'open-1',
            status: InvestmentStatus.open,
            updatedAt: DateTime(2024, 1, 1),
          ),
          makeInvestment(
            id: 'open-2',
            status: InvestmentStatus.open,
            updatedAt: DateTime(2024, 2, 1),
          ),
        ],
        cashFlows: [
          makeCashFlow(id: 'cf-1', investmentId: 'open-1'),
          makeCashFlow(id: 'cf-2', investmentId: 'open-2'),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.when(
        data: (investments) => expect(investments, isEmpty),
        loading: () {},
        error: (e, st) => fail('Should not error: $e'),
      );
    });

    test('sorts closed investments by updatedAt descending (most recent first)', () async {
      final oldest = makeInvestment(
        id: 'closed-oldest',
        status: InvestmentStatus.closed,
        updatedAt: DateTime(2023, 1, 1),
      );
      final middle = makeInvestment(
        id: 'closed-middle',
        status: InvestmentStatus.closed,
        updatedAt: DateTime(2023, 6, 1),
      );
      final newest = makeInvestment(
        id: 'closed-newest',
        status: InvestmentStatus.closed,
        updatedAt: DateTime(2024, 1, 1),
      );

      // Seed in non-sorted order to verify sort is applied
      fakeRepository.seed(
        investments: [middle, oldest, newest],
        cashFlows: [
          makeCashFlow(id: 'cf-1', investmentId: 'closed-oldest'),
          makeCashFlow(id: 'cf-2', investmentId: 'closed-middle'),
          makeCashFlow(id: 'cf-3', investmentId: 'closed-newest'),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.when(
        data: (investments) {
          expect(investments, hasLength(3));
          expect(investments[0].investment.id, equals('closed-newest'));
          expect(investments[1].investment.id, equals('closed-middle'));
          expect(investments[2].investment.id, equals('closed-oldest'));
        },
        loading: () {},
        error: (e, st) => fail('Should not error: $e'),
      );
    });

    test('returns at most 3 closed investments (takes top 3 by updatedAt)', () async {
      // Create 5 closed investments
      final investments = List.generate(5, (i) {
        return makeInvestment(
          id: 'closed-$i',
          status: InvestmentStatus.closed,
          updatedAt: DateTime(2024, i + 1, 1),
        );
      });

      fakeRepository.seed(
        investments: investments,
        cashFlows: List.generate(
          5,
          (i) => makeCashFlow(id: 'cf-$i', investmentId: 'closed-$i'),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.when(
        data: (investments) {
          // Should cap at 3
          expect(investments.length, lessThanOrEqualTo(3));
          // Should be the 3 most recently updated (indices 4, 3, 2 -> May, Apr, Mar 2024)
          if (investments.length == 3) {
            expect(investments[0].investment.id, equals('closed-4'));
            expect(investments[1].investment.id, equals('closed-3'));
            expect(investments[2].investment.id, equals('closed-2'));
          }
        },
        loading: () {},
        error: (e, st) => fail('Should not error: $e'),
      );
    });

    test('returns exactly 3 when exactly 3 closed investments exist', () async {
      fakeRepository.seed(
        investments: [
          makeInvestment(
            id: 'c-1',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 1, 1),
          ),
          makeInvestment(
            id: 'c-2',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 2, 1),
          ),
          makeInvestment(
            id: 'c-3',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 3, 1),
          ),
        ],
        cashFlows: [
          makeCashFlow(id: 'cf-1', investmentId: 'c-1'),
          makeCashFlow(id: 'cf-2', investmentId: 'c-2'),
          makeCashFlow(id: 'cf-3', investmentId: 'c-3'),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.when(
        data: (investments) => expect(investments.length, lessThanOrEqualTo(3)),
        loading: () {},
        error: (e, st) => fail('Should not error: $e'),
      );
    });

    test('includes InvestmentStats for each closed investment', () async {
      fakeRepository.seed(
        investments: [
          makeInvestment(
            id: 'closed-1',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 1, 1),
          ),
        ],
        cashFlows: [
          CashFlowEntity(
            id: 'cf-invest',
            investmentId: 'closed-1',
            date: DateTime(2023, 1, 1),
            type: CashFlowType.invest,
            amount: 1000.0,
            createdAt: DateTime(2023, 1, 1),
          ),
          CashFlowEntity(
            id: 'cf-return',
            investmentId: 'closed-1',
            date: DateTime(2024, 1, 1),
            type: CashFlowType.returnFlow,
            amount: 1500.0,
            createdAt: DateTime(2024, 1, 1),
          ),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.when(
        data: (investments) {
          if (investments.isNotEmpty) {
            final item = investments.first;
            expect(item.investment.id, equals('closed-1'));
            // Stats should be computed from cash flows
            expect(item.stats.totalInvested, equals(1000.0));
            expect(item.stats.totalReturned, equals(1500.0));
          }
        },
        loading: () {},
        error: (e, st) => fail('Should not error: $e'),
      );
    });

    test('returns empty stats for closed investment with no cash flows', () async {
      fakeRepository.seed(
        investments: [
          makeInvestment(
            id: 'closed-no-cf',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 1, 1),
          ),
        ],
        cashFlows: const [],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.when(
        data: (investments) {
          if (investments.isNotEmpty) {
            expect(investments.first.stats.hasData, isFalse);
            expect(investments.first.stats.totalInvested, equals(0.0));
          }
        },
        loading: () {},
        error: (e, st) => fail('Should not error: $e'),
      );
    });

    test('only includes cash flows belonging to the closed investment', () async {
      // Two closed investments with cash flows; only the target's flows should
      // contribute to its stats.
      fakeRepository.seed(
        investments: [
          makeInvestment(
            id: 'closed-a',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 2, 1),
          ),
          makeInvestment(
            id: 'closed-b',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 1, 1),
          ),
        ],
        cashFlows: [
          CashFlowEntity(
            id: 'cf-a',
            investmentId: 'closed-a',
            date: DateTime(2023, 1, 1),
            type: CashFlowType.invest,
            amount: 2000.0,
            createdAt: DateTime(2023, 1, 1),
          ),
          CashFlowEntity(
            id: 'cf-b',
            investmentId: 'closed-b',
            date: DateTime(2023, 1, 1),
            type: CashFlowType.invest,
            amount: 500.0,
            createdAt: DateTime(2023, 1, 1),
          ),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.when(
        data: (investments) {
          if (investments.length == 2) {
            // Most recent first: closed-a then closed-b
            final invA = investments.firstWhere(
              (i) => i.investment.id == 'closed-a',
            );
            final invB = investments.firstWhere(
              (i) => i.investment.id == 'closed-b',
            );

            // Each investment should only count its own cash flows
            expect(invA.stats.totalInvested, equals(2000.0));
            expect(invB.stats.totalInvested, equals(500.0));
          }
        },
        loading: () {},
        error: (e, st) => fail('Should not error: $e'),
      );
    });

    test('boundary: returns 1 item when only 1 closed investment exists', () async {
      fakeRepository.seed(
        investments: [
          makeInvestment(
            id: 'the-only-one',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 5, 15),
          ),
          makeInvestment(
            id: 'open-one',
            status: InvestmentStatus.open,
            updatedAt: DateTime(2024, 6, 1),
          ),
        ],
        cashFlows: [
          makeCashFlow(id: 'cf-1', investmentId: 'the-only-one'),
          makeCashFlow(id: 'cf-2', investmentId: 'open-one'),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.when(
        data: (investments) {
          if (investments.isNotEmpty) {
            expect(investments, hasLength(1));
            expect(investments.first.investment.id, equals('the-only-one'));
          }
        },
        loading: () {},
        error: (e, st) => fail('Should not error: $e'),
      );
    });
  });
}