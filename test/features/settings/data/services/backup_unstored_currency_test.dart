// A80 (#845): a backup must not turn the read-time guess into a stored
// currency. A record saved before multi-currency support has no currency; the
// app shows it in the current base currency, but until the user confirms
// (A03-F1) the backup leaves the Currency cell empty, so the account that
// imports it applies its own base currency (money rules 1 and 2).
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/performance/performance_service.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/document_repository.dart';
import 'package:inv_tracker/features/settings/data/services/data_export_service.dart';
import 'package:inv_tracker/features/settings/data/services/data_import_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../goals/data/repositories/mock_goal_repository.dart';
import '../../../investment/data/repositories/mock_investment_repository.dart';
import '../../../investment/valuation/in_memory_valuation_repository.dart';

class _PerformanceService extends Mock implements PerformanceService {
  @override
  Future<T> trackOperation<T>(
    String traceName,
    Future<T> Function() operation, {
    Map<String, int>? metrics,
    Map<String, String>? attributes,
  }) => operation();
}

class _DocumentRepository extends Mock implements DocumentRepository {}

class _DocumentStorageService extends Mock implements DocumentStorageService {}

/// One device's repositories with an export and an import service on them.
class _Device {
  _Device() {
    final documents = _DocumentRepository();
    final storage = _DocumentStorageService();
    when(
      () => documents.getDocumentsByInvestment(any()),
    ).thenAnswer((_) async => []);
    export = DataExportService(
      investmentRepository: investments,
      goalRepository: goals,
      documentRepository: documents,
      documentStorageService: storage,
      valuationRepository: valuations,
      performanceService: _PerformanceService(),
    );
    import = DataImportService(
      investmentRepository: investments,
      goalRepository: goals,
      documentRepository: documents,
      documentStorageService: storage,
      valuationRepository: valuations,
      performanceService: _PerformanceService(),
    );
  }

  final investments = FakeInvestmentRepository();
  final goals = FakeGoalRepository();
  final valuations = InMemoryValuationRepository();
  late final DataExportService export;
  late final DataImportService import;
}

InvestmentEntity _investment({
  bool assumed = false,
  String currency = 'INR',
  double? currentValue,
}) => InvestmentEntity(
  id: 'inv-1',
  name: 'Legacy FD',
  type: InvestmentType.fixedDeposit,
  status: InvestmentStatus.open,
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
  currency: currency,
  currencyAssumed: assumed,
  currentValue: currentValue,
  currentValueDate: currentValue == null ? null : DateTime(2026, 1, 1),
);

CashFlowEntity _cashFlow({bool assumed = false, String currency = 'INR'}) =>
    CashFlowEntity(
      id: 'cf-1',
      investmentId: 'inv-1',
      type: CashFlowType.invest,
      amount: 10000,
      date: DateTime(2024, 1, 15),
      createdAt: DateTime(2024, 1, 15),
      currency: currency,
      currencyAssumed: assumed,
    );

GoalEntity _goal({bool assumed = false, String currency = 'INR'}) => GoalEntity(
  id: 'goal-1',
  name: 'House',
  type: GoalType.targetAmount,
  targetAmount: 2500000,
  trackingMode: GoalTrackingMode.all,
  icon: 'home',
  colorValue: 0xFF2196F3,
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
  currency: currency,
  currencyAssumed: assumed,
);

/// The cells of [column] in [file] of [bytes], header excluded.
List<String> _column(Uint8List bytes, String file, String column) {
  final content = ZipDecoder().decodeBytes(bytes).findFile(file)!.content;
  final rows = csv.decode(utf8.decode(content as List<int>));
  final index = rows.first.indexOf(column);
  expect(index, isNonNegative, reason: '$file has a $column column');
  return [for (final row in rows.skip(1)) row[index].toString()];
}

