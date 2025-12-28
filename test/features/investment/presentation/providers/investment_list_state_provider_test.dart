import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_list_state_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_list_enums.dart';
import '../../data/repositories/mock_investment_repository.dart';

void main() {
  late FakeInvestmentRepository fakeRepository;
  late ProviderContainer container;

  final openInvestment = InvestmentEntity(
    id: 'open-1',
    name: 'Open Investment',
    type: InvestmentType.stocks,
    status: InvestmentStatus.open,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
    isArchived: false,
  );

  final closedInvestment = InvestmentEntity(
    id: 'closed-1',
    name: 'Closed Investment',
    type: InvestmentType.bonds,
    status: InvestmentStatus.closed,
    createdAt: DateTime(2024, 1, 2),
    updatedAt: DateTime(2024, 1, 2),
    isArchived: false,
  );

  final archivedOpenInvestment = InvestmentEntity(
    id: 'archived-open-1',
    name: 'Archived Open Investment',
    type: InvestmentType.p2pLending,
    status: InvestmentStatus.open,
    createdAt: DateTime(2024, 1, 3),
    updatedAt: DateTime(2024, 1, 3),
    isArchived: true,
  );

  final archivedClosedInvestment = InvestmentEntity(
    id: 'archived-closed-1',
    name: 'Archived Closed Investment',
    type: InvestmentType.mutualFunds,
    status: InvestmentStatus.closed,
    createdAt: DateTime(2024, 1, 4),
    updatedAt: DateTime(2024, 1, 4),
    isArchived: true,
  );

  setUp(() {
    fakeRepository = FakeInvestmentRepository();
    fakeRepository.seed(
      investments: [
        openInvestment,
        closedInvestment,
        archivedOpenInvestment,
        archivedClosedInvestment,
      ],
    );
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

  group('InvestmentFilter enum', () {
    test('should have all, open, closed, and archived values', () {
      expect(InvestmentFilter.values, hasLength(4));
      expect(InvestmentFilter.values, contains(InvestmentFilter.all));
      expect(InvestmentFilter.values, contains(InvestmentFilter.open));
      expect(InvestmentFilter.values, contains(InvestmentFilter.closed));
      expect(InvestmentFilter.values, contains(InvestmentFilter.archived));
    });
  });

  group('investmentCountsProvider', () {
    test('should return zero counts when investments are loading', () {
      // Initially, when stream hasn't emitted, counts should be zero
      final counts = container.read(investmentCountsProvider);

      // All counts are 0 while loading
      expect(counts.all, 0);
      expect(counts.open, 0);
      expect(counts.closed, 0);
      expect(counts.archived, 0);
    });
  });

  group('investmentListStateProvider', () {
    test('should have default filter as all', () {
      final state = container.read(investmentListStateProvider);
      expect(state.filter, InvestmentFilter.all);
    });

    test('should update filter when setFilter is called', () {
      container
          .read(investmentListStateProvider.notifier)
          .setFilter(InvestmentFilter.archived);
      final state = container.read(investmentListStateProvider);
      expect(state.filter, InvestmentFilter.archived);
    });

    test('should cycle through all filters', () {
      final notifier = container.read(investmentListStateProvider.notifier);

      notifier.setFilter(InvestmentFilter.open);
      expect(
        container.read(investmentListStateProvider).filter,
        InvestmentFilter.open,
      );

      notifier.setFilter(InvestmentFilter.closed);
      expect(
        container.read(investmentListStateProvider).filter,
        InvestmentFilter.closed,
      );

      notifier.setFilter(InvestmentFilter.archived);
      expect(
        container.read(investmentListStateProvider).filter,
        InvestmentFilter.archived,
      );

      notifier.setFilter(InvestmentFilter.all);
      expect(
        container.read(investmentListStateProvider).filter,
        InvestmentFilter.all,
      );
    });
  });
}
