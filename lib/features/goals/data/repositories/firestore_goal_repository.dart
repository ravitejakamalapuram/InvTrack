import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inv_tracker/features/goals/data/models/goal_model.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/repositories/goal_repository.dart';

/// Firestore implementation of GoalRepository
/// Uses separate collections for active and archived goals.
class FirestoreGoalRepository implements GoalRepository {
  final FirebaseFirestore _firestore;
  final String _userId;

  /// Timeout for write operations
  static const Duration _writeTimeout = Duration(seconds: 3);

  FirestoreGoalRepository({
    required FirebaseFirestore firestore,
    required String userId,
  }) : _firestore = firestore,
       _userId = userId;

  /// Active goals collection reference
  CollectionReference<Map<String, dynamic>> get _goalsRef =>
      _firestore.collection('users').doc(_userId).collection('goals');

  /// Archived goals collection reference
  CollectionReference<Map<String, dynamic>> get _archivedGoalsRef =>
      _firestore.collection('users').doc(_userId).collection('archivedGoals');

  /// Execute write with timeout (offline-first pattern)
  Future<void> _executeWrite(Future<void> Function() writeOperation) async {
    try {
      await writeOperation().timeout(_writeTimeout);
    } on TimeoutException {
      // Write cached locally, will sync when online
    }
  }

  // ============ ACTIVE GOALS ============

  @override
  Stream<List<GoalEntity>> watchAllGoals() {
    return _goalsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => GoalModel.fromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  @override
  Stream<List<GoalEntity>> watchActiveGoals() {
    // With separate collections, all goals in _goalsRef are active
    return watchAllGoals();
  }

  @override
  Future<List<GoalEntity>> getAllGoals() async {
    final snapshot = await _goalsRef
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => GoalModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<GoalEntity?> getGoalById(String id) async {
    // Search active first
    final doc = await _goalsRef.doc(id).get();
    if (doc.exists) {
      return GoalModel.fromFirestore(doc.data()!, doc.id);
    }
    // Fall back to archived
    final archivedDoc = await _archivedGoalsRef.doc(id).get();
    if (archivedDoc.exists) {
      return GoalModel.fromFirestore(archivedDoc.data()!, archivedDoc.id);
    }
    return null;
  }

  @override
  Stream<GoalEntity?> watchGoalById(String id) {
    // Watch both collections and merge
    return _goalsRef.doc(id).snapshots().asyncMap((activeDoc) async {
      if (activeDoc.exists && activeDoc.data() != null) {
        return GoalModel.fromFirestore(activeDoc.data()!, activeDoc.id);
      }
      // Check archived
      final archivedDoc = await _archivedGoalsRef.doc(id).get();
      if (archivedDoc.exists && archivedDoc.data() != null) {
        return GoalModel.fromFirestore(archivedDoc.data()!, archivedDoc.id);
      }
      return null;
    });
  }

  @override
  Future<void> createGoal(GoalEntity goal) async {
    await _executeWrite(
      () => _goalsRef.doc(goal.id).set(GoalModel.toFirestore(goal)),
    );
  }

  @override
  Future<void> updateGoal(GoalEntity goal) async {
    await _executeWrite(
      () => _goalsRef.doc(goal.id).update(GoalModel.toFirestore(goal)),
    );
  }

  @override
  Future<void> archiveGoal(String id) async {
    // Move goal from active to archived collection
    try {
      final doc = await _goalsRef.doc(id).get();
      if (!doc.exists) return;

      final goalData = doc.data()!;
      goalData['isArchived'] = true;
      goalData['updatedAt'] = FieldValue.serverTimestamp();

      final batch = _firestore.batch();
      batch.set(_archivedGoalsRef.doc(id), goalData);
      batch.delete(_goalsRef.doc(id));

      await _executeWrite(() => batch.commit());
    } on TimeoutException {
      // Offline - will sync when back online
    }
  }

  @override
  Future<void> unarchiveGoal(String id) async {
    // Move goal from archived back to active collection
    try {
      final doc = await _archivedGoalsRef.doc(id).get();
      if (!doc.exists) return;

      final goalData = doc.data()!;
      goalData['isArchived'] = false;
      goalData['updatedAt'] = FieldValue.serverTimestamp();

      final batch = _firestore.batch();
      batch.set(_goalsRef.doc(id), goalData);
      batch.delete(_archivedGoalsRef.doc(id));

      await _executeWrite(() => batch.commit());
    } on TimeoutException {
      // Offline - will sync when back online
    }
  }

  @override
  Future<void> deleteGoal(String id) async {
    await _executeWrite(() => _goalsRef.doc(id).delete());
  }

  @override
  Future<List<GoalEntity>> getGoalsForInvestment(String investmentId) async {
    final snapshot = await _goalsRef
        .where('linkedInvestmentIds', arrayContains: investmentId)
        .get();
    return snapshot.docs
        .map((doc) => GoalModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  // ============ ARCHIVED GOALS ============

  @override
  Stream<List<GoalEntity>> watchArchivedGoals() {
    return _archivedGoalsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => GoalModel.fromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  @override
  Future<GoalEntity?> getArchivedGoalById(String id) async {
    final doc = await _archivedGoalsRef.doc(id).get();
    if (!doc.exists) return null;
    return GoalModel.fromFirestore(doc.data()!, doc.id);
  }

  @override
  Future<void> updateArchivedGoal(GoalEntity goal) async {
    await _executeWrite(
      () => _archivedGoalsRef.doc(goal.id).update(GoalModel.toFirestore(goal)),
    );
  }

  @override
  Future<void> deleteArchivedGoal(String id) async {
    await _executeWrite(() => _archivedGoalsRef.doc(id).delete());
  }
}
