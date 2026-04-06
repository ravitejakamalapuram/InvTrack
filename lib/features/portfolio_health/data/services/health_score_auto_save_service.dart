/// Auto-save service for Portfolio Health Score snapshots
///
/// Periodically checks if score should be saved to Firestore.
/// Runs in background, debounced to avoid excessive writes.
library;

import 'dart:async';

import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/features/portfolio_health/data/repositories/health_score_repository.dart';
import 'package:inv_tracker/features/portfolio_health/domain/entities/portfolio_health_score.dart';

/// Auto-save service for health score snapshots
class HealthScoreAutoSaveService {
  final HealthScoreRepository _repository;
  Timer? _timer;
  PortfolioHealthScore? _lastScore;
  bool _isSaving = false;

  HealthScoreAutoSaveService({
    required HealthScoreRepository repository,
  }) : _repository = repository;

  /// Start auto-save timer (checks every 5 minutes)
  void start() {
    stop(); // Stop any existing timer

    _timer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _checkAndSave(),
    );

    LoggerService.debug('HealthScoreAutoSaveService started');
  }

  /// Stop auto-save timer
  void stop() {
    _timer?.cancel();
    _timer = null;
    LoggerService.debug('HealthScoreAutoSaveService stopped');
  }

  /// Update current score (called by provider when score changes)
  void updateScore(PortfolioHealthScore score) {
    _lastScore = score;
  }

  /// Check if score should be saved and save if needed
  Future<void> _checkAndSave() async {
    if (_lastScore == null) return;
    if (_isSaving) return; // Prevent overlapping saves

    _isSaving = true;
    try {
      // Capture current score before any awaits to operate on immutable snapshot
      final current = _lastScore;
      if (current == null) {
        _isSaving = false;
        return;
      }

      final latest = await _repository.getLatestSnapshot();

      // Save if: no previous snapshot OR score changed >1 point OR >24h old
      final shouldSave = latest == null ||
          (current.overallScore - latest.overallScore).abs() > 1.0 ||
          DateTime.now().difference(latest.calculatedAt).inHours >= 24;

      if (shouldSave) {
        await _repository.saveSnapshot(current);
        // Log score tier instead of exact score for privacy
        final tier = current.overallScore >= 80 ? 'excellent'
            : current.overallScore >= 60 ? 'good'
            : current.overallScore >= 40 ? 'fair'
            : 'poor';
        LoggerService.debug('Health score snapshot saved: $tier tier');
      }
    } catch (e, stackTrace) {
      LoggerService.error(
        'Failed to auto-save health score snapshot',
        error: e,
        stackTrace: stackTrace,
      );
      await CrashlyticsService().recordError(
        e,
        stackTrace,
        reason: 'HealthScoreAutoSave failure',
      );
      // Don't rethrow - auto-save failures should not break the app
    } finally {
      _isSaving = false;
    }
  }

  /// Force save current score (used for explicit user actions)
  Future<void> forceSave() async {
    if (_lastScore == null) return;
    if (_isSaving) return; // Prevent overlapping saves

    _isSaving = true;
    try {
      // Capture current score before any awaits to operate on immutable snapshot
      final current = _lastScore;
      if (current == null) {
        _isSaving = false;
        return;
      }

      await _repository.saveSnapshot(current);
      LoggerService.debug('Health score snapshot force-saved');
    } catch (e, stackTrace) {
      LoggerService.error(
        'Failed to force-save health score snapshot',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow; // Force-save failures should be visible
    } finally {
      _isSaving = false;
    }
  }

  /// Dispose service
  void dispose() {
    stop();
    _lastScore = null;
  }
}