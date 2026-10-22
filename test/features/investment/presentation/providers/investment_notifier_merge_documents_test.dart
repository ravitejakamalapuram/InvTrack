// A23 / INV-07: merging deletes the source investments, and with them their
// documents. The attachments must follow into the merged investment: record
// and file, the files being under the investment id.
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/document_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_notifier.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';

import '../../../../mocks/fake_documents.dart';
import '../../../../mocks/mock_analytics_service.dart';
import '../../valuation/in_memory_valuation_repository.dart';
import '../../../../mocks/mock_notification_service.dart';
import '../../data/repositories/mock_investment_repository.dart';

InvestmentEntity _fd(String id) => InvestmentEntity(
  id: id,
  name: 'FD $id',
  type: InvestmentType.fixedDeposit,
  status: InvestmentStatus.open,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  currency: 'INR',
);

DocumentEntity _doc(String id, String investmentId, String path) =>
    DocumentEntity(
      id: id,
      investmentId: investmentId,
      name: 'Receipt $id',
      fileName: '$id.pdf',
      type: DocumentType.receipt,
      mimeType: 'application/pdf',
      localPath: path,
      fileSize: 3,
      createdAt: DateTime(2026, 2, 1),
      updatedAt: DateTime(2026, 2, 1),
    );

void main() {
  late FakeInvestmentRepository repo;
  late FakeDocumentRepository docs;
  late FakeDocumentStorageService storage;
  late ProviderContainer container;

  setUp(() async {
    repo = FakeInvestmentRepository();
    docs = FakeDocumentRepository();
    storage = FakeDocumentStorageService();
    container = ProviderContainer(
      overrides: [
        investmentRepositoryProvider.overrideWithValue(repo),
        valuationRepositoryProvider.overrideWithValue(
          InMemoryValuationRepository(),
        ),
        documentRepositoryProvider.overrideWithValue(docs),
        documentStorageServiceProvider.overrideWithValue(storage),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        isAuthenticatedProvider.overrideWithValue(true),
        currencyCodeProvider.overrideWithValue('INR'),
      ],
    );
    for (final id in ['a', 'b', 'c']) {
      await repo.createInvestment(_fd(id));
    }
    // a and b each hold a file; c is not merged and keeps its own.
    for (final (docId, invId) in [('d1', 'a'), ('d2', 'b'), ('d3', 'c')]) {
      final path = await storage.saveDocument(
        investmentId: invId,
        documentId: docId,
        fileName: '$docId.pdf',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      docs.records[docId] = _doc(docId, invId, path);
    }
  });

  tearDown(() {
    container.dispose();
    repo.reset();
  });

  Future<void> merge() async {
    container.listen(allInvestmentsProvider, (_, _) {});
    await container.read(allInvestmentsProvider.future);
    await container.read(investmentNotifierProvider.notifier).mergeInvestments([
      'a',
      'b',
    ], 'Merged FD');
  }

  group('merging investments with documents', () {
    test(
      'the documents of the merged investments move to the new one',
      () async {
        await merge();

        final mergedId = repo.investments.singleWhere((i) => i.id != 'c').id;
        final moved = docs.records.values
            .where((d) => d.investmentId == mergedId)
            .toList();
        expect(
          moved.map((d) => d.name),
          unorderedEquals(['Receipt d1', 'Receipt d2']),
        );
        for (final d in moved) {
          expect(d.localPath, startsWith('$mergedId/'));
          expect(storage.files[d.localPath], [1, 2, 3]);
        }
      },
    );

    test('the old files and records are gone, other investments are '
        'untouched', () async {
      await merge();

      expect(
        docs.records.values.where((d) => {'a', 'b'}.contains(d.investmentId)),
        isEmpty,
      );
      expect(
        storage.files.keys.where(
          (p) => p.startsWith('a/') || p.startsWith('b/'),
        ),
        isEmpty,
      );
      expect(docs.records['d3']?.investmentId, 'c');
      expect(storage.files.containsKey(docs.records['d3']!.localPath), isTrue);
    });

    test('a document that cannot be carried over aborts the merge and leaves '
        'the sources whole', () async {
      docs.failOnCreate = true;

      await expectLater(merge(), throwsException);

      expect(
        repo.investments.map((i) => i.id),
        unorderedEquals(['a', 'b', 'c']),
      );
      expect(docs.records.keys, unorderedEquals(['d1', 'd2', 'd3']));
      expect(storage.files.keys.length, 3);
    });

    test('a failing document cleanup still removes the half-merged '
        'investment', () async {
      docs.failOnCreate = true;
      docs.failOnDeleteByInvestment = true;
      final originalPaths = storage.files.keys.toList();

      await expectLater(merge(), throwsException);

      expect(
        repo.investments.map((i) => i.id),
        unorderedEquals(['a', 'b', 'c']),
      );
      expect(storage.files.keys, unorderedEquals(originalPaths));
    });

    test(
      'a document whose file is missing keeps its record and path',
      () async {
        storage.files.remove(docs.records['d1']!.localPath);
        final oldPath = docs.records['d1']!.localPath;

        await merge();

        final mergedId = repo.investments.singleWhere((i) => i.id != 'c').id;
        final moved = docs.records.values.singleWhere(
          (d) => d.investmentId == mergedId && d.name == 'Receipt d1',
        );
        expect(moved.localPath, oldPath);
      },
    );
  });
}
