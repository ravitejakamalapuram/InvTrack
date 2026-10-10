// #941: the valuations listener is opened only when the feature is on and a
// user is signed in. With the flag off nothing is read, so the app behaves
// exactly as before; with it on, only live snapshots of active investments
// reach the calculators.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/investment/domain/repositories/valuation_repository.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/valuation_providers.dart';

import 'in_memory_valuation_repository.dart';
import 'valuation_fixtures.dart';

void main() {
  late InMemoryValuationRepository repo;

  setUp(() {
    repo = InMemoryValuationRepository();
    addTearDown(repo.dispose);
  });

  ProviderContainer container({
    bool enabled = true,
    bool signedIn = true,
    List<InvestmentEntity>? investments,
  }) {
    final c = ProviderContainer(
      overrides: [
        valuationSnapshotsActiveProvider.overrideWithValue(enabled),
        isAuthenticatedProvider.overrideWithValue(signedIn),
        valuationRepositoryProvider.overrideWithValue(repo),
        allInvestmentsProvider.overrideWith(
          (ref) => Stream.value(
            investments ?? [testInvestment('i1'), testInvestment('i2')],
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    // A provider with no listener is paused (Riverpod 3), so keep these two.
    for (final provider in [
      allValuationSnapshotsProvider,
      allInvestmentsProvider,
    ]) {
      final sub = c.listen(provider, (_, _) {});
      addTearDown(sub.close);
    }
    return c;
  }

  final live = testSnapshot('a', amount: 1, date: DateTime(2026, 1, 1));

  test('the flag off opens no listener and gives no snapshots', () async {
    repo.docs['a'] = live;
    final c = container(enabled: false);
    expect(await c.read(allValuationSnapshotsProvider.future), isEmpty);
    expect(repo.watchCount, 0);
    // The by-investment view is ready at once, not loading.
    final byInvestment = c.read(valuationSnapshotsByInvestmentProvider);
    expect(byInvestment.hasValue, isTrue);
    expect(byInvestment.requireValue, isEmpty);
    expect(repo.watchCount, 0);
  });

  test('signed out opens no listener', () async {
    repo.docs['a'] = live;
    final c = container(signedIn: false);
    expect(await c.read(allValuationSnapshotsProvider.future), isEmpty);
    expect(repo.watchCount, 0);
  });

  test('the flag on streams every snapshot of the signed-in user', () async {
    repo.docs['a'] = live;
    final c = container();
    expect(await c.read(allValuationSnapshotsProvider.future), [live]);
    expect(repo.watchCount, 1);
  });

  test('only live snapshots of active investments are valid', () async {
    final archived = testSnapshot(
      'b',
      investmentId: 'gone',
      amount: 2,
      date: DateTime(2026, 1, 1),
    );
    final cleared = testSnapshot(
      'c',
      amount: 3,
      date: DateTime(2026, 2, 1),
      deletedAt: DateTime.utc(2026, 2, 2),
    );
    repo.docs.addAll({'a': live, 'b': archived, 'c': cleared});
    final c = container();
    await c.read(allValuationSnapshotsProvider.future);
    await c.read(allInvestmentsProvider.future);

    final valid = c.read(validValuationSnapshotsProvider).requireValue;
    expect(valid.map((s) => s.id), ['a']);
  });

  test('snapshots are grouped by investment, newest first', () async {
    final older = testSnapshot('o', amount: 1, date: DateTime(2026, 1, 1));
    final newer = testSnapshot('n', amount: 2, date: DateTime(2026, 6, 1));
    final other = testSnapshot(
      'x',
      investmentId: 'i2',
      amount: 3,
      date: DateTime(2026, 3, 1),
    );
    repo.docs.addAll({'o': older, 'n': newer, 'x': other});
    final c = container();
    await c.read(allValuationSnapshotsProvider.future);
    await c.read(allInvestmentsProvider.future);

    final map = c.read(valuationSnapshotsByInvestmentProvider).requireValue;
    expect(map.keys, unorderedEquals(['i1', 'i2']));
    expect(
      c.read(investmentValuationSnapshotsProvider('i1')).map((s) => s.id),
      ['n', 'o'],
    );
    expect(c.read(investmentValuationSnapshotsProvider('none')), isEmpty);
  });

  test('the by-investment view waits for the snapshots', () {
    final c = container();
    expect(c.read(valuationSnapshotsByInvestmentProvider).isLoading, isTrue);
  });

  test(
    'a snapshot cleared on this device leaves the valid ones at once',
    () async {
      repo.docs['a'] = live;
      final c = container();
      await c.read(allValuationSnapshotsProvider.future);
      await c.read(allInvestmentsProvider.future);
      expect(
        c.read(validValuationSnapshotsProvider).requireValue,
        hasLength(1),
      );

      await repo.softDelete(
        live,
        mirror: const CompatMirror(investmentId: 'i1'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(c.read(validValuationSnapshotsProvider).requireValue, isEmpty);
    },
  );
}
