import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/settings/data/services/deletion_request_service.dart';

/// Live status of the signed-in user's `deletionRequests/{uid}` document,
/// for the pending-request banner. [DeletionRequestStatus.none] when signed
/// out.
final deletionRequestStatusProvider =
    StreamProvider.autoDispose<DeletionRequestStatus>((ref) {
      final userId = ref.watch(authStateProvider.select((s) => s.value?.id));
      if (userId == null) return Stream.value(DeletionRequestStatus.none);
      return ref.watch(deletionRequestServiceProvider).watchStatus();
    });
