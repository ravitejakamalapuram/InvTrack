import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';

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

      LoggerService.info(
        'Connectivity changed',
        metadata: {
          'status': isConnected ? 'ONLINE' : 'OFFLINE',
          'results': results.map((r) => r.name).join(', '),
        },
      );

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

      LoggerService.debug(
        'Current connectivity',
        metadata: {
          'status': isConnected ? 'ONLINE' : 'OFFLINE',
          'results': results.map((r) => r.name).join(', '),
        },
      );

      return isConnected;
    } catch (e) {
      LoggerService.error(
        'Error checking connectivity',
        error: e,
        metadata: {'operation': 'checkConnectivity'},
      );
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
  }
}

