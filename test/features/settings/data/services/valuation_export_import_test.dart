// #941 (plan tests 15, T21): dated valuations survive export -> wipe -> import
// (money rule 6), including investments that have no cash flows at all (an
// opening baseline), several snapshots per investment, archived investments
// and files written before the new columns existed.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/performance/performance_service.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/document_repository.dart';
import 'package:inv_tracker/features/settings/data/services/data_export_service.dart';
import 'package:inv_tracker/features/settings/data/services/data_import_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../goals/data/repositories/mock_goal_repository.dart';
import '../../../investment/data/repositories/mock_investment_repository.dart';
import '../../../investment/valuation/in_memory_valuation_repository.dart';
import '../../../investment/valuation/valuation_fixtures.dart';

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

CashFlowEntity _invest(String investmentId, {double amount = 100000}) =>
    CashFlowEntity(
      id: 'cf-$investmentId',
      investmentId: investmentId,
      type: CashFlowType.invest,
      amount: amount,
      currency: 'INR',
      date: DateTime(2025, 10, 1),
      createdAt: DateTime(2025, 10, 1),
    );

Uint8List _zip(Map<String, String> files) {
  final zip = Archive();
  void add(String name, String content) {
    final data = utf8.encode(content);
    zip.addFile(ArchiveFile(name, data.length, data));
  }

  add('metadata.json', jsonEncode({'version': '1.0', 'documents': []}));
  files.forEach(add);
  return Uint8List.fromList(ZipEncoder().encode(zip)!);
}

const _cashFlowsHeader =
    'Date,Investment Name,Type,Amount,Currency,Notes,Investment Type,'
    'Investment Status\n';
const _legacyHeader = 'Investment Name,Archived,Date,Value,Currency\n';
const _newHeader =
    'Investment Name,Archived,Date,Value,Currency,Snapshot ID,Kind,Source,'
    'Updated At,Investment Type,Investment Status\n';

