/// Repository for Portfolio Health Score persistence
///
/// Handles Firestore operations for health score snapshots
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/features/portfolio_health/data/models/health_score_snapshot_model.dart';
import 'package:inv_tracker/features/portfolio_health/domain/entities/portfolio_health_score.dart';

/// Repository for health score snapshots
class HealthScoreRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final CrashlyticsService _crashlytics;

  HealthScoreRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    CrashlyticsService? crashlytics,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _crashlytics = crashlytics ?? CrashlyticsService();

  /// Get current user ID
  String get _userId {
    final user = _auth.currentUser;
    if (user == null) {
      throw AuthException.notAuthenticated();
    }
    return user.uid;
  }

  /// Firestore collection reference
  CollectionReference get _collection {
    return _firestore.collection('users').doc(_userId).collection('healthScores');
  }

  /// Save health score snapshot
  Future<void> saveSnapshot(PortfolioHealthScore score) async {
    try {
      final snapshot = HealthScoreSnapshotModel.fromEntity(score);
      await _collection.doc(snapshot.id).set(snapshot.toFirestore());
    } catch (e, stackTrace) {
      _crashlytics.recordError(
        e,
        stackTrace,
        reason: 'Failed to save health score snapshot',
      );
      throw DataException.saveFailed(
        operation: 'save health score snapshot',
        cause: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Get latest snapshot
  Future<HealthScoreSnapshotModel?> getLatestSnapshot() async {
    try {
      final querySnapshot = await _collection
          .orderBy('calculatedAt', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      return HealthScoreSnapshotModel.fromFirestore(querySnapshot.docs.first);
    } catch (e, stackTrace) {
      _crashlytics.recordError(
        e,
        stackTrace,
        reason: 'Failed to get latest health score snapshot',
      );
      throw DataException.fetchFailed(
        details: 'get latest health score snapshot',
        cause: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Get historical snapshots (last N weeks)
  Future<List<HealthScoreSnapshotModel>> getHistoricalSnapshots({
    int weeks = 12,
  }) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: weeks * 7));

      final querySnapshot = await _collection
          .where('calculatedAt', isGreaterThan: Timestamp.fromDate(cutoffDate))
          .orderBy('calculatedAt', descending: false)
          .get();

      return querySnapshot.docs
          .map((doc) => HealthScoreSnapshotModel.fromFirestore(doc))
          .toList();
    } catch (e, stackTrace) {
      _crashlytics.recordError(
        e,
        stackTrace,
        reason: 'Failed to get historical health score snapshots',
      );
      throw DataException.fetchFailed(
        details: 'get historical health score snapshots',
        cause: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Stream of historical snapshots (real-time updates)
  Stream<List<HealthScoreSnapshotModel>> watchHistoricalSnapshots({
    int weeks = 12,
  }) {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: weeks * 7));

      return _collection
          .where('calculatedAt', isGreaterThan: Timestamp.fromDate(cutoffDate))
          .orderBy('calculatedAt', descending: false)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => HealthScoreSnapshotModel.fromFirestore(doc))
                .toList(),
          );
    } catch (e, stackTrace) {
      _crashlytics.recordError(
        e,
        stackTrace,
        reason: 'Failed to watch historical health score snapshots',
      );
      rethrow;
    }
  }

  /// Delete all snapshots for current user (for data deletion compliance)
  Future<void> deleteAllSnapshots() async {
    try {
      final querySnapshot = await _collection.get();
      final batch = _firestore.batch();

      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e, stackTrace) {
      _crashlytics.recordError(
        e,
        stackTrace,
        reason: 'Failed to delete health score snapshots',
      );
      throw DataException.deleteFailed(
        cause: e,
        stackTrace: stackTrace,
      );
    }
  }
}
