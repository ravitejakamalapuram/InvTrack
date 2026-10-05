// A121 (#895): on a fresh install with no network, Firestore answers the
// investments listener from an empty cache. That says nothing about the
// account, but it reached Overview as "no investments", which then offered an
// existing user sample data. An empty snapshot from the cache must wait for
// the server; a cached snapshot with documents is still shown at once.

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
  List<List<String>> collectNames(Stream<List<InvestmentEntity>> stream) {
    final emitted = <List<String>>[];
    final subscription = stream.listen(
      (investments) => emitted.add([for (final i in investments) i.name]),
    );
    addTearDown(subscription.cancel);
    return emitted;
  }

  for (final (label, watch, snapshots, collection) in [
    (
      'watchAllInvestments',
      () => firestore.repository().watchAllInvestments(),
      () => firestore.activeSnapshots,
      () => firestore.active,
    ),
    (
      'watchArchivedInvestments',
      () => firestore.repository().watchArchivedInvestments(),
      () => firestore.archivedSnapshots,
      () => firestore.archived,
    ),
  ]) {
    group(label, () {
      test('emits nothing for an empty snapshot from the cache, then exactly '
          'one empty list once the server confirms it', () async {
        final emitted = collectNames(watch());

        snapshots().add(querySnapshot(fromCache: true));
        await pumpEventQueue();
        expect(emitted, isEmpty);

        snapshots().add(querySnapshot(fromCache: false));
        await pumpEventQueue();
        expect(emitted, [<String>[]]);

        // Later metadata-only snapshots (pending writes acknowledged, going
        // offline) carry the same documents and emit nothing new.
        snapshots().add(querySnapshot(fromCache: false, changed: false));
        snapshots().add(querySnapshot(fromCache: true, changed: false));
        await pumpEventQueue();
        expect(emitted, [<String>[]]);
      });

      test('listens to metadata changes, so an empty server answer that '
          'follows an empty cache answer arrives at all', () async {
        collectNames(watch());
        await pumpEventQueue();

        final ordered = firestore.orderedQueries[collection()]!;
        verify(
          () => ordered.snapshots(
            includeMetadataChanges: true,
            source: any(named: 'source'),
          ),
        ).called(1);
      });

      test('shows a cached snapshot with documents at once (offline-first) '
          'and does not emit it again when the server confirms it', () async {
        final emitted = collectNames(watch());

        snapshots().add(
          querySnapshot(
            docs: {'inv-1': investmentDoc('HDFC FD')},
            fromCache: true,
          ),
        );
        await pumpEventQueue();
        expect(emitted, [
          ['HDFC FD'],
        ]);

        snapshots().add(
          querySnapshot(
            docs: {'inv-1': investmentDoc('HDFC FD')},
            fromCache: false,
            changed: false,
          ),
        );
        await pumpEventQueue();
        expect(emitted, [
          ['HDFC FD'],
        ]);
      });

      test('after an empty cache answer, a server answer with documents is '
          'emitted', () async {
        final emitted = collectNames(watch());

        snapshots().add(querySnapshot(fromCache: true));
        snapshots().add(
          querySnapshot(
            docs: {'inv-1': investmentDoc('Gold SGB')},
            fromCache: false,
          ),
        );
        await pumpEventQueue();
        expect(emitted, [
          ['Gold SGB'],
        ]);
      });

      test('an investment added offline on a fresh install is shown before '
          'the server answers', () async {
        final emitted = collectNames(watch());

        snapshots().add(querySnapshot(fromCache: true));
        snapshots().add(
          querySnapshot(
            docs: {'inv-1': investmentDoc('Chit fund')},
            fromCache: true,
          ),
        );
        await pumpEventQueue();
        expect(emitted, [
          ['Chit fund'],
        ]);
      });

      test('once a list was shown, deleting the last investment offline '
          'shows the empty list', () async {
        final emitted = collectNames(watch());

        snapshots().add(
          querySnapshot(
            docs: {'inv-1': investmentDoc('P2P')},
            fromCache: false,
          ),
        );
        snapshots().add(querySnapshot(fromCache: true, changed: true));
        await pumpEventQueue();
        expect(emitted, [
          ['P2P'],
          <String>[],
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
}
