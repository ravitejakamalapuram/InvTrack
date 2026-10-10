import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:inv_tracker/core/utils/custom_type_label.dart';
import 'package:inv_tracker/features/investment/domain/entities/custom_investment_type_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/custom_investment_type_repository.dart';

/// Firestore implementation of [CustomInvestmentTypeRepository]: one small
/// document per definition in `users/{uid}/customInvestmentTypes`, written
/// offline-first.
class FirestoreCustomInvestmentTypeRepository
    implements CustomInvestmentTypeRepository {
  FirestoreCustomInvestmentTypeRepository({
    required FirebaseFirestore firestore,
    required String userId,
  }) : _firestore = firestore,
       _userId = userId;

  final FirebaseFirestore _firestore;
  final String _userId;

  /// A write that times out is cached locally and syncs when back online.
  static const Duration _writeTimeout = Duration(seconds: 5);

  CollectionReference<Map<String, dynamic>> get _ref => _firestore
      .collection('users')
      .doc(_userId)
      .collection('customInvestmentTypes');

  @override
  Stream<List<CustomInvestmentType>> watchAll() =>
      _ref.snapshots().map((snapshot) => _readAll(snapshot.docs));

  @override
  Future<List<CustomInvestmentType>> getAll() async =>
      _readAll((await _ref.get()).docs);

  /// The readable definitions. A malformed document is skipped, so one bad
  /// document never hides the others or blocks saving an investment.
  static List<CustomInvestmentType> _readAll(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) => [for (final doc in docs) ?fromFirestore(doc.data(), doc.id)];

  @override
  Future<void> put(CustomInvestmentType type) async {
    try {
      await _ref.doc(type.id).set(toFirestore(type)).timeout(_writeTimeout);
    } on TimeoutException {
      // Cached locally; it syncs when the device is back online.
    }
  }

  @override
  Future<void> deleteAll() async {
    // By id, so a malformed document is deleted too.
    final ids = [for (final doc in (await _ref.get()).docs) doc.id];
    await Future.wait([for (final id in ids) _delete(id)]);
  }

  Future<void> _delete(String id) async {
    try {
      await _ref.doc(id).delete().timeout(_writeTimeout);
    } on TimeoutException {
      // Cached locally; it syncs when the device is back online.
    }
  }

  @visibleForTesting
  static Map<String, dynamic> toFirestore(CustomInvestmentType type) => {
    'label': type.label,
    'createdAt': Timestamp.fromDate(type.createdAt),
    'updatedAt': Timestamp.fromDate(type.updatedAt),
    // Written as null while active, so reviving clears it.
    'removedAt': type.removedAt == null
        ? null
        : Timestamp.fromDate(type.removedAt!),
  };

  /// The definition a document holds, or null if it has no usable label. The
  /// label is cleaned and cut like one typed in the app, as a document may
  /// come from another build; the dates fall back to each other, then to the
  /// epoch, so a document with a label is never lost over a date.
  @visibleForTesting
  static CustomInvestmentType? fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    final label = CustomTypeLabel.fromStorage(data['label']);
    if (label.isEmpty) return null;
    final updatedAt = _date(data['updatedAt']);
    final createdAt =
        _date(data['createdAt']) ??
        updatedAt ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return CustomInvestmentType(
      id: id,
      label: label,
      createdAt: createdAt,
      updatedAt: updatedAt ?? createdAt,
      removedAt: _date(data['removedAt']),
    );
  }

  static DateTime? _date(Object? value) =>
      value is Timestamp ? value.toDate() : null;
}
