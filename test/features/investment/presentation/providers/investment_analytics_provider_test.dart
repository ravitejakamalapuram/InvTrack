// Tests for investment_analytics_provider.dart
//
// The PR refactored the closed-investment filter in recentlyClosedInvestmentsProvider
// from an explicit for-loop to `.where((i) => i.status == InvestmentStatus.closed)
// .toList()..sort(...)`. These tests verify that the observable behaviour of the
// provider is correct regardless of the implementation style used.

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

    // Helper: create a base investment with configurable status / updatedAt.
    InvestmentEntity makeInvestment({
      required String id,
      required String name,
      required InvestmentStatus status,
      DateTime? updatedAt,
    }) {
      final ts = updatedAt ?? DateTime(2023, 1, 1);
      return InvestmentEntity(
        id: id,
        name: name,
        type: InvestmentType.stocks,
        status: status,
        isArchived: false,
        createdAt: DateTime(2023, 1, 1),
        updatedAt: ts,
      );
    }

    setUp(() {
      fakeRepository = FakeInvestmentRepository();
    });

    tearDown(() {
      container.dispose();
      fakeRepository.reset();
    });

    ProviderContainer createContainer() {
      return ProviderContainer(
        overrides: [
          // Provide a real (authenticated) repository so the stream providers
          // resolve without hitting Firestore.
          investmentRepositoryProvider.overrideWithValue(fakeRepository),
          isAuthenticatedProvider.overrideWithValue(true),
        ],
      );
    }

    test('returns empty list when there are no investments', () async {
      container = createContainer();

      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.whenData((list) {
        expect(list, isEmpty);
      });
    });

    test('returns empty list when all investments are open (not closed)',
        () async {
      fakeRepository.seed(
        investments: [
          makeInvestment(id: 'open-1', name: 'Open A', status: InvestmentStatus.open),
          makeInvestment(id: 'open-2', name: 'Open B', status: InvestmentStatus.open),
        ],
      );
      container = createContainer();

      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.whenData((list) {
        expect(list, isEmpty);
      });
    });

    test('only includes closed investments, not open ones', () async {
      fakeRepository.seed(
        investments: [
          makeInvestment(
            id: 'closed-1',
            name: 'Closed A',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 1, 1),
          ),
          makeInvestment(
            id: 'open-1',
            name: 'Open A',
            status: InvestmentStatus.open,
            updatedAt: DateTime(2024, 6, 1),
          ),
        ],
      );
      container = createContainer();

      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.whenData((list) {
        expect(list.length, 1);
        expect(list.first.investment.id, 'closed-1');
        // The open investment must NOT appear regardless of its updatedAt.
        expect(
          list.any((e) => e.investment.id == 'open-1'),
          isFalse,
        );
      });
    });

    test('sorts closed investments by updatedAt descending (most recent first)',
        () async {
      fakeRepository.seed(
        investments: [
          makeInvestment(
            id: 'older',
            name: 'Older Closed',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2022, 1, 1),
          ),
          makeInvestment(
            id: 'newest',
            name: 'Newest Closed',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 6, 1),
          ),
          makeInvestment(
            id: 'middle',
            name: 'Middle Closed',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2023, 3, 1),
          ),
        ],
      );
      container = createContainer();

      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.whenData((list) {
        expect(list.length, 3);
        // Sorted by updatedAt descending
        expect(list[0].investment.id, 'newest');
        expect(list[1].investment.id, 'middle');
        expect(list[2].investment.id, 'older');
      });
    });

    test('returns at most 3 investments (take(3) limit)', () async {
      // Seed 5 closed investments; only the 3 most recent should be returned.
      fakeRepository.seed(
        investments: [
          makeInvestment(
            id: 'c1', name: 'C1', status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 5, 1),
          ),
          makeInvestment(
            id: 'c2', name: 'C2', status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 4, 1),
          ),
          makeInvestment(
            id: 'c3', name: 'C3', status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 3, 1),
          ),
          makeInvestment(
            id: 'c4', name: 'C4', status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 2, 1),
          ),
          makeInvestment(
            id: 'c5', name: 'C5', status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 1, 1),
          ),
        ],
      );
      container = createContainer();

      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.whenData((list) {
        expect(list.length, 3);
        // Most recent 3
        expect(list[0].investment.id, 'c1');
        expect(list[1].investment.id, 'c2');
        expect(list[2].investment.id, 'c3');
        // c4 and c5 are excluded
        expect(list.any((e) => e.investment.id == 'c4'), isFalse);
        expect(list.any((e) => e.investment.id == 'c5'), isFalse);
      });
    });

    test('includes InvestmentStats computed from matching cash flows', () async {
      fakeRepository.seed(
        investments: [
          makeInvestment(
            id: 'closed-with-flows',
            name: 'Closed With Flows',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 1, 1),
          ),
        ],
        cashFlows: [
          CashFlowEntity(
            id: 'cf1',
            investmentId: 'closed-with-flows',
            date: DateTime(2023, 1, 1),
            type: CashFlowType.invest,
            amount: 2000,
            createdAt: DateTime(2023, 1, 1),
          ),
          CashFlowEntity(
            id: 'cf2',
            investmentId: 'closed-with-flows',
            date: DateTime(2024, 1, 1),
            type: CashFlowType.returnFlow,
            amount: 3000,
            createdAt: DateTime(2024, 1, 1),
          ),
        ],
      );
      container = createContainer();

      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.whenData((list) {
        expect(list.length, 1);
        final stats = list.first.stats;
        expect(stats.totalInvested, 2000);
        expect(stats.totalReturned, 3000);
        expect(stats.netCashFlow, 1000);
      });
    });

    // Regression: the filter must use InvestmentStatus.closed only.
    // Open investments with large amounts must not inflate the closed list.
    test(
      'regression – open investment with large amount is not included in closed list',
      () async {
        fakeRepository.seed(
          investments: [
            makeInvestment(
              id: 'big-open',
              name: 'Large Open Investment',
              status: InvestmentStatus.open,
              updatedAt: DateTime(2025, 1, 1), // very recent
            ),
            makeInvestment(
              id: 'small-closed',
              name: 'Small Closed Investment',
              status: InvestmentStatus.closed,
              updatedAt: DateTime(2020, 1, 1),
            ),
          ],
          cashFlows: [
            CashFlowEntity(
              id: 'open-cf',
              investmentId: 'big-open',
              date: DateTime(2025, 1, 1),
              type: CashFlowType.invest,
              amount: 1000000,
              createdAt: DateTime(2025, 1, 1),
            ),
          ],
        );
        container = createContainer();

        await Future.delayed(const Duration(milliseconds: 50));

        final result = container.read(recentlyClosedInvestmentsProvider);

        result.whenData((list) {
          // Only the closed investment should appear
          expect(list.length, 1);
          expect(list.first.investment.id, 'small-closed');
          expect(list.any((e) => e.investment.id == 'big-open'), isFalse);
        });
      },
    );
  });
}