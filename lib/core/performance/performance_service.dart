/// Performance monitoring service for tracking app performance metrics.
///
/// Wraps Firebase Performance Monitoring to track:
/// - Custom traces for critical operations
/// - Network request latency
/// - App startup time
/// - Screen rendering performance
library;

import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

/// Service for tracking performance metrics using Firebase Performance Monitoring.
class PerformanceService {
  PerformanceService._();

  static final PerformanceService _instance = PerformanceService._();
  factory PerformanceService() => _instance;

  FirebasePerformance? _performance;
  bool _isInitialized = false;

  /// Initialize Firebase Performance Monitoring
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _performance = FirebasePerformance.instance;

      // Enable performance monitoring
      await _performance!.setPerformanceCollectionEnabled(true);

      _isInitialized = true;

      if (kDebugMode) {
        debugPrint('📊 Performance monitoring initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📊 Error initializing performance monitoring: $e');
      }
    }
  }

  /// Start a custom trace for tracking operation performance
  ///
  /// Example:
  /// ```dart
  /// final trace = await performanceService.startTrace('investment_create');
  /// try {
  ///   // ... perform operation
  ///   await trace?.putMetric('investment_count', 1);
  /// } finally {
  ///   await trace?.stop();
  /// }
  /// ```
  Future<Trace?> startTrace(String name) async {
    if (!_isInitialized || _performance == null) {
      if (kDebugMode) {
        debugPrint('📊 Performance not initialized, skipping trace: $name');
      }
      return null;
    }

    try {
      final trace = _performance!.newTrace(name);
      await trace.start();

      if (kDebugMode) {
        debugPrint('📊 Started trace: $name');
      }

      return trace;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📊 Error starting trace $name: $e');
      }
      return null;
    }
  }

  /// Track a synchronous operation with automatic trace management
  ///
  /// Example:
  /// ```dart
  /// final result = await performanceService.trackOperation(
  ///   'calculate_xirr',
  ///   () => calculateXirr(cashFlows),
  ///   metrics: {'cash_flow_count': cashFlows.length},
  /// );
  /// ```
  Future<T> trackOperation<T>(
    String traceName,
    Future<T> Function() operation, {
    Map<String, int>? metrics,
    Map<String, String>? attributes,
  }) async {
    final trace = await startTrace(traceName);

    try {
      // Add attributes before operation
      if (attributes != null && trace != null) {
        for (final entry in attributes.entries) {
          trace.putAttribute(entry.key, entry.value);
        }
      }

      // Execute operation
      final result = await operation();

      // Add metrics after operation
      if (metrics != null && trace != null) {
        for (final entry in metrics.entries) {
          trace.putMetric(entry.key, entry.value);
        }
      }

      return result;
    } finally {
      await trace?.stop();
    }
  }

  /// Track a synchronous operation with automatic trace management
  ///
  /// Example:
  /// ```dart
  /// final result = performanceService.trackSync(
  ///   'sort_investments',
  ///   () => investments.sort(),
  ///   metrics: {'investment_count': investments.length},
  /// );
  /// ```
  T trackSync<T>(
    String traceName,
    T Function() operation, {
    Map<String, int>? metrics,
    Map<String, String>? attributes,
  }) {
    // For sync operations, we can't use async trace management
    // So we just execute and log in debug mode
    if (kDebugMode) {
      final stopwatch = Stopwatch()..start();
      final result = operation();
      stopwatch.stop();
      debugPrint('📊 $traceName completed in ${stopwatch.elapsedMilliseconds}ms');
      return result;
    }

    return operation();
  }
}

