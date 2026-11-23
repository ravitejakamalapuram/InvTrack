// #1162: merging deletes the source investments one by one. A failed delete
// must not strand the merged copy next to undeleted sources (every amount
// would count twice).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_notifier.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';

import '../../../../mocks/fake_documents.dart';
import '../../../../mocks/mock_analytics_service.dart';
import '../../../../mocks/mock_notification_service.dart';
import '../../data/repositories/mock_investment_repository.dart';
import '../../valuation/in_memory_valuation_repository.dart';

InvestmentEntity _fd(String id) => InvestmentEntity(
  id: id,
  name: 'FD $id',
  type: InvestmentType.fixedDeposit,
  status: InvestmentStatus.open,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  currency: 'INR',
);

/// A repository whose delete fails for the listed ids.
class _FailingDeleteRepository extends FakeInvestmentRepository {
  final failFor = <String>{};

  @override
  Future<void> deleteInvestment(String id) async {
    if (failFor.contains(id)) throw Exception('delete failed for $id');
    await super.deleteInvestment(id);
  }
}

void main() {
  late _FailingDeleteRepository repo;
  late ProviderContainer container;

  setUp(() async {
    repo = _FailingDeleteRepository();
    container = ProviderContainer(
      overrides: [
        investmentRepositoryProvider.overrideWithValue(repo),
        valuationRepositoryProvider.overrideWithValue(
          InMemoryValuationRepository(),
        ),
        documentRepositoryProvider.overrideWithValue(FakeDocumentRepository()),
        documentStorageServiceProvider.overrideWithValue(
          FakeDocumentStorageService(),
        ),
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

  test('when no source can be deleted, the merge is undone and the sources '
      'stay whole', () async {
    repo.failFor.addAll(['a', 'b']);

    await expectLater(merge(), throwsException);

    expect(
      repo.investments.map((i) => i.id),
      unorderedEquals(['a', 'b', 'c']),
    );
  });

  test('when one source cannot be deleted, the rest are still removed and '
      'the failure names what is left', () async {
    repo.failFor.add('b');

    await expectLater(
      merge(),
      throwsA(
        isA<MergeSourcesNotRemovedException>().having(
          (e) => e.remainingIds,
          'remainingIds',
          ['b'],
        ),
      ),
    );

    final ids = repo.investments.map((i) => i.id).toList();
    expect(ids, isNot(contains('a')));
    expect(ids, contains('b'));
    expect(ids, contains('c'));
    // The merged investment is kept: it holds the data of both sources.
    expect(repo.investments.length, 3);
  });
}
