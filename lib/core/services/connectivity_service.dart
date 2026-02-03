import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service for monitoring network connectivity status
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Stream of connectivity status changes
  /// Emits true when connected, false when disconnected
  Stream<bool> get connectivityStream {
    return _connectivity.onConnectivityChanged.map((results) {
      final isConnected = results.any((result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet);

      if (kDebugMode) {
        debugPrint(
            '🌐 Connectivity changed: ${isConnected ? "ONLINE" : "OFFLINE"} (${results.join(", ")})');
      }

      return isConnected;
    });
  }

  /// Check current connectivity status
  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final isConnected = results.any((result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet);

      if (kDebugMode) {
        debugPrint(
            '🌐 Current connectivity: ${isConnected ? "ONLINE" : "OFFLINE"} (${results.join(", ")})');
      }

      return isConnected;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error checking connectivity: $e');
      }
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
  }
}

