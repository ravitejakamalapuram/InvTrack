import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/sync/presentation/providers/sync_provider.dart';
import 'package:intl/intl.dart';

class SyncStatusIcon extends ConsumerWidget {
  const SyncStatusIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStatusProvider);

    return IconButton(
      onPressed: () {
        ref.read(syncStatusProvider.notifier).sync();
      },
      icon: syncState.when(
        data: (lastSynced) {
          return const Icon(Icons.cloud_done_outlined);
        },
        loading: () => const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        error: (err, stack) => const Icon(Icons.cloud_off_outlined, color: Colors.red),
      ),
      tooltip: syncState.when(
        data: (lastSynced) => lastSynced != null 
            ? 'Last synced: ${DateFormat.Hm().format(lastSynced)}' 
            : 'Sync Now',
        loading: () => 'Syncing...',
        error: (err, stack) => 'Sync Failed: $err',
      ),
    );
  }
}