void main() {
  late _Device source;
  late _Device target;

  setUp(() {
    source = _Device();
    target = _Device();
  });

  tearDown(() {
    source.valuations.dispose();
    target.valuations.dispose();
  });

  Future<ZipImportResult> restore(Uint8List bytes, String baseCurrency) =>
      target.import.importFromZip(
        bytes,
        ImportStrategy.merge,
        baseCurrency: baseCurrency,
      );

  group('cash flows (cashflows.csv)', () {
    test('an assumed currency is written as an empty cell, not the base '
        'currency', () async {
      source.investments.seed(
        investments: [_investment(assumed: true)],
        cashFlows: [_cashFlow(assumed: true)],
      );

      final export = await source.export.exportAsZipBytes();

      expect(_column(export.bytes, 'cashflows.csv', 'Currency'), ['']);
      expect(_column(export.bytes, 'cashflows.csv', 'Amount'), ['10000.0']);
    });

    test('imported into a USD account it is stored as USD 10000.00', () async {
      source.investments.seed(
        investments: [_investment(assumed: true)],
        cashFlows: [_cashFlow(assumed: true)],
      );
      final export = await source.export.exportAsZipBytes();

      final result = await restore(export.bytes, 'USD');

      expect(result.isSuccess, isTrue);
      final stored = target.investments.cashFlows.single;
      expect(stored.currency, 'USD');
      expect(stored.amount, 10000.00);
      expect(target.investments.investments.single.currency, 'USD');
    });

    for (final base in ['USD', 'INR', 'GBP']) {
      test(
        'a stored EUR currency exports and imports as EUR (base $base)',
        () async {
          source.investments.seed(
            investments: [_investment(currency: 'EUR')],
            cashFlows: [_cashFlow(currency: 'EUR')],
          );
          final export = await source.export.exportAsZipBytes();

          expect(_column(export.bytes, 'cashflows.csv', 'Currency'), ['EUR']);

          await restore(export.bytes, base);

          expect(target.investments.cashFlows.single.currency, 'EUR');
          expect(target.investments.cashFlows.single.amount, 10000.00);
        },
      );
    }
  });

  group('goals (goals.csv)', () {
    test('an assumed currency is written as an empty cell', () async {
      source.investments.seed(
        investments: [_investment(assumed: true)],
        cashFlows: [_cashFlow(assumed: true)],
      );
      source.goals.seed(goals: [_goal(assumed: true)]);

      final export = await source.export.exportAsZipBytes();

      expect(_column(export.bytes, 'goals.csv', 'Currency'), ['']);
    });

    test('imported into a USD account it is stored as USD', () async {
      source.goals.seed(goals: [_goal(assumed: true)]);
      final export = await source.export.exportAsZipBytes();

      final result = await restore(export.bytes, 'USD');

      expect(result.goalsImported, 1);
      expect(target.goals.goals.single.currency, 'USD');
      expect(target.goals.goals.single.targetAmount, 2500000.00);
    });

    for (final base in ['USD', 'INR']) {
      test(
        'a stored EUR goal exports and imports as EUR (base $base)',
        () async {
          source.goals.seed(goals: [_goal(currency: 'EUR')]);
          final export = await source.export.exportAsZipBytes();

          expect(_column(export.bytes, 'goals.csv', 'Currency'), ['EUR']);

          await restore(export.bytes, base);

          expect(target.goals.goals.single.currency, 'EUR');
        },
      );
    }
  });

  group('investments (valuations.csv)', () {
    test('the value of an investment with an assumed currency has an empty '
        'Currency cell and takes the importing account\'s base', () async {
      source.investments.seed(
        investments: [_investment(assumed: true, currentValue: 12000)],
        cashFlows: [_cashFlow(assumed: true)],
      );
      final export = await source.export.exportAsZipBytes();

      expect(_column(export.bytes, 'valuations.csv', 'Currency'), ['']);

      final result = await restore(export.bytes, 'USD');

      expect(result.errors, isEmpty);
      expect(target.investments.investments.single.currency, 'USD');
      final snapshot = (await target.valuations.getAll()).single;
      expect(snapshot.currency, 'USD');
      expect(snapshot.amount, 12000.00);
    });

    test(
      'the value of an investment with a stored currency keeps it',
      () async {
        source.investments.seed(
          investments: [_investment(currency: 'EUR', currentValue: 12000)],
          cashFlows: [_cashFlow(currency: 'EUR')],
        );
        final export = await source.export.exportAsZipBytes();

        expect(_column(export.bytes, 'valuations.csv', 'Currency'), ['EUR']);
      },
    );
  });

  group('guest merge', () {
    // The merge exports the guest's data and imports it into the Google
    // account with the base currency the provider passes (the guest's,
    // read before the sign-in): the same two calls as below. The guest's
    // device guessed INR for the unconfirmed record; the merge must apply
    // its own base currency (USD), not carry the guess over.
    test('a guest legacy cash flow with no stored currency is stored as the '
        'base currency of the merge, never a stamped guess', () async {
      source.investments.seed(
        investments: [_investment(assumed: true)],
        cashFlows: [_cashFlow(assumed: true)],
      );
      source.goals.seed(goals: [_goal(assumed: true)]);

      final export = await source.export.exportAsZipBytes();
      await target.import.importFromZip(
        export.bytes,
        ImportStrategy.merge,
        baseCurrency: 'USD',
      );

      expect(target.investments.cashFlows.single.currency, 'USD');
      expect(target.investments.cashFlows.single.amount, 10000.00);
      expect(target.goals.goals.single.currency, 'USD');
    });
  });
}
