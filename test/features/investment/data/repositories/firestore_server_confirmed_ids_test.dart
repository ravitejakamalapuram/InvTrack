// #964: the ids of every investment, active and archived, as the server has
// them. The orphaned valuation sweep judges a valuation snapshot from this, so
// an answer from the cache, or one with a write of this device still pending,
// must never be taken for the server's: a partially loaded list would make
// valid snapshots look orphaned.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'investment_snapshot_mocks.dart';

void main() {
  setUpAll(registerInvestmentSnapshotFallbacks);

  late InvestmentFirestoreMock firestore;

  setUp(() => firestore = InvestmentFirestoreMock());
  tearDown(() => firestore.close());

  List<Set<String>> collect(Stream<Set<String>> stream) {
    final emitted = <Set<String>>[];
    final subscription = stream.listen(emitted.add);
    addTearDown(subscription.cancel);
    return emitted;
  }

  Map<String, Map<String, dynamic>> docs(List<String> ids) => {
    for (final id in ids) id: investmentDoc('Name of $id'),
  };

  test('emits the active and archived ids together once the server has '
      'answered for both', () async {
    final emitted = collect(
      firestore.repository().watchServerConfirmedInvestmentIds(),
    );

    firestore.activeSnapshots.add(
      querySnapshot(docs: docs(['live-1', 'live-2']), fromCache: false),
    );
    await pumpEventQueue();
    expect(emitted, isEmpty, reason: 'the archived side has not answered');

    firestore.archivedSnapshots.add(
      querySnapshot(docs: docs(['archived-1']), fromCache: false),
    );
    await pumpEventQueue();

    expect(emitted, [
      {'live-1', 'live-2', 'archived-1'},
    ]);
  });

  test('emits nothing while either side only has a cache answer', () async {
    final emitted = collect(
      firestore.repository().watchServerConfirmedInvestmentIds(),
    );

    firestore.activeSnapshots.add(
      querySnapshot(docs: docs(['live-1']), fromCache: true),
    );
    firestore.archivedSnapshots.add(
      querySnapshot(docs: docs(['archived-1']), fromCache: false),
    );
    await pumpEventQueue();
    expect(emitted, isEmpty);

    firestore.archivedSnapshots.add(
      querySnapshot(docs: docs(['archived-1']), fromCache: true),
    );
    await pumpEventQueue();
    expect(emitted, isEmpty);
  });

  test('emits when the server confirms what the cache already showed (a '
      'metadata-only change)', () async {
    final emitted = collect(
      firestore.repository().watchServerConfirmedInvestmentIds(),
    );

    firestore.activeSnapshots
      ..add(querySnapshot(docs: docs(['live-1']), fromCache: true))
      ..add(
        querySnapshot(docs: docs(['live-1']), fromCache: false, changed: false),
      );
    firestore.archivedSnapshots.add(
      querySnapshot(fromCache: false, changed: false),
    );
    await pumpEventQueue();

    expect(emitted, [
      {'live-1'},
    ]);
    verify(
      () => firestore.orderedQueries[firestore.active]!.snapshots(
        includeMetadataChanges: true,
        source: any(named: 'source'),
      ),
    ).called(greaterThan(0));
    verify(
      () => firestore.orderedQueries[firestore.archived]!.snapshots(
        includeMetadataChanges: true,
        source: any(named: 'source'),
      ),
    ).called(greaterThan(0));
  });

  test('emits nothing while a write of this device is still pending', () async {
    final emitted = collect(
      firestore.repository().watchServerConfirmedInvestmentIds(),
    );

    firestore.activeSnapshots.add(
      querySnapshot(
        docs: docs(['live-1']),
        fromCache: false,
        hasPendingWrites: true,
      ),
    );
    firestore.archivedSnapshots.add(querySnapshot(fromCache: false));
    await pumpEventQueue();

    expect(emitted, isEmpty);
  });

  test('passes a listener error through', () async {
    final errors = <Object>[];
    final subscription = firestore
        .repository()
        .watchServerConfirmedInvestmentIds()
        .listen((_) {}, onError: errors.add);
    addTearDown(subscription.cancel);

    firestore.activeSnapshots.addError(StateError('permission-denied'));
    await pumpEventQueue();

    expect(errors, hasLength(1));
  });
}
