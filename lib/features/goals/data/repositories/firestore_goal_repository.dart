import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inv_tracker/features/goals/data/models/goal_model.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/repositories/goal_repository.dart';

/// Firestore implementation of GoalRepository
class FirestoreGoalRepository implements GoalRepository {
  final FirebaseFirestore _firestore;
  final String _userId;

  /// Timeout for write operations
  static const Duration _writeTimeout = Duration(seconds: 3);

  FirestoreGoalRepository({
    required FirebaseFirestore firestore,
    required String userId,
  })  : _firestore = firestore,
        _userId = userId;

  /// Goals collection reference
  CollectionReference<Map<String, dynamic>> get _goalsRef =>
      _firestore.collection('users').doc(_userId).collection('goals');

  /// Execute write with timeout (offline-first pattern)
  Future<void> _executeWrite(Future<void> Function() writeOperation) async {
    try {
      await writeOperation().timeout(_writeTimeout);
    } on TimeoutException {
      // Write cached locally, will sync when online
    }
  }

  @override
  Stream<List<GoalEntity>> watchAllGoals() {
    return _goalsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GoalModel.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  @override
  Stream<List<GoalEntity>> watchActiveGoals() {
    // Client-side filtering to avoid Firestore composite index requirement
    return _goalsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GoalModel.fromFirestore(doc.data(), doc.id))
            .where((goal) => !goal.isArchived)
            .toList());
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
    final doc = await _goalsRef.doc(id).get();
    if (!doc.exists) return null;
    return GoalModel.fromFirestore(doc.data()!, doc.id);
  }

  @override
  Stream<GoalEntity?> watchGoalById(String id) {
    return _goalsRef.doc(id).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return GoalModel.fromFirestore(doc.data()!, doc.id);
    });
  }

  @override
  Future<void> createGoal(GoalEntity goal) async {
    await _executeWrite(() =>
        _goalsRef.doc(goal.id).set(GoalModel.toFirestore(goal)));
  }

  @override
  Future<void> updateGoal(GoalEntity goal) async {
    await _executeWrite(() =>
        _goalsRef.doc(goal.id).update(GoalModel.toFirestore(goal)));
  }

  @override
  Future<void> archiveGoal(String id) async {
    await _executeWrite(() => _goalsRef.doc(id).update({
          'isArchived': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }));
  }

  @override
  Future<void> unarchiveGoal(String id) async {
    await _executeWrite(() => _goalsRef.doc(id).update({
          'isArchived': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }));
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
}