void main() {
  late FakeInvestmentRepository repo;
  late InMemoryValuationRepository valuations;
  late DataExportService exportService;
  late DataImportService importService;

  setUp(() {
    repo = FakeInvestmentRepository();
    valuations = InMemoryValuationRepository();
    final goals = FakeGoalRepository();
    final documents = _DocumentRepository();
    final storage = _DocumentStorageService();
    when(
      () => documents.getDocumentsByInvestment(any()),
    ).thenAnswer((_) async => []);
    exportService = DataExportService(
      investmentRepository: repo,
      goalRepository: goals,
      documentRepository: documents,
      documentStorageService: storage,
      valuationRepository: valuations,
      performanceService: _PerformanceService(),
    );
    importService = DataImportService(
      investmentRepository: repo,
      goalRepository: goals,
      documentRepository: documents,
      documentStorageService: storage,
      valuationRepository: valuations,
      performanceService: _PerformanceService(),
    );
  });

  tearDown(() => valuations.dispose());

  Future<ZipExport> export() => exportService.exportAsZipBytes();

  List<List<dynamic>> valuationRows(Uint8List bytes) {
    final file = ZipDecoder().decodeBytes(bytes).findFile('valuations.csv')!;
    return csv.decode(utf8.decode(file.content as List<int>));
  }

  Future<ZipImportResult> importZip(
    Uint8List bytes, {
    ImportStrategy strategy = ImportStrategy.replace,
  }) => importService.importFromZip(bytes, strategy, baseCurrency: 'INR');

  void wipe() {
    repo.reset();
    valuations.docs.clear();
  }

  Future<List<InvestmentValuationSnapshot>> imported() => valuations.getAll();

  group('a baseline with no cash flows (T21)', () {
    final baseline = testSnapshot(
      'b1',
      investmentId: 'plot',
      amount: 500000.00,
      date: DateTime(2026, 1, 1),
      kind: ValuationKind.marketValue,
      provenance: ValuationProvenance.openingBaseline,
      updatedAt: DateTime.utc(2026, 1, 2, 9, 30),
    );

    setUp(() {
      repo.seed(
        investments: [
          testInvestment(
            'plot',
            compatValue: 500000,
            compatDate: DateTime(2026, 1, 1),
          ).copyWith(name: 'Plot in Pune'),
        ],
      );
      valuations.docs['b1'] = baseline;
    });

    test('is carried by the export', () async {
      final result = await export();
      expect(result.investments, 1);
      expect(result.cashFlows, 0);
      expect(result.investmentsNotInExport, 0);
      expect(result.carriesEverything, isTrue);
    });

    test('survives export, wipe and import', () async {
      final bytes = (await export()).bytes;
      wipe();

      final result = await importZip(bytes);
      expect(result.errors, isEmpty);
      expect(result.investmentsImported, 1);
      expect(result.cashflowsImported, 0);

      final investment = (await repo.getAllInvestments()).single;
      expect(investment.name, 'Plot in Pune');
      expect(investment.type, InvestmentType.gold);
      expect(investment.status, InvestmentStatus.open);
      expect(investment.currency, 'INR');
      expect(repo.cashFlows, isEmpty);
      // The mirror is written whatever the feature flag says.
      expect(investment.currentValue, 500000.00);
      expect(investment.currentValueDate, DateTime(2026, 1, 1));

      final snapshot = (await imported()).single;
      expect(snapshot.investmentId, investment.id);
      expect(snapshot.amount, 500000.00);
      expect(snapshot.currency, 'INR');
      expect(snapshot.effectiveDate, DateTime(2026, 1, 1));
      expect(snapshot.kind, ValuationKind.marketValue);
      expect(snapshot.provenance, ValuationProvenance.openingBaseline);
      expect(snapshot.updatedAt, DateTime.utc(2026, 1, 2, 9, 30));
      expect(snapshot.isLive, isTrue);
    });

    test(
      'is not counted as left out when it only has a legacy value',
      () async {
        valuations.docs.clear();
        final result = await export();
        expect(result.investmentsNotInExport, 0);
      },
    );

    test(
      'an investment with neither flows nor a value is still left out',
      () async {
        repo.seed(investments: [testInvestment('empty')]);
        final result = await export();
        expect(result.investmentsNotInExport, 1);
        expect(result.carriesEverything, isFalse);
      },
    );

    test('an archived baseline-only investment survives too', () async {
      repo
        ..reset()
        ..seed(
          archivedInvestments: [
            testInvestment('old', isArchived: true).copyWith(name: 'Old plot'),
          ],
        );
      valuations.docs
        ..clear()
        ..['o1'] = testSnapshot(
          'o1',
          investmentId: 'old',
          amount: 42,
          date: DateTime(2026, 1, 1),
        );
      final bytes = (await export()).bytes;
      wipe();

      await importZip(bytes);
      final archived = await repo.watchArchivedInvestments().first;
      expect(archived.single.name, 'Old plot');
      expect((await repo.getAllInvestments()), isEmpty);
      expect((await imported()).single.amount, 42);
    });
  });

  group('several snapshots per investment', () {
    setUp(() {
      repo.seed(
        investments: [testInvestment('gold').copyWith(name: 'SGB 2031')],
        cashFlows: [_invest('gold')],
        archivedInvestments: [
          testInvestment('old', isArchived: true).copyWith(name: 'Old gold'),
        ],
        archivedCashFlows: [_invest('old')],
      );
      valuations.docs.addAll({
        // Written out of order on purpose.
        'g3': testSnapshot(
          'g3',
          investmentId: 'gold',
          amount: 130000,
          date: DateTime(2026, 6, 1),
          kind: ValuationKind.marketValue,
        ),
        'g1': testSnapshot(
          'g1',
          investmentId: 'gold',
          amount: 110000,
          date: DateTime(2025, 12, 1),
          provenance: ValuationProvenance.openingBaseline,
        ),
        'g2': testSnapshot(
          'g2',
          investmentId: 'gold',
          amount: 120000,
          date: DateTime(2026, 3, 1),
          kind: ValuationKind.principalOutstanding,
        ),
        'g4': testSnapshot(
          'g4',
          investmentId: 'gold',
          amount: 999,
          date: DateTime(2026, 7, 1),
          deletedAt: DateTime.utc(2026, 7, 2),
        ),
        'o1': testSnapshot(
          'o1',
          investmentId: 'old',
          amount: 90000,
          date: DateTime(2026, 2, 1),
        ),
      });
    });

    test('the file lists live snapshots oldest first, so an older app that '
        'keeps the last row per investment keeps the newest', () async {
      final rows = valuationRows((await export()).bytes);
      expect(rows.first, [
        'Investment Name',
        'Archived',
        'Date',
        'Value',
        'Currency',
        'Snapshot ID',
        'Kind',
        'Source',
        'Updated At',
        'Investment Type',
        'Investment Status',
      ]);
      final gold = [
        for (final row in rows.skip(1))
          if (row[0] == 'SGB 2031') row,
      ];
      expect(gold.map((r) => r[2]), ['2025-12-01', '2026-03-01', '2026-06-01']);
      expect(gold.map((r) => r[3]), ['110000.0', '120000.0', '130000.0']);
      expect(gold.map((r) => r[5]), ['g1', 'g2', 'g3']);
      expect(gold.map((r) => r[6]), [
        'carryingValue',
        'principalOutstanding',
        'marketValue',
      ]);
      expect(gold.map((r) => r[7]), ['openingBaseline', 'manual', 'manual']);
      expect(gold.every((r) => r[1] == 'false'), isTrue);
      // A cleared snapshot is not exported.
      expect(rows.any((r) => r.contains('g4')), isFalse);
    });

    test('every snapshot is restored, active and archived', () async {
      final bytes = (await export()).bytes;
      wipe();
      final result = await importZip(bytes);
      expect(result.errors, isEmpty);

      final all = await imported();
      expect(all, hasLength(4));
      final active = (await repo.getAllInvestments()).single;
      final archived = (await repo.watchArchivedInvestments().first).single;
      final mine = [
        for (final s in all)
          if (s.investmentId == active.id) s,
      ]..sort((a, b) => a.effectiveDate.compareTo(b.effectiveDate));
      expect(mine.map((s) => s.amount), [110000, 120000, 130000]);
      expect(mine.map((s) => s.kind), [
        ValuationKind.carryingValue,
        ValuationKind.principalOutstanding,
        ValuationKind.marketValue,
      ]);
      expect(mine.first.provenance, ValuationProvenance.openingBaseline);
      expect(all.where((s) => s.investmentId == archived.id), hasLength(1));
      // The mirror reads the latest.
      expect(active.currentValue, 130000);
      expect(active.currentValueDate, DateTime(2026, 6, 1));
    });

    test('snapshot ids are new, so an import cannot overwrite another '
        'investment\'s snapshot', () async {
      final bytes = (await export()).bytes;
      final before = valuations.docs.keys.toSet();
      await importZip(bytes, strategy: ImportStrategy.merge);
      // Merge skips an investment that already exists: its snapshots are
      // untouched and none is attached to it.
      expect(
        {
          for (final s in valuations.docs.values)
            if (s.investmentId == 'gold') s.id,
        },
        {'g1', 'g2', 'g3', 'g4'},
      );

      wipe();
      await importZip(bytes);
      expect(valuations.docs.keys.toSet().intersection(before), isEmpty);
    });
  });

  group('the legacy row', () {
    test('an investment with only a legacy value exports exactly one row, '
        'as before', () async {
      repo.seed(
        investments: [
          testInvestment(
            'gold',
            compatValue: 125000.55,
            compatDate: DateTime(2026, 10, 1),
          ).copyWith(name: 'SGB 2031'),
        ],
        cashFlows: [_invest('gold')],
      );
      final rows = valuationRows((await export()).bytes);
      expect(rows, hasLength(2));
      expect(rows[1].sublist(0, 5), [
        'SGB 2031',
        'false',
        '2026-10-01',
        '125000.55',
        'INR',
      ]);
      expect(rows[1][5], isEmpty, reason: 'no snapshot id');
      expect(rows[1][6], 'carryingValue');
      expect(rows[1][7], 'manual');
      expect(rows[1][8], isEmpty);
    });

    test('a value an older app edited after the snapshots is exported last, '
        'as what the app shows', () async {
      repo.seed(
        investments: [
          testInvestment(
            'gold',
            compatValue: 140000,
            compatDate: DateTime(2026, 8, 1),
            updatedAt: DateTime.utc(2026, 8, 2),
          ).copyWith(name: 'SGB 2031'),
        ],
        cashFlows: [_invest('gold')],
      );
      valuations.docs['g1'] = testSnapshot(
        'g1',
        investmentId: 'gold',
        amount: 130000,
        date: DateTime(2026, 6, 1),
        updatedAt: DateTime.utc(2026, 6, 2),
      );
      final rows = valuationRows((await export()).bytes);
      expect(rows.skip(1).map((r) => r[3]), ['130000.0', '140000.0']);
    });

    test('a file from before the new columns imports as manual carrying '
        'values with new ids', () async {
      final result = await importZip(
        _zip({
          'cashflows.csv':
              '${_cashFlowsHeader}2025-10-01,SGB 2031,INVEST,100000,INR,,gold,open\n',
          'valuations.csv':
              '${_legacyHeader}SGB 2031,false,2026-10-01,125000.55,INR\n',
        }),
      );
      expect(result.errors, isEmpty);
      final snapshot = (await imported()).single;
      expect(snapshot.kind, ValuationKind.carryingValue);
      expect(snapshot.provenance, ValuationProvenance.manual);
      expect(snapshot.amount, 125000.55);
      expect(snapshot.id, isNotEmpty);
      final investment = (await repo.getAllInvestments()).single;
      expect(investment.currentValue, 125000.55);
      expect(snapshot.investmentId, investment.id);
    });

    test('an old file\'s value of an investment with no cash flows creates '
        'a plain investment holding it', () async {
      final result = await importZip(
        _zip({
          'cashflows.csv': _cashFlowsHeader,
          'valuations.csv':
              '${_legacyHeader}Plot in Pune,false,2026-10-01,500000,INR\n',
        }),
      );
      expect(result.errors, isEmpty);
      final investment = (await repo.getAllInvestments()).single;
      expect(investment.name, 'Plot in Pune');
      expect(investment.type, InvestmentType.other);
      expect(investment.status, InvestmentStatus.open);
      expect(investment.currency, 'INR');
      expect((await imported()).single.amount, 500000);
    });
  });

  group('rows that cannot be trusted are skipped (plan test 15)', () {
    Future<ZipImportResult> importRows(String rows) => importZip(
      _zip({
        'cashflows.csv':
            '${_cashFlowsHeader}2025-10-01,SGB 2031,INVEST,100000,INR,,gold,open\n',
        'valuations.csv': '$_newHeader$rows',
      }),
    );

    test('with warnings that hold no amount', () async {
      final result = await importRows(
        'SGB 2031,false,2026-01-01,-5,INR,,carryingValue,manual,,gold,open\n'
        'SGB 2031,false,2026-01-02,abc,INR,,carryingValue,manual,,gold,open\n'
        'SGB 2031,false,2999-01-01,77777,INR,,carryingValue,manual,,gold,open\n'
        'SGB 2031,false,2026-01-03,88888,INR,,fairValue,manual,,gold,open\n'
        'SGB 2031,false,2026-01-04,99999,INR,,carryingValue,estimate,,gold,open\n'
        'SGB 2031,false,2026-01-05,66666,,,carryingValue,manual,,gold,open\n'
        'SGB 2031,false,2026-01-06,55555,USD,,carryingValue,manual,,gold,open\n',
      );
      expect(await imported(), isEmpty);
      expect(result.warnings, hasLength(greaterThanOrEqualTo(6)));
      final text = result.warnings.join('\n');
      for (final amount in ['77777', '88888', '99999', '66666', '55555']) {
        expect(text, isNot(contains(amount)));
      }
      expect(result.errors, isEmpty);
      final investment = (await repo.getAllInvestments()).single;
      expect(investment.currentValue, isNull);
    });

    test('a second baseline for the same investment is skipped', () async {
      // Two investments of one name collapse into one on import.
      final result = await importRows(
        'SGB 2031,false,2026-01-01,100,INR,a,carryingValue,openingBaseline,,gold,open\n'
        'SGB 2031,false,2026-02-01,200,INR,b,carryingValue,openingBaseline,,gold,open\n',
      );
      final all = await imported();
      expect(all, hasLength(1));
      expect(all.single.amount, 100);
      expect(result.warnings, isNotEmpty);
    });

    test('no more than 100 snapshots are kept per investment', () async {
      final rows = StringBuffer();
      for (var i = 0; i < 105; i++) {
        final day = DateTime(2025, 1, 1).add(Duration(days: i));
        rows.writeln(
          'SGB 2031,false,${day.toIso8601String().split('T').first},${i + 1},INR,'
          ',carryingValue,manual,,gold,open',
        );
      }
      final result = await importRows(rows.toString());
      final all = await imported();
      expect(all, hasLength(100));
      // The newest are kept.
      expect(all.map((s) => s.amount).reduce((a, b) => a > b ? a : b), 105);
      expect(result.warnings, isNotEmpty);
    });

    test('a blank currency never reaches money rounding', () async {
      final result = await importRows(
        'SGB 2031,false,2026-01-01,100,,,carryingValue,manual,,gold,open\n',
      );
      expect(result.errors, isEmpty);
      expect(await imported(), isEmpty);
    });

    test('a file with no usable header leaves the values out', () async {
      final result = await importZip(
        _zip({
          'cashflows.csv':
              '${_cashFlowsHeader}2025-10-01,SGB 2031,INVEST,100000,INR,,gold,open\n',
          'valuations.csv': 'Name,Value\nSGB 2031,5\n',
        }),
      );
      expect(result.warnings, isNotEmpty);
      expect(await imported(), isEmpty);
    });
  });

  group('merge', () {
    test('an investment that already exists keeps its own values', () async {
      repo.seed(
        investments: [testInvestment('x').copyWith(name: 'Plot in Pune')],
      );
      final result = await importZip(
        _zip({
          'cashflows.csv': _cashFlowsHeader,
          'valuations.csv':
              '${_newHeader}Plot in Pune,false,2026-01-01,500000,INR,,marketValue,openingBaseline,,gold,open\n',
        }),
        strategy: ImportStrategy.merge,
      );
      expect(result.investmentsImported, 0);
      expect(await imported(), isEmpty);
      expect((await repo.getAllInvestments()).single.currentValue, isNull);
    });
  });
}
