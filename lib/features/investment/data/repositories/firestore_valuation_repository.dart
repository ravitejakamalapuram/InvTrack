import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:inv_tracker/core/calculations/current_value_calculator.dart';
import 'package:inv_tracker/core/utils/money_precision.dart';
import 'package:inv_tracker/core/utils/stored_date.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';
import 'package:inv_tracker/features/investment/domain/repositories/valuation_repository.dart';

/// Firestore implementation of [ValuationRepository]: one document per
/// snapshot in `users/{uid}/valuations`, with offline persistence.
class FirestoreValuationRepository implements ValuationRepository {
  final FirebaseFirestore _firestore;
  final String _userId;

  /// Writes of an offline-first app are considered done when queued: see
  /// FirestoreInvestmentRepository.
  static const Duration _writeTimeout = Duration(seconds: 3);

  /// Writes per batch (the Firestore limit is 500).
  static const int _importBatchSize = 450;

  FirestoreValuationRepository({
    required FirebaseFirestore firestore,
    required String userId,
  }) : _firestore = firestore,
       _userId = userId;

  Future<void> _executeWrite(Future<void> Function() writeOperation) async {
    try {
      await writeOperation().timeout(_writeTimeout);
    } on TimeoutException {
      // Queued locally; Firestore sends it when the device is back online.
    }
  }

  // The collection name is a literal so that the account deletion coverage
  // test finds it.
  CollectionReference<Map<String, dynamic>> get _valuationsRef =>
      _firestore.collection('users').doc(_userId).collection('valuations');

  CollectionReference<Map<String, dynamic>> get _investmentsRef =>
      _firestore.collection('users').doc(_userId).collection('investments');

  @override
  Stream<List<InvestmentValuationSnapshot>> watchAll() =>
      _valuationsRef.snapshots().map(_readAll);

  @override
  Stream<List<InvestmentValuationSnapshot>> watchServerConfirmed() =>
      _valuationsRef
          .snapshots(includeMetadataChanges: true)
          .where(
            (query) =>
                !query.metadata.isFromCache && !query.metadata.hasPendingWrites,
          )
          .map(_readAll);

  @override
  Future<List<InvestmentValuationSnapshot>> getAll() async =>
      _readAll(await _valuationsRef.get());

  @override
  Future<void> save(
    InvestmentValuationSnapshot snapshot, {
    required CompatMirror mirror,
  }) => _write(snapshot, mirror);

  @override
  Future<void> softDelete(
    InvestmentValuationSnapshot snapshot, {
    required CompatMirror mirror,
  }) => _write(snapshot.copyWith(deletedAt: DateTime.now()), mirror);

  @override
  Future<void> restore(
    InvestmentValuationSnapshot snapshot, {
    required CompatMirror mirror,
  }) => _write(snapshot.copyWith(clearDeletedAt: true), mirror);

