// In-memory stand-in for the `users/{uid}` tree, just large enough for
// LegacyCurrencyBackfillService and UsdTagRepairService: collection reads
// (with the GetOptions used), document references by id, and transactions
// (get + update, applied on commit like the server).
//
// The project has no fake_cloud_firestore dependency, so this is hand-built.

// ignore_for_file: subtype_of_sealed_class
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeLegacyCurrencyFirestore extends Fake implements FirebaseFirestore {
  FakeLegacyCurrencyFirestore({this.uid = 'uid-1'});

  final String uid;

  /// collection name -> document id -> stored fields.
  final data = <String, Map<String, Map<String, dynamic>>>{};

  /// Every GetOptions passed to a collection read, in order.
  final readOptions = <GetOptions?>[];

  /// Number of documents updated by each committed transaction.
  final commitSizes = <int>[];

  /// Fields of the `users/{uid}` document itself; null while it does not
  /// exist.
  Map<String, dynamic>? userFields;

  /// Every GetOptions passed to a read of the `users/{uid}` document itself.
  final userDocReadOptions = <GetOptions?>[];

  /// Thrown by reads of collections and of the `users/{uid}` document
  /// (simulates offline or permission errors).
  Object? readError;

  /// Thrown by writes to the `users/{uid}` document itself.
  Object? userDocWriteError;

  /// When set, collection reads wait for it (simulates a slow server scan).
  Completer<void>? readGate;

  /// Thrown by runTransaction (simulates offline or a rejected write).
  Object? transactionError;

  /// Runs after the collection scan and before the transaction reads, to
  /// simulate another device writing in between.
  void Function()? beforeTransaction;

  int get transactionCount => commitSizes.length;
  int get updatedDocs => commitSizes.fold(0, (a, b) => a + b);

  void put(String collection, String id, Map<String, dynamic> fields) {
    data.putIfAbsent(collection, () => {})[id] = Map.of(fields);
  }

  Map<String, dynamic>? stored(String collection, String id) =>
      data[collection]?[id];

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    if (path != 'users') throw UnimplementedError(path);
    return _UsersCollection(this);
  }

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    beforeTransaction?.call();
    if (transactionError != null) throw transactionError!;
    final tx = _FakeTransaction(this);
    final result = await transactionHandler(tx);
    for (final entry in tx.updates) {
      stored(entry.key.collectionName, entry.key.id)!.addAll(entry.value);
    }
    commitSizes.add(tx.updates.length);
    return result;
  }
}

class _UsersCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _UsersCollection(this.store);
  final FakeLegacyCurrencyFirestore store;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    if (path != store.uid) throw UnimplementedError('unexpected uid');
    return _UserDoc(store);
  }
}

class _UserDoc extends Fake implements DocumentReference<Map<String, dynamic>> {
  _UserDoc(this.store);
  final FakeLegacyCurrencyFirestore store;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _DataCollection(store, path);

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    store.userDocReadOptions.add(options);
    final gate = store.readGate;
    if (gate != null) await gate.future;
    if (store.readError != null) throw store.readError!;
    return _FakeDocSnapshot(store.userFields);
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    if (store.userDocWriteError != null) throw store.userDocWriteError!;
    store.userFields = {
      if (options?.merge ?? false) ...?store.userFields,
      ...data,
    };
  }
}

class _DataCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _DataCollection(this.store, this.name);
  final FakeLegacyCurrencyFirestore store;
  final String name;

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    store.readOptions.add(options);
    final gate = store.readGate;
    if (gate != null) await gate.future;
    if (store.readError != null) throw store.readError!;
    final docs = store.data[name] ?? {};
    return _FakeQuerySnapshot([
      for (final e in docs.entries)
        _FakeQueryDoc(_FakeDocRef(name, e.key), Map.of(e.value)),
    ]);
  }

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _FakeDocRef(name, path!);
}

class _FakeDocRef extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _FakeDocRef(this.collectionName, this.id);
  final String collectionName;
  @override
  final String id;

  @override
  bool operator ==(Object other) =>
      other is _FakeDocRef &&
      other.collectionName == collectionName &&
      other.id == id;

  @override
  int get hashCode => Object.hash(collectionName, id);
}

class _FakeQuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  _FakeQuerySnapshot(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

class _FakeQueryDoc extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _FakeQueryDoc(this.reference, this._data);
  @override
  final DocumentReference<Map<String, dynamic>> reference;
  final Map<String, dynamic> _data;

  @override
  String get id => reference.id;

  @override
  Map<String, dynamic> data() => _data;
}

class _FakeDocSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDocSnapshot(this._data);
  final Map<String, dynamic>? _data;

  @override
  bool get exists => _data != null;

  @override
  Map<String, dynamic>? data() => _data == null ? null : Map.of(_data);
}

class _FakeTransaction extends Fake implements Transaction {
  _FakeTransaction(this.store);
  final FakeLegacyCurrencyFirestore store;
  final updates = <MapEntry<_FakeDocRef, Map<String, dynamic>>>[];

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) async {
    if (updates.isNotEmpty) {
      throw StateError('Transactions must read before they write');
    }
    final ref = documentReference as _FakeDocRef;
    return _FakeDocSnapshot(store.stored(ref.collectionName, ref.id))
        as DocumentSnapshot<T>;
  }

  @override
  Transaction update(
    DocumentReference documentReference,
    Map<Object, Object?> data,
  ) {
    updates.add(
      MapEntry(documentReference as _FakeDocRef, data.cast<String, dynamic>()),
    );
    return this;
  }
}
