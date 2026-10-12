// #964: valuation snapshots (users/{uid}/valuations) left behind by an
// investment deleted while this device had not cached them are removed once
// per session, and only on the server's word: both the investments and the
// valuations must be server-confirmed, and each candidate is checked once more
// on the server, so a partially loaded list or an investment another device
// just created can never get a valid snapshot deleted.
//
// ignore_for_file: subtype_of_sealed_class
import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/data/services/orphaned_valuation_cleanup_service.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';
import 'package:inv_tracker/features/investment/domain/repositories/valuation_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _MockDocSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class _MockBatch extends Mock implements WriteBatch {}

class _MockInvestmentRepository extends Mock implements InvestmentRepository {}

class _MockValuationRepository extends Mock implements ValuationRepository {}

InvestmentValuationSnapshot _snapshot(
  String id,
  String investmentId, {
  bool cleared = false,
}) => InvestmentValuationSnapshot(
  id: id,
  investmentId: investmentId,
  amount: 125000.5,
  currency: 'INR',
  effectiveDate: DateTime(2026, 4, 1),
  kind: ValuationKind.marketValue,
  provenance: ValuationProvenance.manual,
  createdAt: DateTime.utc(2026, 4, 1),
  deletedAt: cleared ? DateTime.utc(2026, 5, 1) : null,
);