  /// The snapshot as a whole document, and the mirror on the investment, in
  /// one batch: both carry the same server timestamp, which is how readers
  /// tell this app's writes from an older app's.
  Future<void> _write(
    InvestmentValuationSnapshot snapshot,
    CompatMirror mirror,
  ) async {
    // Built first, so an invalid snapshot writes nothing.
    final data = snapshotToFirestore(snapshot);
    final batch = _firestore.batch();
    batch.set(_valuationsRef.doc(snapshot.id), data);
    // update(), never set(): an investment deleted on another device must
    // not come back as a stub with only these fields.
    batch.update(_investmentsRef.doc(mirror.investmentId), {
      'currentValue': mirror.value,
      // The written format of the pair is unchanged, for older app versions.
      'currentValueDate': mirror.date == null
          ? null
          : Timestamp.fromDate(mirror.date!),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _executeWrite(() => batch.commit());
  }

  @override
  Future<int> importAll(List<InvestmentValuationSnapshot> snapshots) async {
    // Every document is built first, so an invalid one writes nothing.
    final documents = [
      for (final snapshot in snapshots)
        (
          id: snapshot.id,
          data: snapshotToFirestore(snapshot, keepUpdatedAt: true),
        ),
    ];
    for (var i = 0; i < documents.length; i += _importBatchSize) {
      final end = (i + _importBatchSize < documents.length)
          ? i + _importBatchSize
          : documents.length;
      final batch = _firestore.batch();
      for (final document in documents.sublist(i, end)) {
        batch.set(_valuationsRef.doc(document.id), document.data);
      }
      await _executeWrite(() => batch.commit());
    }
    return documents.length;
  }

  List<InvestmentValuationSnapshot> _readAll(
    QuerySnapshot<Map<String, dynamic>> query,
  ) => [
    for (final doc in query.docs) ?snapshotFromFirestore(doc.data(), doc.id),
  ];

  // ============ MAPPERS ============

  /// The whole document for [snapshot]. Throws [ArgumentError] for a value
  /// that must never be stored: a blank currency, a negative or non-finite
  /// amount, or the reserved `estimate` provenance. The amount is rounded to
  /// the currency's minor unit here, at write only (never inside
  /// calculators). [keepUpdatedAt] stores the snapshot's own update time
  /// instead of the server's, for imports that must keep same-day ties.
  @visibleForTesting
  static Map<String, dynamic> snapshotToFirestore(
    InvestmentValuationSnapshot snapshot, {
    bool keepUpdatedAt = false,
  }) {
    if (snapshot.currency.trim().isEmpty) {
      throw ArgumentError.value(snapshot.currency, 'currency', 'Is blank');
    }
    if (!snapshot.amount.isFinite || snapshot.amount < 0) {
      throw ArgumentError.value(
        'amount',
        'amount',
        'Must be finite and not negative',
      );
    }
    if (TerminalValues.isEphemeralId(snapshot.id)) {
      // A calculation's flow, never a stored snapshot.
      throw ArgumentError.value(
        'id',
        'id',
        'Is the id of a flow built for a calculation',
      );
    }
    if (snapshot.provenance == ValuationProvenance.estimate) {
      throw ArgumentError.value(
        snapshot.provenance.name,
        'provenance',
        'Estimates are computed, never stored',
      );
    }
    final updatedAt = snapshot.updatedAt;
    return {
      'investmentId': snapshot.investmentId,
      'amount': MoneyPrecision.round(
        snapshot.amount,
        currencyCode: snapshot.currency,
      ),
      'currency': snapshot.currency,
      'effectiveDate': Timestamp.fromDate(
        StoredDate.toStorage(snapshot.effectiveDate),
      ),
      'kind': snapshot.kind.name,
      'provenance': snapshot.provenance.storageName,
      'createdAt': Timestamp.fromDate(snapshot.createdAt),
      'updatedAt': keepUpdatedAt && updatedAt != null
          ? Timestamp.fromDate(updatedAt)
          : FieldValue.serverTimestamp(),
      'deletedAt': snapshot.deletedAt == null
          ? null
          : Timestamp.fromDate(snapshot.deletedAt!),
    };
  }

  /// The snapshot in [data], or null when the document cannot be trusted: an
  /// unknown kind or provenance, a missing or blank currency, a missing,
  /// non-finite or negative amount, or a missing date or investment. Such a
  /// document is ignored, never reinterpreted or defaulted. A null
  /// `updatedAt` is a write still on its way.
  @visibleForTesting
  static InvestmentValuationSnapshot? snapshotFromFirestore(
    Map<String, dynamic> data,
    String id, {
    UtcOffsetAt? offsetAt,
  }) {
    final kind = ValuationKind.tryParse(data['kind']);
    final provenance = ValuationProvenance.tryParse(data['provenance']);
    final currency = data['currency'];
    final amount = data['amount'];
    final effectiveDate = data['effectiveDate'];
    final investmentId = data['investmentId'];
    if (kind == null ||
        provenance == null ||
        currency is! String ||
        currency.trim().isEmpty ||
        amount is! num ||
        !amount.isFinite ||
        amount < 0 ||
        effectiveDate is! Timestamp ||
        investmentId is! String ||
        investmentId.isEmpty) {
      return null;
    }
    final createdAt = data['createdAt'];
    final updatedAt = data['updatedAt'];
    final deletedAt = data['deletedAt'];
    return InvestmentValuationSnapshot(
      id: id,
      investmentId: investmentId,
      amount: amount.toDouble(),
      currency: currency,
      effectiveDate: StoredDate.fromStorage(
        effectiveDate.toDate(),
        offsetAt: offsetAt,
      ),
      kind: kind,
      provenance: provenance,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
      deletedAt: deletedAt is Timestamp ? deletedAt.toDate() : null,
    );
  }
}
