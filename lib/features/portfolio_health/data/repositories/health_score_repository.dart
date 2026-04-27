/// Repository for Portfolio Health Score persistence
///
/// Handles Firestore operations for health score snapshots
library;

import 'dart:async';

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
        _crashlytics = crashlytics ??
            CrashlyticsService(
              debugModeEnabled: CrashlyticsService.enableInDebugMode,
            );

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
  ///
  /// Uses 5-second timeout for offline-first behavior.
  /// If timeout occurs, snapshot is cached locally and syncs when online.
  ///
  /// Firestore auto-generates unique document IDs to prevent timestamp-based collisions
  /// when multiple scores are calculated quickly.
  ///
  /// Throws [TimeoutException] if save times out (data is cached locally by Firestore).
  /// Throws [DataException.saveFailed] for other errors (permission denied, etc.).
  Future<void> saveSnapshot(PortfolioHealthScore score) async {
    try {
      final snapshot = HealthScoreSnapshotModel.fromEntity(score);

      // Use Firestore auto-generated ID instead of timestamp to avoid collisions
      // (when snapshot.id is empty, we use add() which auto-generates a unique ID)
      final saveOperation = snapshot.id.isEmpty
          ? _collection.add(snapshot.toFirestore())
          : _collection.doc(snapshot.id).set(snapshot.toFirestore());

      // 5-second timeout for offline-first behavior
      await saveOperation.timeout(const Duration(seconds: 5));
    } on TimeoutException catch (e, stackTrace) {
      // Timeout is expected offline - snapshot cached locally
      _crashlytics.recordError(
        e,
        stackTrace,
        reason: 'Health score save timeout - will sync when online',
        fatal: false,
      );
      // Rethrow to let callers handle timeout (forceSave vs auto-save)
      rethrow;
    } catch (e, stackTrace) {
      // Other errors (permission denied, etc.) should fail
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
          .transform(
            StreamTransformer<QuerySnapshot<Map<String, dynamic>>,
                QuerySnapshot<Map<String, dynamic>>>.fromHandlers(
              handleError: (error, stackTrace, sink) {
                // Record stream errors to Crashlytics
                _crashlytics.recordError(
                  error,
                  stackTrace,
                  reason: 'Stream error in watchHistoricalSnapshots',
                );
                // Forward error to UI for handling
                sink.addError(error, stackTrace);
              },
            ),
          )
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => HealthScoreSnapshotModel.fromFirestore(doc))
                .toList(),
          );
    } catch (e, stackTrace) {
      _crashlytics.recordError(
        e,
        stackTrace,
        reason: 'Failed to setup watchHistoricalSnapshots',
      );
      rethrow;
    }
  }

  /// Delete all snapshots for current user (for data deletion compliance)
  Future<void> deleteAllSnapshots() async {
    try {
      // Use paginated batched delete to avoid OOM on large collections
      const batchSize = 500;
      bool hasMore = true;

      while (hasMore) {
        // Get next page
        final querySnapshot = await _collection.limit(batchSize).get();

        if (querySnapshot.docs.isEmpty) {
          hasMore = false;
          break;
        }

        // Delete this page
        final batch = _firestore.batch();
        for (final doc in querySnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        // Check if there are more docs
        hasMore = querySnapshot.docs.length == batchSize;
      }
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