import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/sync/domain/services/sync_service.dart';

final syncStatusProvider = StateNotifierProvider<SyncStatusNotifier, AsyncValue<DateTime?>>((ref) {
  return SyncStatusNotifier(ref);
});

class SyncStatusNotifier extends StateNotifier<AsyncValue<DateTime?>> {
  final Ref _ref;

  SyncStatusNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> sync() async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(syncServiceProvider).sync();
      state = AsyncValue.data(DateTime.now());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
