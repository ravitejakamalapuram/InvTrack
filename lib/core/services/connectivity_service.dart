import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for the connectivity service.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityServiceImpl();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Service for checking internet connectivity.
abstract class ConnectivityService {
  /// Check if device has active internet connection.
  /// Returns true if we can reach the internet.
  Future<bool> hasInternetConnection();

  /// Stream of connectivity changes (for real-time UI updates).
  /// Emits true when internet becomes available, false when lost.
  Stream<bool> get onConnectivityChanged;
}

/// Implementation of ConnectivityService that actually checks connectivity.
class ConnectivityServiceImpl implements ConnectivityService {
  /// Timeout for connectivity check.
  static const Duration _timeout = Duration(seconds: 5);

  /// Polling interval for connectivity checks.
  static const Duration _pollInterval = Duration(seconds: 10);

  /// Stream controller for connectivity changes.
  final _connectivityController = StreamController<bool>.broadcast();

  /// Timer for periodic connectivity checks.
  Timer? _pollTimer;

  /// Last known connectivity state.
  bool? _lastKnownState;

  ConnectivityServiceImpl() {
    // Start polling for connectivity changes
    _startPolling();
  }

  void _startPolling() {
    // Check immediately
    _checkAndEmit();

    // Then poll periodically
    _pollTimer = Timer.periodic(_pollInterval, (_) => _checkAndEmit());
  }

  Future<void> _checkAndEmit() async {
    final isConnected = await hasInternetConnection();
    if (_lastKnownState != isConnected) {
      _lastKnownState = isConnected;
      _connectivityController.add(isConnected);
      debugPrint('[Connectivity] State changed: ${isConnected ? 'online' : 'offline'}');
    }
  }

  @override
  Stream<bool> get onConnectivityChanged => _connectivityController.stream;

  @override
  Future<bool> hasInternetConnection() async {
    // On web, we assume internet is available (browser handles offline)
    if (kIsWeb) {
      return true;
    }

    try {
      // Try to lookup Google's DNS - a reliable way to check connectivity
      final result = await InternetAddress.lookup('google.com')
          .timeout(_timeout);
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      debugPrint('[Connectivity] No internet - SocketException');
      return false;
    } on TimeoutException catch (_) {
      debugPrint('[Connectivity] No internet - Timeout');
      return false;
    } catch (e) {
      debugPrint('[Connectivity] Error checking connectivity: $e');
      return false;
    }
  }

  /// Dispose resources.
  void dispose() {
    _pollTimer?.cancel();
    _connectivityController.close();
  }
}