void main() {
  const uid = 'user-1';
  const server = GetOptions(source: Source.server);

  late _MockFirestore firestore;
  late _MockInvestmentRepository investments;
  late _MockValuationRepository valuations;
  late StreamController<Set<String>> idStream;
  late StreamController<List<InvestmentValuationSnapshot>> valuationStream;
  late int idListens;
  late int valuationListens;

  /// Reference of each valuation document, by id.
  late Map<String, _MockDoc> valuationRefs;
  late List<List<DocumentReference>> deletedPerBatch;

  /// The investment ids whose existence was asked of the server, in order.
  late List<String> readIds;

  /// The ids of the investments the server holds, by collection. Both are
  /// read again by the sweep, so these can differ from the snapshots.
  late Map<String, Set<String>> onServer;

  /// When set, a server read of an investment throws it.
  late Object? readFailure;

  /// When set, a batch commit never completes (offline).
  late bool commitHangs;
  late int inFlightReads;
  late int maxInFlightReads;

  /// Runs at the start of every server read of an investment.
  late void Function()? onRead;

  OrphanedValuationCleanupService service({
    Duration readTimeout = const Duration(seconds: 20),
    Duration writeTimeout = const Duration(seconds: 3),
  }) => OrphanedValuationCleanupService(
    firestore: firestore,
    userId: uid,
    investmentRepository: investments,
    valuationRepository: valuations,
    readTimeout: readTimeout,
    writeTimeout: writeTimeout,
  );

  List<DocumentReference> deleted() =>
      deletedPerBatch.expand((d) => d).toList();

  /// Both server-confirmed streams answer.
  void serverSays({
    required Set<String> investmentIds,
    required List<InvestmentValuationSnapshot> snapshots,
  }) {
    idStream.add(investmentIds);
    valuationStream.add(snapshots);
  }

  setUpAll(() {
    registerFallbackValue(_MockDoc());
    registerFallbackValue(const GetOptions());
  });

  setUp(() {
    firestore = _MockFirestore();
    investments = _MockInvestmentRepository();
    valuations = _MockValuationRepository();
    idStream = StreamController<Set<String>>.broadcast();
    valuationStream =
        StreamController<List<InvestmentValuationSnapshot>>.broadcast();
    idListens = 0;
    valuationListens = 0;
    valuationRefs = {};
    deletedPerBatch = [];
    readIds = [];
    onServer = {'investments': {}, 'archivedInvestments': {}};
    readFailure = null;
    commitHangs = false;
    inFlightReads = 0;
    maxInFlightReads = 0;
    onRead = null;

    when(() => investments.watchServerConfirmedInvestmentIds()).thenAnswer((_) {
      idListens++;
      return idStream.stream;
    });
    when(() => valuations.watchServerConfirmed()).thenAnswer((_) {
      valuationListens++;
      return valuationStream.stream;
    });

    final users = _MockCollection();
    final userDoc = _MockDoc();
    when(() => firestore.collection('users')).thenReturn(users);
    when(() => users.doc(uid)).thenReturn(userDoc);

    final valuationCollection = _MockCollection();
    when(
      () => userDoc.collection('valuations'),
    ).thenReturn(valuationCollection);
    when(() => valuationCollection.doc(any())).thenAnswer(
      (call) => valuationRefs.putIfAbsent(
        call.positionalArguments.first as String,
        _MockDoc.new,
      ),
    );

    for (final name in ['investments', 'archivedInvestments']) {
      final collection = _MockCollection();
      when(() => userDoc.collection(name)).thenReturn(collection);
      when(() => collection.doc(any())).thenAnswer((call) {
        final investmentId = call.positionalArguments.first as String;
        final ref = _MockDoc();
        when(() => ref.get(server)).thenAnswer((_) async {
          readIds.add(investmentId);
          onRead?.call();
          inFlightReads++;
          maxInFlightReads = math.max(maxInFlightReads, inFlightReads);
          await Future<void>.delayed(Duration.zero);
          inFlightReads--;
          final failure = readFailure;
          if (failure != null) throw failure;
          final snapshot = _MockDocSnapshot();
          when(
            () => snapshot.exists,
          ).thenReturn(onServer[name]!.contains(investmentId));
          return snapshot;
        });
        return ref;
      });
    }

    when(() => firestore.batch()).thenAnswer((_) {
      final batch = _MockBatch();
      final inBatch = <DocumentReference>[];
      when(() => batch.delete(any())).thenAnswer((i) {
        inBatch.add(i.positionalArguments.first as DocumentReference);
      });
      when(() => batch.commit()).thenAnswer((_) {
        if (commitHangs) return Completer<void>().future;
        return Future.value();
      });
      deletedPerBatch.add(inBatch);
      return batch;
    });
  });

  tearDown(() {
    unawaited(idStream.close());
    unawaited(valuationStream.close());
  });

  test('deletes the snapshots of an investment that no longer exists, '
      'cleared ones included, and keeps those of live and archived '
      'investments', () async {
    onServer['investments']!.add('live'); // re-read finds nothing for 'gone'
    final run = service().runOnce();

    serverSays(
      investmentIds: {'live', 'archived'},
      snapshots: [
        _snapshot('v-live', 'live'),
        _snapshot('v-archived', 'archived'),
        _snapshot('v-gone', 'gone'),
        _snapshot('v-gone-cleared', 'gone', cleared: true),
      ],
    );

    expect(await run, isTrue);
    expect(
      deleted(),
      unorderedEquals([
        valuationRefs['v-gone'],
        valuationRefs['v-gone-cleared'],
      ]),
    );
    expect(deletedPerBatch, hasLength(1));
  });

  test('deletes nothing while only the investments have been confirmed by '
      'the server', () async {
    final run = service().runOnce();
    var finished = false;
    unawaited(run.whenComplete(() => finished = true));

    idStream.add({'live'});
    await pumpEventQueue();

    expect(finished, isFalse);
    expect(deletedPerBatch, isEmpty);
  });

  test('deletes nothing while only the valuations have been confirmed by '
      'the server', () async {
    final run = service().runOnce();
    var finished = false;
    unawaited(run.whenComplete(() => finished = true));

    valuationStream.add([_snapshot('v-gone', 'gone')]);
    await pumpEventQueue();

    expect(finished, isFalse);
    expect(deletedPerBatch, isEmpty);
  });

  test('a second run in the same session does nothing', () async {
    final first = service();
    final run = first.runOnce();
    serverSays(
      investmentIds: {'live'},
      snapshots: [_snapshot('v-gone', 'gone')],
    );
    expect(await run, isTrue);
    final batchesAfterFirst = deletedPerBatch.length;
    final readsAfterFirst = readIds.length;

    expect(await first.runOnce(), isTrue);
    serverSays(
      investmentIds: {'live'},
      snapshots: [_snapshot('v-gone-2', 'gone-2')],
    );
    await pumpEventQueue();

    expect(deletedPerBatch, hasLength(batchesAfterFirst));
    expect(readIds, hasLength(readsAfterFirst));
    expect(idListens, 1);
    expect(valuationListens, 1);
  });

  test('two runs started together share one sweep', () async {
    final sweep = service();
    final a = sweep.runOnce();
    final b = sweep.runOnce();
    serverSays(
      investmentIds: {'live'},
      snapshots: [_snapshot('v-gone', 'gone')],
    );

    expect(await Future.wait([a, b]), [true, true]);
    expect(deletedPerBatch, hasLength(1));
    expect(idListens, 1);
  });

  test('keeps a snapshot whose investment the server still has, although '
      'the investments snapshot did not list it yet (another device just '
      'created it)', () async {
    onServer['investments']!.add('new-on-other-device');
    onServer['archivedInvestments']!.add('archived-meanwhile');
    final run = service().runOnce();

    serverSays(
      investmentIds: {'live'},
      snapshots: [
        _snapshot('v-new', 'new-on-other-device'),
        _snapshot('v-moved', 'archived-meanwhile'),
        _snapshot('v-gone', 'gone'),
      ],
    );

    expect(await run, isTrue);
    expect(deleted(), [valuationRefs['v-gone']]);
  });

  test('checks each candidate investment on the server once, in both '
      'collections', () async {
    final run = service().runOnce();

    serverSays(
      investmentIds: const {},
      snapshots: [
        _snapshot('v-1', 'gone'),
        _snapshot('v-2', 'gone'),
        _snapshot('v-3', 'also-gone'),
      ],
    );
    await run;

    expect(readIds.where((id) => id == 'gone'), hasLength(2));
    expect(readIds.where((id) => id == 'also-gone'), hasLength(2));
    expect(deleted(), hasLength(3));
  });

  test('checks the candidates in chunks, not all at once', () async {
    final run = service().runOnce();

    serverSays(
      investmentIds: const {},
      snapshots: [for (var i = 0; i < 120; i++) _snapshot('v-$i', 'gone-$i')],
    );
    await run;

    // 50 investments at a time, each read in two collections.
    expect(maxInFlightReads, 100);
    expect(deleted(), hasLength(120));
  });

  test('leaves snapshots without an investment id alone', () async {
    final run = service().runOnce();

    serverSays(
      investmentIds: const {},
      snapshots: [_snapshot('v-blank', '  '), _snapshot('v-gone', 'gone')],
    );
    await run;

    expect(deleted(), [valuationRefs['v-gone']]);
  });

  test('deletes nothing when there are no orphans', () async {
    final run = service().runOnce();

    serverSays(
      investmentIds: {'live'},
      snapshots: [_snapshot('v-live', 'live')],
    );

    expect(await run, isTrue);
    expect(deletedPerBatch, isEmpty);
    expect(readIds, isEmpty);
  });

  test('deletes in batches of at most 450', () async {
    final run = service().runOnce();

    serverSays(
      investmentIds: const {},
      snapshots: [for (var i = 0; i < 1000; i++) _snapshot('v-$i', 'gone')],
    );
    await run;

    expect(
      [for (final batch in deletedPerBatch) batch.length],
      [450, 450, 100],
    );
  });

  test('deletes nothing and tries again next time when the server read '
      'fails (offline)', () async {
    readFailure = TimeoutException('offline');
    final sweep = service();
    final first = sweep.runOnce();
    serverSays(
      investmentIds: const {},
      snapshots: [_snapshot('v-gone', 'gone')],
    );

    expect(await first, isFalse);
    expect(deletedPerBatch, isEmpty);

    readFailure = null;
    final second = sweep.runOnce();
    serverSays(
      investmentIds: const {},
      snapshots: [_snapshot('v-gone', 'gone')],
    );

    expect(await second, isTrue);
    expect(deleted(), [valuationRefs['v-gone']]);
    expect(idListens, 2);
  });

  test('does not count the sweep as done when the server does not confirm '
      'the delete in time, so the next call tries again', () async {
    commitHangs = true;
    final sweep = service(writeTimeout: const Duration(milliseconds: 20));
    final first = sweep.runOnce();
    serverSays(
      investmentIds: const {},
      snapshots: [_snapshot('v-gone', 'gone')],
    );

    expect(await first, isFalse);

    commitHangs = false;
    final second = sweep.runOnce();
    serverSays(
      investmentIds: const {},
      snapshots: [_snapshot('v-gone', 'gone')],
    );
    expect(await second, isTrue);
  });

  test(
    'a stream error ends the run without deleting and allows a retry',
    () async {
      final sweep = service();
      final first = sweep.runOnce();
      idStream.addError(StateError('permission-denied'));

      expect(await first, isFalse);
      expect(deletedPerBatch, isEmpty);

      final second = sweep.runOnce();
      serverSays(investmentIds: {'live'}, snapshots: [_snapshot('v', 'live')]);
      expect(await second, isTrue);
    },
  );

  test('cancel stops waiting for the server, closes both listeners and '
      'deletes nothing even if the server answers later', () async {
    final sweep = service();
    final run = sweep.runOnce();
    await pumpEventQueue();
    expect(idStream.hasListener, isTrue);
    expect(valuationStream.hasListener, isTrue);

    sweep.cancel();

    expect(await run, isFalse);
    expect(idStream.hasListener, isFalse);
    expect(valuationStream.hasListener, isFalse);
    serverSays(
      investmentIds: const {},
      snapshots: [_snapshot('v-gone', 'gone')],
    );
    await pumpEventQueue();
    expect(readIds, isEmpty);
    expect(deletedPerBatch, isEmpty);
  });

  test(
    'cancel while the candidates are being checked deletes nothing',
    () async {
      final sweep = service();
      onRead = sweep.cancel;
      final run = sweep.runOnce();
      serverSays(
        investmentIds: const {},
        snapshots: [_snapshot('v-gone', 'gone')],
      );

      expect(await run, isFalse);
      expect(deletedPerBatch, isEmpty);
    },
  );

  test('a cancelled service does not listen again', () async {
    final sweep = service()..cancel();

    expect(await sweep.runOnce(), isFalse);
    expect(idListens, 0);
    expect(valuationListens, 0);
  });
}
