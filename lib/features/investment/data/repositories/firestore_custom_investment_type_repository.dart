import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
  Stream<List<CustomInvestmentType>> watchAll() => _ref.snapshots().map(
    (snapshot) => [
      for (final doc in snapshot.docs) fromFirestore(doc.data(), doc.id),
    ],
  );

  @override
  Future<List<CustomInvestmentType>> getAll() async {
    final snapshot = await _ref.get();
    return [for (final doc in snapshot.docs) fromFirestore(doc.data(), doc.id)];
  }

  @override
  Future<void> put(CustomInvestmentType type) async {
    try {
      await _ref.doc(type.id).set(toFirestore(type)).timeout(_writeTimeout);
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

  @visibleForTesting
  static CustomInvestmentType fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    final createdAt = (data['createdAt'] as Timestamp).toDate();
    return CustomInvestmentType(
      id: id,
      label: data['label'] as String,
      createdAt: createdAt,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? createdAt,
      removedAt: (data['removedAt'] as Timestamp?)?.toDate(),
    );
  }
}
