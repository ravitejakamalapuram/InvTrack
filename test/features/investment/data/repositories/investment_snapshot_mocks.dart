// Mocked Firestore for one user's investment collections, with snapshots
// whose metadata (cache or server) the test controls.

// ignore_for_file: subtype_of_sealed_class
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inv_tracker/features/investment/data/repositories/firestore_investment_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class _MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class _MockQueryDoc extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

class _MockMetadata extends Mock implements SnapshotMetadata {}

class _MockDocChange extends Mock
    implements DocumentChange<Map<String, dynamic>> {}

/// Registers the fallback values the stubs below match with `any()`.
void registerInvestmentSnapshotFallbacks() {
  registerFallbackValue(const GetOptions());
  registerFallbackValue(ListenSource.defaultSource);
}

/// An investment document as Firestore stores it.
Map<String, dynamic> investmentDoc(String name) => {
  'name': name,
  'type': 'fixedDeposit',
  'status': 'OPEN',
  'createdAt': Timestamp.fromDate(DateTime.utc(2026, 4, 1)),
  'currency': 'INR',
};

/// A query snapshot holding [docs] (id to data).
///
/// [changed] says whether the documents differ from the previous snapshot.
/// It is false for a snapshot that only changes metadata, such as the server
/// confirming what the cache already showed. By default a snapshot with
/// documents counts as changed and an empty one does not, as for the first
/// snapshot of a listener.
QuerySnapshot<Map<String, dynamic>> querySnapshot({
  Map<String, Map<String, dynamic>> docs = const {},
  required bool fromCache,
  bool? changed,
}) {
  final snapshot = _MockQuerySnapshot();
  final queryDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[
    for (final entry in docs.entries) _queryDoc(entry.key, entry.value),
  ];
  final metadata = _MockMetadata();
  when(() => metadata.isFromCache).thenReturn(fromCache);
  when(() => metadata.hasPendingWrites).thenReturn(false);
  when(() => snapshot.docs).thenReturn(queryDocs);
  when(() => snapshot.size).thenReturn(queryDocs.length);
  when(() => snapshot.metadata).thenReturn(metadata);
  when(
    () => snapshot.docChanges,
  ).thenReturn([if (changed ?? queryDocs.isNotEmpty) _MockDocChange()]);
  return snapshot;
}

QueryDocumentSnapshot<Map<String, dynamic>> _queryDoc(
  String id,
  Map<String, dynamic> data,
) {
  final doc = _MockQueryDoc();
  when(() => doc.id).thenReturn(id);
  when(() => doc.data()).thenReturn(data);
  return doc;
}

/// A mocked Firestore for one user's `investments` and `archivedInvestments`.
///
/// Live snapshots are pushed through [activeSnapshots] and
/// [archivedSnapshots]. One-shot reads of either collection answer with
/// [activeOnServer] and [archivedOnServer].
class InvestmentFirestoreMock {
  InvestmentFirestoreMock({this.userId = 'uid-1'}) {
    final users = _MockCollection();
    final userDoc = _MockDoc();
    when(() => firestore.collection('users')).thenReturn(users);
    when(() => users.doc(userId)).thenReturn(userDoc);
    when(() => userDoc.collection('investments')).thenReturn(active);
    when(() => userDoc.collection('archivedInvestments')).thenReturn(archived);
    _stubCollection(active, activeSnapshots, () => activeOnServer);
    _stubCollection(archived, archivedSnapshots, () => archivedOnServer);
  }

  final String userId;
  final FirebaseFirestore firestore = _MockFirestore();
  final CollectionReference<Map<String, dynamic>> active = _MockCollection();
  final CollectionReference<Map<String, dynamic>> archived = _MockCollection();

  /// Live snapshots of `investments`. Broadcast, because several listeners
  /// can share one query, as Firestore lets them.
  final activeSnapshots =
      StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();

  /// Live snapshots of `archivedInvestments`, broadcast like
  /// [activeSnapshots].
  final archivedSnapshots =
      StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();

  /// What a one-shot read of `investments` returns, or throws.
  FutureOr<QuerySnapshot<Map<String, dynamic>>> Function() activeOnServer =
      () => querySnapshot(fromCache: false);

  /// What a one-shot read of `archivedInvestments` returns, or throws.
  FutureOr<QuerySnapshot<Map<String, dynamic>>> Function() archivedOnServer =
      () => querySnapshot(fromCache: false);

  /// Each collection's query ordered by `createdAt`, newest first, as the
  /// repository builds it for live and one-shot reads.
  final Map<
    CollectionReference<Map<String, dynamic>>,
    Query<Map<String, dynamic>>
  >
  orderedQueries = {};

  /// Each collection's `limit(1)` query.
  final Map<
    CollectionReference<Map<String, dynamic>>,
    Query<Map<String, dynamic>>
  >
  firstDocQueries = {};

  FirestoreInvestmentRepository repository() => FirestoreInvestmentRepository(
    firestore: firestore,
    userId: userId,
    baseCurrency: () => 'INR',
  );

  /// Closes both snapshot streams.
  void close() {
    unawaited(activeSnapshots.close());
    unawaited(archivedSnapshots.close());
  }

  void _stubCollection(
    CollectionReference<Map<String, dynamic>> collection,
    StreamController<QuerySnapshot<Map<String, dynamic>>> snapshots,
    FutureOr<QuerySnapshot<Map<String, dynamic>>> Function() Function() read,
  ) {
    final ordered = _MockQuery();
    orderedQueries[collection] = ordered;
    when(
      () => collection.orderBy('createdAt', descending: true),
    ).thenReturn(ordered);
    when(
      () => ordered.snapshots(
        includeMetadataChanges: any(named: 'includeMetadataChanges'),
        source: any(named: 'source'),
      ),
    ).thenAnswer((_) => snapshots.stream);
    when(() => ordered.get(any())).thenAnswer((_) async => read()());

    final firstDoc = _MockQuery();
    firstDocQueries[collection] = firstDoc;
    when(() => collection.limit(1)).thenReturn(firstDoc);
    when(() => firstDoc.get(any())).thenAnswer((_) async => read()());
  }
}
