import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/data/presentation/providers/data_provider.dart';

/// A simple cloud status icon that shows connectivity state.
///
/// In the cloud-first architecture, this icon:
/// - Shows cloud_done when online
/// - Shows cloud_off when offline
/// - Tapping refreshes data from cloud
class SyncStatusIcon extends ConsumerStatefulWidget {
  const SyncStatusIcon({super.key});

  @override
  ConsumerState<SyncStatusIcon> createState() => _SyncStatusIconState();
}

class _SyncStatusIconState extends ConsumerState<SyncStatusIcon> {
  bool _isRefreshing = false;

  Future<void> _refresh() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      final result = await ref.read(dataControllerProvider).refreshFromCloud();
      if (mounted) {
        if (result.isFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Refresh failed'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOfflineAsync = ref.watch(isOfflineProvider);
    final isGoogleUser = ref.watch(isGoogleUserProvider);

    // Don't show for guest users
    if (!isGoogleUser) {
      return const SizedBox.shrink();
    }

    final isOffline = isOfflineAsync.maybeWhen(
      data: (offline) => offline,
      orElse: () => false,
    );

    return IconButton(
      onPressed: _isRefreshing ? null : _refresh,
      icon: _isRefreshing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              isOffline ? Icons.cloud_off_outlined : Icons.cloud_done_outlined,
              color: isOffline ? Colors.orange : null,
            ),
      tooltip: _isRefreshing
          ? 'Refreshing...'
          : isOffline
              ? 'Offline'
              : 'Refresh from cloud',
    );
  }
}
