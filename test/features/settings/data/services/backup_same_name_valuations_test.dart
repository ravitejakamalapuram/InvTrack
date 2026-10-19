// A24 (#1048): valuations.csv and custom_types.json name an investment by id,
// so two investments with the same name and currency keep their own values
// and custom type through Replace and Merge.
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/performance/performance_service.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/document_repository.dart';
import 'package:inv_tracker/features/investment/domain/repositories/valuation_repository.dart';
import 'package:inv_tracker/features/settings/data/services/data_export_service.dart';
import 'package:inv_tracker/features/settings/data/services/data_import_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../goals/data/repositories/mock_goal_repository.dart';
import '../../../investment/data/repositories/mock_investment_repository.dart';
import '../../../investment/valuation/in_memory_valuation_repository.dart';

class _NoTrace extends Mock implements PerformanceService {
  @override
  Future<T> trackOperation<T>(
    String traceName,
    Future<T> Function() operation, {
    Map<String, int>? metrics,
    Map<String, String>? attributes,
  }) => operation();
}

class _Docs extends Mock implements DocumentRepository {}

class _Storage extends Mock implements DocumentStorageService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> roundTrip(
    ImportStrategy strategy, {
    Uint8List Function(Uint8List zip)? tamper,
  }) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '/tmp',
        );
    final repo = FakeInvestmentRepository();
    final goals = FakeGoalRepository();
    final valuations = InMemoryValuationRepository();
    addTearDown(valuations.dispose);
    final docs = _Docs();
    when(
      () => docs.getDocumentsByInvestment(any()),
    ).thenAnswer((_) async => []);
    final storage = _Storage();
    final perf = _NoTrace();
    final export = DataExportService(
      investmentRepository: repo,
      goalRepository: goals,
      documentRepository: docs,
      documentStorageService: storage,
      valuationRepository: valuations,
      performanceService: perf,
    );
    final import = DataImportService(
      investmentRepository: repo,
      goalRepository: goals,
      documentRepository: docs,
      documentStorageService: storage,
      valuationRepository: valuations,
      performanceService: perf,
    );

    InvestmentEntity investment(String id, {String? customTypeLabel}) =>
        InvestmentEntity(
          id: id,
          name: 'Gold',
          type: InvestmentType.other,
          status: InvestmentStatus.open,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
          currency: 'INR',
          customTypeLabel: customTypeLabel,
        );
    CashFlowEntity invest(String id, String investmentId, double amount) =>
        CashFlowEntity(
          id: id,
          investmentId: investmentId,
          date: DateTime(2026, 2, 1),
          type: CashFlowType.invest,
          amount: amount,
          createdAt: DateTime(2026, 2, 1),
          currency: 'INR',
        );
    InvestmentValuationSnapshot snapshot(
      String id,
      String investmentId,
      double amount,
    ) => InvestmentValuationSnapshot(
      id: id,
      investmentId: investmentId,
      amount: amount,
      currency: 'INR',
      effectiveDate: DateTime(2026, 3, 1),
      kind: ValuationKind.marketValue,
      provenance: ValuationProvenance.manual,
      createdAt: DateTime(2026, 3, 1),
    );

    await repo.bulkImport(
      investments: [
        investment('a', customTypeLabel: 'Art'),
        investment('b'),
      ],
      cashFlows: [invest('fa', 'a', 1000), invest('fb', 'b', 2000)],
    );
    final first = snapshot('aaaaaaaaaaaaaaaaaaaaaaaa', 'a', 1100);
    final second = snapshot('bbbbbbbbbbbbbbbbbbbbbbbb', 'b', 2500);
    await valuations.save(first, mirror: CompatMirror.of('a', first));
    await valuations.save(second, mirror: CompatMirror.of('b', second));
    final zip = await export.exportAsZipBytes();
    final bytes = tamper == null ? zip.bytes : tamper(zip.bytes);

    await repo.bulkDelete(['a', 'b']);
    valuations.docs.clear();
    final result = await import.importFromZip(
      bytes,
      strategy,
      baseCurrency: 'INR',
    );
    expect(result.errors, isEmpty);

    final restored = await repo.getAllInvestments();
    expect(restored, hasLength(2));
    final snapshots = (await valuations.getAll()).where((s) => s.isLive);
    expect(snapshots, hasLength(2));
    for (final inv in restored) {
      final flows = await repo.getCashFlowsByInvestment(inv.id);
      final invested = flows.single.amount;
      final own = snapshots.where((s) => s.investmentId == inv.id).toList();
      // 1000 invested went with the 1100 value and the Art type; 2000 with
      // the 2500 value and no type.
      expect(own, hasLength(1), reason: 'invested $invested');
      expect(own.single.amount, invested == 1000 ? 1100 : 2500);
      expect(inv.currentValue, invested == 1000 ? 1100 : 2500);
      expect(inv.customTypeLabel, invested == 1000 ? 'Art' : isNull);
    }
  }

  test('Replace keeps same-name investments apart in values and type', () {
    return roundTrip(ImportStrategy.replace);
  });

  test('Merge keeps same-name investments apart in values and type', () {
    return roundTrip(ImportStrategy.merge);
  });

  // An investments.json row Merge cannot read is skipped; its cash-flow group
  // then has no saved investment, and must not take the dated values of the
  // other same-name investment.
  test(
    'Merge: a skipped investments.json row does not take its twin values',
    () {
      Uint8List dropRowOfA(Uint8List zip) {
        final archive = ZipDecoder().decodeBytes(zip);
        final out = Archive();
        for (final f in archive.files) {
          if (f.name == 'investments.json') {
            final json =
                jsonDecode(utf8.decode(f.content as List<int>))
                    as Map<String, dynamic>;
            final rows = json['investments'] as List;
            final i = rows.indexWhere((r) => (r as Map)['id'] == 'a');
            rows[i] = 'unreadable';
            final data = utf8.encode(jsonEncode(json));
            out.addFile(ArchiveFile(f.name, data.length, data));
          } else {
            out.addFile(f);
          }
        }
        return Uint8List.fromList(ZipEncoder().encode(out)!);
      }

      return roundTrip(ImportStrategy.merge, tamper: dropRowOfA);
    },
  );

  group('valuation-only investments', () {
    late FakeInvestmentRepository repo;
    late InMemoryValuationRepository valuations;
    late DataExportService export;
    late DataImportService import;

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => '/tmp',
          );
      repo = FakeInvestmentRepository();
      valuations = InMemoryValuationRepository();
      addTearDown(valuations.dispose);
      final docs = _Docs();
      when(
        () => docs.getDocumentsByInvestment(any()),
      ).thenAnswer((_) async => []);
      final storage = _Storage();
      final perf = _NoTrace();
      export = DataExportService(
        investmentRepository: repo,
        goalRepository: FakeGoalRepository(),
        documentRepository: docs,
        documentStorageService: storage,
        valuationRepository: valuations,
        performanceService: perf,
      );
      import = DataImportService(
        investmentRepository: repo,
        goalRepository: FakeGoalRepository(),
        documentRepository: docs,
        documentStorageService: storage,
        valuationRepository: valuations,
        performanceService: perf,
      );
    });

    InvestmentEntity gold(String id, {String? customTypeLabel}) =>
        InvestmentEntity(
          id: id,
          name: 'Gold',
          type: InvestmentType.other,
          status: InvestmentStatus.open,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
          currency: 'INR',
          customTypeLabel: customTypeLabel,
        );
    CashFlowEntity invest(String id, String investmentId, double amount) =>
        CashFlowEntity(
          id: id,
          investmentId: investmentId,
          date: DateTime(2026, 2, 1),
          type: CashFlowType.invest,
          amount: amount,
          createdAt: DateTime(2026, 2, 1),
          currency: 'INR',
        );
    Future<void> value(String id, String investmentId, double amount) {
      final s = InvestmentValuationSnapshot(
        id: id,
        investmentId: investmentId,
        amount: amount,
        currency: 'INR',
        effectiveDate: DateTime(2026, 3, 1),
        kind: ValuationKind.marketValue,
        provenance: ValuationProvenance.manual,
        createdAt: DateTime(2026, 3, 1),
      );
      return valuations.save(s, mirror: CompatMirror.of(investmentId, s));
    }

    test(
      'Replace restores the custom type of a valuation-only investment',
      () async {
        await repo.bulkImport(
          investments: [gold('v', customTypeLabel: 'Art')],
          cashFlows: const [],
        );
        await value('cccccccccccccccccccccccc', 'v', 700);
        final zip = await export.exportAsZipBytes();

        await repo.bulkDelete(['v']);
        valuations.docs.clear();
        final result = await import.importFromZip(
          zip.bytes,
          ImportStrategy.replace,
          baseCurrency: 'INR',
        );
        expect(result.errors, isEmpty);

        final restored = await repo.getAllInvestments();
        expect(restored.single.customTypeLabel, 'Art');
        expect(restored.single.currentValue, 700);
      },
    );

    test(
      'Merge restores a valuation-only twin of an existing investment',
      () async {
        await repo.bulkImport(
          investments: [gold('a'), gold('v')],
          cashFlows: [invest('fa', 'a', 1000)],
        );
        await value('aaaaaaaaaaaaaaaaaaaaaaaa', 'a', 1100);
        await value('cccccccccccccccccccccccc', 'v', 700);
        final zip = await export.exportAsZipBytes();

        // The account keeps one Gold with cash flows; the backup holds two.
        await repo.bulkDelete(['a', 'v']);
        valuations.docs.clear();
        await repo.bulkImport(
          investments: [gold('dest')],
          cashFlows: [invest('fd', 'dest', 1000)],
        );
        final result = await import.importFromZip(
          zip.bytes,
          ImportStrategy.merge,
          baseCurrency: 'INR',
        );
        expect(result.errors, isEmpty);

        final all = await repo.getAllInvestments();
        expect(all, hasLength(2));
        final restored = all.singleWhere((i) => i.id != 'dest');
        final snapshots = (await valuations.getAll())
            .where((s) => s.isLive)
            .toList();
        expect(snapshots, hasLength(1));
        expect(snapshots.single.investmentId, restored.id);
        expect(snapshots.single.amount, 700);
        expect(all.singleWhere((i) => i.id == 'dest').currentValue, isNull);
      },
    );
  });
}
