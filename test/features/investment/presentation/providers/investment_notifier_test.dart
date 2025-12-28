import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/config/app_constants.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_notifier.dart';
import '../../data/repositories/mock_investment_repository.dart';
import '../../../../mocks/mock_analytics_service.dart';

void main() {
  late FakeInvestmentRepository fakeRepository;
  late FakeAnalyticsService fakeAnalytics;
  late ProviderContainer container;

  setUp(() {
    fakeRepository = FakeInvestmentRepository();
    fakeAnalytics = FakeAnalyticsService();
    container = ProviderContainer(
      overrides: [
        investmentRepositoryProvider.overrideWithValue(fakeRepository),
        analyticsServiceProvider.overrideWithValue(fakeAnalytics),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    fakeRepository.reset();
    fakeAnalytics.reset();
  });

  group('InvestmentNotifier - addInvestment', () {
    test('should create investment with valid data', () async {
      final notifier = container.read(investmentNotifierProvider.notifier);

      final result = await notifier.addInvestment(
        name: 'Test Investment',
        type: InvestmentType.p2pLending,
        notes: 'Test notes',
      );

      expect(result.name, 'Test Investment');
      expect(result.type, InvestmentType.p2pLending);
      expect(result.notes, 'Test notes');
      expect(result.status, InvestmentStatus.open);
      expect(fakeRepository.investments, hasLength(1));
    });

    test('should trim whitespace from name and notes', () async {
      final notifier = container.read(investmentNotifierProvider.notifier);

      final result = await notifier.addInvestment(
        name: '  Trimmed Name  ',
        type: InvestmentType.stocks,
        notes: '  Trimmed Notes  ',
      );

      expect(result.name, 'Trimmed Name');
      expect(result.notes, 'Trimmed Notes');
    });

    test('should throw ValidationException for empty name', () async {
      final notifier = container.read(investmentNotifierProvider.notifier);

      expect(
        () => notifier.addInvestment(name: '', type: InvestmentType.p2pLending),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should throw ValidationException for whitespace-only name', () async {
      final notifier = container.read(investmentNotifierProvider.notifier);

      expect(
        () => notifier.addInvestment(
          name: '   ',
          type: InvestmentType.p2pLending,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test(
      'should throw ValidationException for name exceeding max length',
      () async {
        final notifier = container.read(investmentNotifierProvider.notifier);
        final longName = 'A' * (ValidationConstants.maxNameLength + 1);

        expect(
          () => notifier.addInvestment(
            name: longName,
            type: InvestmentType.p2pLending,
          ),
          throwsA(isA<ValidationException>()),
        );
      },
    );

    test(
      'should throw ValidationException for notes exceeding max length',
      () async {
        final notifier = container.read(investmentNotifierProvider.notifier);
        final longNotes = 'A' * (ValidationConstants.maxNotesLength + 1);

        expect(
          () => notifier.addInvestment(
            name: 'Valid Name',
            type: InvestmentType.p2pLending,
            notes: longNotes,
          ),
          throwsA(isA<ValidationException>()),
        );
      },
    );
  });

  group('InvestmentNotifier - updateInvestment', () {
    test('should update existing investment', () async {
      final notifier = container.read(investmentNotifierProvider.notifier);
      final created = await notifier.addInvestment(
        name: 'Original Name',
        type: InvestmentType.p2pLending,
      );

      await notifier.updateInvestment(
        id: created.id,
        name: 'Updated Name',
        type: InvestmentType.stocks,
        notes: 'New notes',
      );

      final updated = await fakeRepository.getInvestmentById(created.id);
      expect(updated!.name, 'Updated Name');
      expect(updated.type, InvestmentType.stocks);
      expect(updated.notes, 'New notes');
    });

    test('should throw DataException for non-existent investment', () async {
      final notifier = container.read(investmentNotifierProvider.notifier);

      expect(
        () => notifier.updateInvestment(
          id: 'non-existent-id',
          name: 'Name',
          type: InvestmentType.p2pLending,
        ),
        throwsA(isA<DataException>()),
      );
    });
  });

  group('InvestmentNotifier - closeInvestment', () {
    test('should close an open investment', () async {
      final notifier = container.read(investmentNotifierProvider.notifier);
      final created = await notifier.addInvestment(
        name: 'Test Investment',
        type: InvestmentType.p2pLending,
      );

      await notifier.closeInvestment(created.id);

      final closed = await fakeRepository.getInvestmentById(created.id);
      expect(closed!.status, InvestmentStatus.closed);
      expect(closed.closedAt, isNotNull);
    });
  });

  group('InvestmentNotifier - reopenInvestment', () {
    test('should reopen a closed investment', () async {
      final notifier = container.read(investmentNotifierProvider.notifier);
      final created = await notifier.addInvestment(
        name: 'Test Investment',
        type: InvestmentType.p2pLending,
      );
      await notifier.closeInvestment(created.id);

      await notifier.reopenInvestment(created.id);

      final reopened = await fakeRepository.getInvestmentById(created.id);
      expect(reopened!.status, InvestmentStatus.open);
      expect(reopened.closedAt, isNull);
    });
  });

  group('InvestmentNotifier - deleteInvestment', () {
    test('should delete investment and its cash flows', () async {
      final notifier = container.read(investmentNotifierProvider.notifier);
      final created = await notifier.addInvestment(
        name: 'Test Investment',
        type: InvestmentType.p2pLending,
      );
      await notifier.addCashFlow(
        investmentId: created.id,
        type: CashFlowType.invest,
        amount: 1000,
        date: DateTime.now(),
      );

      await notifier.deleteInvestment(created.id);

      expect(fakeRepository.investments, isEmpty);
      expect(fakeRepository.cashFlows, isEmpty);
    });
  });

  group('InvestmentNotifier - addCashFlow', () {
    test('should add cash flow with valid data', () async {
      final notifier = container.read(investmentNotifierProvider.notifier);
      final investment = await notifier.addInvestment(
        name: 'Test Investment',
        type: InvestmentType.p2pLending,
      );

      await notifier.addCashFlow(
        investmentId: investment.id,
        type: CashFlowType.invest,
        amount: 1000,
        date: DateTime(2024, 1, 1),
        notes: 'Initial investment',
      );

      expect(fakeRepository.cashFlows, hasLength(1));
      expect(fakeRepository.cashFlows.first.amount, 1000);
      expect(fakeRepository.cashFlows.first.type, CashFlowType.invest);
    });

    test('should throw ValidationException for zero amount', () async {
      final notifier = container.read(investmentNotifierProvider.notifier);
      final investment = await notifier.addInvestment(
        name: 'Test Investment',
        type: InvestmentType.p2pLending,
      );

      expect(
        () => notifier.addCashFlow(
          investmentId: investment.id,
          type: CashFlowType.invest,
          amount: 0,
          date: DateTime.now(),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should throw ValidationException for negative amount', () async {
      final notifier = container.read(investmentNotifierProvider.notifier);
      final investment = await notifier.addInvestment(
        name: 'Test Investment',
        type: InvestmentType.p2pLending,
      );

      expect(
        () => notifier.addCashFlow(
          investmentId: investment.id,
          type: CashFlowType.invest,
          amount: -100,
          date: DateTime.now(),
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('InvestmentNotifier - bulkDelete', () {
    test('should delete multiple investments', () async {
      final notifier = container.read(investmentNotifierProvider.notifier);
      final inv1 = await notifier.addInvestment(
        name: 'Investment 1',
        type: InvestmentType.p2pLending,
      );
      final inv2 = await notifier.addInvestment(
        name: 'Investment 2',
        type: InvestmentType.stocks,
      );

      final deletedCount = await notifier.bulkDelete([inv1.id, inv2.id]);

      expect(deletedCount, 2);
      expect(fakeRepository.investments, isEmpty);
    });

    test('should return 0 for empty list', () async {
      final notifier = container.read(investmentNotifierProvider.notifier);

      final deletedCount = await notifier.bulkDelete([]);

      expect(deletedCount, 0);
    });
  });

  group('InvestmentNotifier - archiveInvestment', () {
    test('should archive an investment', () async {
      final notifier = container.read(investmentNotifierProvider.notifier);
      final created = await notifier.addInvestment(
        name: 'Test Investment',
        type: InvestmentType.p2pLending,
      );

      expect(created.isArchived, false);

      await notifier.archiveInvestment(created.id);

      final archived = await fakeRepository.getInvestmentById(created.id);
      expect(archived!.isArchived, true);
    });

    test('should archive an already closed investment', () async {
      final notifier = container.read(investmentNotifierProvider.notifier);
      final created = await notifier.addInvestment(
        name: 'Test Investment',
        type: InvestmentType.stocks,
      );
      await notifier.closeInvestment(created.id);

      await notifier.archiveInvestment(created.id);

      final archived = await fakeRepository.getInvestmentById(created.id);
      expect(archived!.isArchived, true);
      expect(archived.status, InvestmentStatus.closed);
    });
  });

  group('InvestmentNotifier - unarchiveInvestment', () {
    test('should unarchive an archived investment', () async {
      final notifier = container.read(investmentNotifierProvider.notifier);
      final created = await notifier.addInvestment(
        name: 'Test Investment',
        type: InvestmentType.p2pLending,
      );
      await notifier.archiveInvestment(created.id);

      final archived = await fakeRepository.getInvestmentById(created.id);
      expect(archived!.isArchived, true);

      await notifier.unarchiveInvestment(created.id);

      final unarchived = await fakeRepository.getInvestmentById(created.id);
      expect(unarchived!.isArchived, false);
    });

    test('should preserve investment status when unarchiving', () async {
      final notifier = container.read(investmentNotifierProvider.notifier);
      final created = await notifier.addInvestment(
        name: 'Test Investment',
        type: InvestmentType.stocks,
      );
      await notifier.closeInvestment(created.id);
      await notifier.archiveInvestment(created.id);

      await notifier.unarchiveInvestment(created.id);

      final unarchived = await fakeRepository.getInvestmentById(created.id);
      expect(unarchived!.isArchived, false);
      expect(unarchived.status, InvestmentStatus.closed);
    });
  });
}
