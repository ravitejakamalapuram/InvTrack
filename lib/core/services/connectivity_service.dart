import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for the connectivity service.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityServiceImpl();
});

/// Service for checking internet connectivity.
abstract class ConnectivityService {
  /// Check if device has active internet connection.
  /// Returns true if we can reach the internet.
  Future<bool> hasInternetConnection();
}

/// Implementation of ConnectivityService that actually checks connectivity.
class ConnectivityServiceImpl implements ConnectivityService {
  /// Timeout for connectivity check.
  static const Duration _timeout = Duration(seconds: 5);

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
}

