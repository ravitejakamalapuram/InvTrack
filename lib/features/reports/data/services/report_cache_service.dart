/// Report cache service with TTL for dynamic reports
///
/// Caches expensive report calculations (e.g., XIRR, aggregations) in memory
/// with automatic expiration after 5 minutes. Prevents redundant calculations
/// when users view reports multiple times in a session.
///
/// **Automatic Cleanup**: Expired entries are removed every 5 minutes via a
/// periodic timer to prevent memory leaks from stale cached reports.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/features/reports/domain/entities/report_type.dart';

/// Provider for report cache service
///
/// The service automatically starts periodic cleanup when created.
/// Cleanup runs every 5 minutes to remove expired cache entries.
final reportCacheServiceProvider = Provider<ReportCacheService>((ref) {
  final service = ReportCacheService();
  // Start periodic cleanup when service is created
  service.startPeriodicCleanup();

  // Stop cleanup when provider is disposed
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// Cache entry with TTL
class _CacheEntry<T> {
  final T data;
  final DateTime expiresAt;

  _CacheEntry(this.data, this.expiresAt);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Report cache service
class ReportCacheService {
  /// Cache duration (5 minutes)
  static const _cacheDuration = Duration(minutes: 5);

  /// Cleanup interval (5 minutes)
  static const _cleanupInterval = Duration(minutes: 5);

  /// In-memory cache storage
  final Map<String, _CacheEntry<Object>> _cache = {};

  /// Periodic cleanup timer
  Timer? _cleanupTimer;

  /// Get cached report
  T? get<T>(ReportType type, DateTime periodStart, DateTime periodEnd) {
    final key = _generateKey(type, periodStart, periodEnd);
    final entry = _cache[key];

    if (entry == null) {
      LoggerService.debug('Cache miss for $key');
      return null;
    }

    if (entry.isExpired) {
      LoggerService.debug('Cache expired for $key');
      _cache.remove(key);
      return null;
    }

    LoggerService.debug('Cache hit for $key');
    return entry.data as T;
  }

  /// Store report in cache
  void set<T>(
    ReportType type,
    DateTime periodStart,
    DateTime periodEnd,
    T data,
  ) {
    final key = _generateKey(type, periodStart, periodEnd);
    final expiresAt = DateTime.now().add(_cacheDuration);

    _cache[key] = _CacheEntry(data as Object, expiresAt);

    LoggerService.debug(
      'Cache set for $key',
      metadata: {'expiresAt': expiresAt.toString()},
    );
  }

  /// Clear cache for a specific report type
  void clearType(ReportType type) {
    _cache.removeWhere((key, _) => key.startsWith('${type.id}_'));
    LoggerService.debug('Cache cleared for type: ${type.id}');
  }

  /// Clear all cached reports
  void clearAll() {
    _cache.clear();
    LoggerService.debug('All cache cleared');
  }

  /// Get cache statistics for debugging
  Map<String, dynamic> getStats() {
    final validEntries = _cache.values.where((e) => !e.isExpired).length;
    final expiredEntries = _cache.length - validEntries;

    return {
      'total_entries': _cache.length,
      'valid_entries': validEntries,
      'expired_entries': expiredEntries,
      'cache_duration_minutes': _cacheDuration.inMinutes,
    };
  }

  /// Generate cache key from report parameters
  String _generateKey(
    ReportType type,
    DateTime periodStart,
    DateTime periodEnd,
  ) {
    final startStr = periodStart.toIso8601String().substring(0, 10);
    final endStr = periodEnd.toIso8601String().substring(0, 10);
    return '${type.id}_${startStr}_$endStr';
  }

  /// Clean up expired entries (called periodically)
  void cleanupExpired() {
    final before = _cache.length;
    _cache.removeWhere((_, entry) => entry.isExpired);
    final removed = before - _cache.length;

    if (removed > 0) {
      LoggerService.debug('Cleaned up $removed expired cache entries');
    }
  }

  /// Start periodic cleanup timer
  ///
  /// Automatically removes expired cache entries every [_cleanupInterval].
  /// This prevents memory leaks from stale cached reports that were never
  /// explicitly accessed after expiration.
  void startPeriodicCleanup() {
    // Cancel existing timer if any
    _cleanupTimer?.cancel();

    // Start new periodic timer
    _cleanupTimer = Timer.periodic(_cleanupInterval, (_) {
      cleanupExpired();
    });

    LoggerService.debug(
      'Started periodic cache cleanup',
      metadata: {'interval_minutes': _cleanupInterval.inMinutes},
    );
  }

  /// Stop periodic cleanup timer
  ///
  /// Called automatically when the service is disposed via provider.onDispose.
  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;

    LoggerService.debug('Stopped periodic cache cleanup');
  }
}
