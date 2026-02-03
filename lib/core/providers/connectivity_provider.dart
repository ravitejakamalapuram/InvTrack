import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/services/connectivity_service.dart';

/// Provider for ConnectivityService instance
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Stream provider for connectivity status
/// Emits true when connected, false when disconnected
final connectivityStatusProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.connectivityStream;
});

/// Provider to check current connectivity status (one-time check)
final currentConnectivityProvider = FutureProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.checkConnectivity();
});

