// A24 (#1048): valuations.csv and custom_types.json name an investment by id,
// so two investments with the same name and currency keep their own values
// and custom type through Replace and Merge.
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

  Future<void> roundTrip(ImportStrategy strategy) async {
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

    await repo.bulkDelete(['a', 'b']);
    valuations.docs.clear();
    final result = await import.importFromZip(
      zip.bytes,
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
}
