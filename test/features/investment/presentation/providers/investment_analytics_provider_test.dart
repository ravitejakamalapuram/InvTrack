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

    final now = DateTime(2024, 6, 1);

    InvestmentEntity makeInvestment({
      required String id,
      required String name,
      required InvestmentStatus status,
      required DateTime updatedAt,
    }) {
      return InvestmentEntity(
        id: id,
        name: name,
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
      CashFlowType type = CashFlowType.invest,
      DateTime? date,
    }) {
      return CashFlowEntity(
        id: id,
        investmentId: investmentId,
        type: type,
        amount: amount,
        date: date ?? DateTime(2023, 1, 1),
        createdAt: DateTime(2023, 1, 1),
      );
    }

    setUp(() {
      fakeRepository = FakeInvestmentRepository();
      container = ProviderContainer(
        overrides: [
          investmentRepositoryProvider.overrideWithValue(fakeRepository),
          isAuthenticatedProvider.overrideWith((ref) => true),
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

      result.whenData((list) {
        expect(list, isEmpty);
      });
    });

    test('returns empty list when all investments are open', () async {
      fakeRepository.seed(investments: [
        makeInvestment(
          id: 'inv-1',
          name: 'Open A',
          status: InvestmentStatus.open,
          updatedAt: now,
        ),
        makeInvestment(
          id: 'inv-2',
          name: 'Open B',
          status: InvestmentStatus.open,
          updatedAt: now,
        ),
      ]);

      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.whenData((list) {
        expect(list, isEmpty);
      });
    });

    test('filters out open investments and returns only closed ones', () async {
      fakeRepository.seed(
        investments: [
          makeInvestment(
            id: 'open-1',
            name: 'Open Investment',
            status: InvestmentStatus.open,
            updatedAt: now,
          ),
          makeInvestment(
            id: 'closed-1',
            name: 'Closed Investment',
            status: InvestmentStatus.closed,
            updatedAt: now,
          ),
        ],
        cashFlows: [
          makeCashFlow(id: 'cf-1', investmentId: 'closed-1'),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.whenData((list) {
        expect(list.length, 1);
        expect(list.first.investment.id, 'closed-1');
        expect(list.first.investment.status, InvestmentStatus.closed);
      });
    });

    test('sorts closed investments by updatedAt descending (most recent first)',
        () async {
      fakeRepository.seed(
        investments: [
          makeInvestment(
            id: 'closed-old',
            name: 'Closed Old',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 1, 1),
          ),
          makeInvestment(
            id: 'closed-new',
            name: 'Closed New',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 5, 1),
          ),
          makeInvestment(
            id: 'closed-mid',
            name: 'Closed Mid',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 3, 1),
          ),
        ],
        cashFlows: [
          makeCashFlow(id: 'cf-1', investmentId: 'closed-old'),
          makeCashFlow(id: 'cf-2', investmentId: 'closed-new'),
          makeCashFlow(id: 'cf-3', investmentId: 'closed-mid'),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.whenData((list) {
        expect(list.length, 3);
        expect(list[0].investment.id, 'closed-new'); // Most recent
        expect(list[1].investment.id, 'closed-mid');
        expect(list[2].investment.id, 'closed-old'); // Least recent
      });
    });

    test('returns at most 3 most recently closed investments when more exist',
        () async {
      fakeRepository.seed(
        investments: [
          makeInvestment(
            id: 'inv-1',
            name: 'Closed 1',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 1, 1),
          ),
          makeInvestment(
            id: 'inv-2',
            name: 'Closed 2',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 2, 1),
          ),
          makeInvestment(
            id: 'inv-3',
            name: 'Closed 3',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 3, 1),
          ),
          makeInvestment(
            id: 'inv-4',
            name: 'Closed 4',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 4, 1),
          ),
          makeInvestment(
            id: 'inv-5',
            name: 'Closed 5',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 5, 1),
          ),
        ],
        cashFlows: [
          makeCashFlow(id: 'cf-1', investmentId: 'inv-1'),
          makeCashFlow(id: 'cf-2', investmentId: 'inv-2'),
          makeCashFlow(id: 'cf-3', investmentId: 'inv-3'),
          makeCashFlow(id: 'cf-4', investmentId: 'inv-4'),
          makeCashFlow(id: 'cf-5', investmentId: 'inv-5'),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.whenData((list) {
        expect(list.length, 3);
        // Should be the 3 most recently updated (inv-5, inv-4, inv-3)
        expect(list[0].investment.id, 'inv-5');
        expect(list[1].investment.id, 'inv-4');
        expect(list[2].investment.id, 'inv-3');
        // inv-1 and inv-2 should be excluded (oldest)
        expect(
          list.any((item) => item.investment.id == 'inv-1'),
          isFalse,
        );
        expect(
          list.any((item) => item.investment.id == 'inv-2'),
          isFalse,
        );
      });
    });

    test('returns all closed investments when exactly 3 exist', () async {
      fakeRepository.seed(
        investments: [
          makeInvestment(
            id: 'inv-1',
            name: 'Closed 1',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 1, 1),
          ),
          makeInvestment(
            id: 'inv-2',
            name: 'Closed 2',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 2, 1),
          ),
          makeInvestment(
            id: 'inv-3',
            name: 'Closed 3',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 3, 1),
          ),
        ],
        cashFlows: [
          makeCashFlow(id: 'cf-1', investmentId: 'inv-1'),
          makeCashFlow(id: 'cf-2', investmentId: 'inv-2'),
          makeCashFlow(id: 'cf-3', investmentId: 'inv-3'),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.whenData((list) {
        expect(list.length, 3);
      });
    });

    test('returns fewer than 3 when only 1 or 2 closed investments exist',
        () async {
      fakeRepository.seed(
        investments: [
          makeInvestment(
            id: 'inv-1',
            name: 'Closed 1',
            status: InvestmentStatus.closed,
            updatedAt: now,
          ),
          makeInvestment(
            id: 'inv-2',
            name: 'Open',
            status: InvestmentStatus.open,
            updatedAt: now,
          ),
        ],
        cashFlows: [
          makeCashFlow(id: 'cf-1', investmentId: 'inv-1'),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.whenData((list) {
        expect(list.length, 1);
        expect(list.first.investment.id, 'inv-1');
      });
    });

    test('attaches stats with cash flows for each returned investment',
        () async {
      fakeRepository.seed(
        investments: [
          makeInvestment(
            id: 'inv-1',
            name: 'Closed With Flows',
            status: InvestmentStatus.closed,
            updatedAt: now,
          ),
        ],
        cashFlows: [
          makeCashFlow(
            id: 'cf-1',
            investmentId: 'inv-1',
            amount: 5000.0,
            type: CashFlowType.invest,
            date: DateTime(2023, 1, 1),
          ),
          makeCashFlow(
            id: 'cf-2',
            investmentId: 'inv-1',
            amount: 6000.0,
            type: CashFlowType.returnFlow,
            date: DateTime(2024, 1, 1),
          ),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.whenData((list) {
        expect(list.length, 1);
        final item = list.first;
        expect(item.investment.id, 'inv-1');
        expect(item.stats.hasData, isTrue);
        expect(item.stats.totalInvested, 5000.0);
        expect(item.stats.totalReturned, 6000.0);
        expect(item.stats.cashFlowCount, 2);
      });
    });

    test(
        'only includes cash flows belonging to the matching closed investment (no cross-contamination)',
        () async {
      fakeRepository.seed(
        investments: [
          makeInvestment(
            id: 'closed-1',
            name: 'Closed A',
            status: InvestmentStatus.closed,
            updatedAt: DateTime(2024, 2, 1),
          ),
          makeInvestment(
            id: 'open-1',
            name: 'Open B',
            status: InvestmentStatus.open,
            updatedAt: now,
          ),
        ],
        cashFlows: [
          makeCashFlow(
              id: 'cf-closed',
              investmentId: 'closed-1',
              amount: 1000.0,
              type: CashFlowType.invest),
          makeCashFlow(
              id: 'cf-open',
              investmentId: 'open-1',
              amount: 9999.0,
              type: CashFlowType.invest),
        ],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.whenData((list) {
        expect(list.length, 1);
        // Stats for closed-1 must not include the open-1 cash flow
        expect(list.first.stats.totalInvested, 1000.0);
        expect(list.first.stats.cashFlowCount, 1);
      });
    });

    test('returns empty stats for closed investment with no cash flows',
        () async {
      fakeRepository.seed(
        investments: [
          makeInvestment(
            id: 'inv-1',
            name: 'Closed No Flows',
            status: InvestmentStatus.closed,
            updatedAt: now,
          ),
        ],
        cashFlows: [],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final result = container.read(recentlyClosedInvestmentsProvider);

      result.whenData((list) {
        expect(list.length, 1);
        expect(list.first.investment.id, 'inv-1');
        expect(list.first.stats.hasData, isFalse);
        expect(list.first.stats.totalInvested, 0.0);
      });
    });
  });
}