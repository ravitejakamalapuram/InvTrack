// A121 (#895): on a fresh install with no network, Firestore answers the
// investments listener from an empty cache. That says nothing about the
// account, but it reached Overview as "no investments", which then offered an
// existing user sample data. Only the new-account decision may wait for the
// server: the investment lists keep showing what the cache holds, including
// an empty list, so offline screens still reach their empty states.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:mocktail/mocktail.dart';

import 'investment_snapshot_mocks.dart';

void main() {
  setUpAll(registerInvestmentSnapshotFallbacks);

  late InvestmentFirestoreMock firestore;

  setUp(() => firestore = InvestmentFirestoreMock());
  tearDown(() => firestore.close());

  /// Collects what [stream] emits, so a test can check it after each event.
  List<T> collect<T>(Stream<T> stream) {
    final emitted = <T>[];
    final subscription = stream.listen(emitted.add);
    addTearDown(subscription.cancel);
    return emitted;
  }

  List<List<String>> names(List<List<InvestmentEntity>> emitted) => [
    for (final list in emitted) [for (final i in list) i.name],
  ];

  for (final (label, watch, snapshots) in [
    (
      'watchAllInvestments',
      () => firestore.repository().watchAllInvestments(),
      () => firestore.activeSnapshots,
    ),
    (
      'watchArchivedInvestments',
      () => firestore.repository().watchArchivedInvestments(),
      () => firestore.archivedSnapshots,
    ),
  ]) {
    group(label, () {
      test('emits an empty snapshot from the cache at once, so an offline '
          'list reaches its empty state', () async {
        final emitted = collect(watch());

        snapshots().add(querySnapshot(fromCache: true));
        await pumpEventQueue();

        expect(names(emitted), [<String>[]]);
      });

      test('emits a cached snapshot with documents at once', () async {
        final emitted = collect(watch());

        snapshots().add(
          querySnapshot(
            docs: {'inv-1': investmentDoc('HDFC FD')},
            fromCache: true,
          ),
        );
        await pumpEventQueue();

        expect(names(emitted), [
          ['HDFC FD'],
        ]);
      });

      test('passes a listener error through', () async {
        final errors = <Object>[];
        final subscription = watch().listen((_) {}, onError: errors.add);
        addTearDown(subscription.cancel);

        snapshots().addError(StateError('permission-denied'));
        await pumpEventQueue();

        expect(errors, hasLength(1));
      });
    });
  }

  group('watchHasNoInvestments', () {
    Stream<bool> watch() => firestore.repository().watchHasNoInvestments();

    test('emits nothing while both collections answer only from an empty '
        'cache, then true once the server confirms both are empty', () async {
      final emitted = collect(watch());

      firestore.activeSnapshots.add(querySnapshot(fromCache: true));
      firestore.archivedSnapshots.add(querySnapshot(fromCache: true));
      await pumpEventQueue();
      expect(emitted, isEmpty);

      // One collection confirmed is not enough.
      firestore.activeSnapshots.add(querySnapshot(fromCache: false));
      await pumpEventQueue();
      expect(emitted, isEmpty);

      firestore.archivedSnapshots.add(querySnapshot(fromCache: false));
      await pumpEventQueue();
      expect(emitted, [true]);

      // Going offline again changes only metadata: still known to be empty.
      firestore.activeSnapshots.add(querySnapshot(fromCache: true));
      firestore.archivedSnapshots.add(querySnapshot(fromCache: true));
      await pumpEventQueue();
      expect(emitted, [true]);
    });

    test('is false at once when the archived cache holds an investment, even '
        'with an empty active cache and no server answer', () async {
      final emitted = collect(watch());

      firestore.activeSnapshots.add(querySnapshot(fromCache: true));
      firestore.archivedSnapshots.add(
        querySnapshot(
          docs: {'inv-1': investmentDoc('Old FD')},
          fromCache: true,
        ),
      );
      await pumpEventQueue();

      expect(emitted, [false]);
    });

    test(
      'is false at once when the active cache holds an investment',
      () async {
        final emitted = collect(watch());

        firestore.activeSnapshots.add(
          querySnapshot(
            docs: {'inv-1': investmentDoc('Gold SGB')},
            fromCache: true,
          ),
        );
        firestore.archivedSnapshots.add(querySnapshot(fromCache: true));
        await pumpEventQueue();

        expect(emitted, [false]);
      },
    );

    test('turns false when an investment is added to a confirmed empty '
        'account, and does not repeat a value', () async {
      final emitted = collect(watch());

      firestore.activeSnapshots.add(querySnapshot(fromCache: false));
      firestore.archivedSnapshots.add(querySnapshot(fromCache: false));
      await pumpEventQueue();
      firestore.activeSnapshots.add(
        querySnapshot(
          docs: {'inv-1': investmentDoc('Chit fund')},
          fromCache: true,
        ),
      );
      firestore.activeSnapshots.add(
        querySnapshot(
          docs: {'inv-1': investmentDoc('Chit fund')},
          fromCache: false,
        ),
      );
      await pumpEventQueue();

      expect(emitted, [true, false]);
    });

    test('listens to metadata changes on both collections, so an empty '
        'server answer that follows an empty cache answer arrives', () async {
      collect(watch());
      await pumpEventQueue();

      for (final collection in [firestore.active, firestore.archived]) {
        verify(
          () => firestore.orderedQueries[collection]!.snapshots(
            includeMetadataChanges: true,
            source: any(named: 'source'),
          ),
        ).called(1);
      }
    });

    test('passes a listener error through', () async {
      final errors = <Object>[];
      final subscription = watch().listen((_) {}, onError: errors.add);
      addTearDown(subscription.cancel);

      firestore.activeSnapshots.add(querySnapshot(fromCache: true));
      firestore.archivedSnapshots.addError(StateError('permission-denied'));
      await pumpEventQueue();

      expect(errors, hasLength(1));
    });
  });
}
