// A26 / ARCH-V02: a cash flow save used to wait up to 3 s for the server to
// acknowledge the write, so every save in airplane mode took 3 s. The local
// write is the success; a write the server later rejects is reported through
// `onWriteRejected`, by type only.
//
// The project has no fake_cloud_firestore dependency, so a small in-memory
// Firestore stands in for the server: a write lands in the "cache" at once
// and its future completes only when the test lets the server answer.
//
// ignore_for_file: subtype_of_sealed_class
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/data/repositories/firestore_investment_repository.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

class _Store extends Fake implements FirebaseFirestore {
  final cashflows = <String, Map<String, dynamic>>{};

  /// Completes the pending server answer of every write; null = never.
  Completer<void> serverAnswer = Completer<void>();

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.store, this.name);
  final _Store store;
  final String name;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      name == 'users' ? _UserDoc(store) : _Doc(store, path!);
}

class _UserDoc extends Fake implements DocumentReference<Map<String, dynamic>> {
  _UserDoc(this.store);
  final _Store store;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(store, path);
}

class _Doc extends Fake implements DocumentReference<Map<String, dynamic>> {
  _Doc(this.store, this.id);
  final _Store store;
  @override
  final String id;

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    store.cashflows[id] = Map.of(data);
    await store.serverAnswer.future;
  }
}

CashFlowEntity _flow() => CashFlowEntity(
  id: 'cf-1',
  investmentId: 'inv-1',
  type: CashFlowType.income,
  amount: 1250.5,
  date: DateTime(2026, 10, 11),
  createdAt: DateTime(2026, 10, 11, 9),
  currency: 'INR',
);

void main() {
  test('adding a cash flow with no server ack completes at once', () async {
    final store = _Store();
    final repository = FirestoreInvestmentRepository(
      firestore: store,
      userId: 'uid-1',
      baseCurrency: () => 'INR',
    );

    // The old 3 s wait would run past this limit.
    await repository.addCashFlow(_flow()).timeout(const Duration(seconds: 1));

    expect(store.cashflows.keys, ['cf-1']);
  });

  test('a write the server rejects is reported, without its content', () async {
    final store = _Store();
    final rejected = <Object>[];
    final repository = FirestoreInvestmentRepository(
      firestore: store,
      userId: 'uid-1',
      baseCurrency: () => 'INR',
      onWriteRejected: rejected.add,
    );

    await repository.addCashFlow(_flow());
    expect(rejected, isEmpty);

    store.serverAnswer.completeError(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(rejected, hasLength(1));
    expect(rejected.single, isA<FirebaseException>());
  });

  test('a rejection with nobody listening does not crash', () async {
    final store = _Store();
    final repository = FirestoreInvestmentRepository(
      firestore: store,
      userId: 'uid-1',
      baseCurrency: () => 'INR',
    );

    await repository.addCashFlow(_flow());
    store.serverAnswer.completeError(StateError('rejected'));
    await Future<void>.delayed(Duration.zero);
  });
}
