import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/database/app_database.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/widgets/empty_state_widget.dart';
import 'package:inv_tracker/features/sync/domain/services/sync_service.dart';

final failedItemsProvider = FutureProvider<List<SyncQueueData>>((ref) async {
  final repo = ref.watch(syncRepositoryProvider);
  return repo.getFailedItems();
});

class SyncIssuesScreen extends ConsumerWidget {
  const SyncIssuesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failedItemsAsync = ref.watch(failedItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Sync Issues', style: AppTypography.h3),
      ),
      body: failedItemsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const EmptyStateWidget(
              title: 'No Sync Issues',
              message: 'Everything is synced correctly.',
              icon: Icons.check_circle_outline,
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                title: Text('${item.operation} ${item.entityType}'),
                subtitle: Text('ID: ${item.entityId}\nFailed at: ${item.createdAt}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.blue),
                      onPressed: () async {
                        // Retry logic: Reset status to PENDING and trigger sync
                        // We need to expose a method in SyncRepository or Service for this.
                        // For now, let's just delete and re-add or update status directly?
                        // Better: Add retryItem(id) to SyncService.
                        await ref.read(syncServiceProvider).retryItem(item.id);
                        return ref.refresh(failedItemsProvider);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await ref.read(syncRepositoryProvider).deleteItem(item.id);
                        return ref.refresh(failedItemsProvider);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
