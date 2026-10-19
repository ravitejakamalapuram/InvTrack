// A24 (#768): a snapshot of an investment whose saved currency differs from
// its cash flows' currency is routed by the saved currency on Replace.
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
  test(
    'Replace keeps a USD snapshot of a USD investment with INR flows',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
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

      await repo.bulkImport(
        investments: [
          InvestmentEntity(
            id: 'a',
            name: 'Dollar note',
            type: InvestmentType.fixedDeposit,
            status: InvestmentStatus.open,
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
            currency: 'USD',
          ),
        ],
        cashFlows: [
          CashFlowEntity(
            id: 'f',
            investmentId: 'a',
            date: DateTime(2026, 2, 1),
            type: CashFlowType.invest,
            amount: 1000,
            createdAt: DateTime(2026, 2, 1),
            currency: 'INR',
          ),
        ],
      );
      final snapshot = InvestmentValuationSnapshot(
        id: 'abcdefabcdefabcdefabcdef',
        investmentId: 'a',
        amount: 1100,
        currency: 'USD',
        effectiveDate: DateTime(2026, 3, 1),
        kind: ValuationKind.marketValue,
        provenance: ValuationProvenance.manual,
        createdAt: DateTime(2026, 3, 1),
      );
      await valuations.save(snapshot, mirror: CompatMirror.of('a', snapshot));
      final zip = await export.exportAsZipBytes();

      await repo.bulkDelete(['a']);
      // Restore into an account with no valuations, so only the import can
      // put the snapshot back.
      valuations.docs.clear();
      final result = await import.importFromZip(
        zip.bytes,
        ImportStrategy.replace,
        baseCurrency: 'INR',
      );
      expect(result.errors, isEmpty);

      final back = (await repo.getAllInvestments()).single;
      expect(back.currency, 'USD');
      final restored = await valuations.getAll();
      expect(restored.where((s) => s.isLive), hasLength(1));
      expect(restored.single.currency, 'USD');
      expect(restored.single.investmentId, back.id);
      expect(restored.single.amount, 1100);
      expect(back.currentValue, 1100);
    },
  );
}
