import 'dart:async';

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

/// True while this device runs Delete Account or Delete Guest Data. The
/// banner offers no Withdraw meanwhile: withdrawing mid-wipe would leave the
/// deletion running with no request for the server job to finish it.
final deletionInProgressProvider =
    NotifierProvider<DeletionInProgressNotifier, bool>(
      DeletionInProgressNotifier.new,
    );

class DeletionInProgressNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void start() => state = true;

  void finish() => state = false;
}

/// The status the banner keeps showing after a withdrawal the server has not
/// acknowledged (offline, or no answer in time); null otherwise.
///
/// Firestore drops the document from this device's view as soon as the
/// delete is issued, so [deletionRequestStatusProvider] alone would read "no
/// request" while the server may still hold it and the job would still
/// delete the account. Kept until a withdrawal succeeds, the queued delete
/// reaches the server, or the user changes.
final deletionWithdrawalProvider =
    NotifierProvider<DeletionWithdrawalNotifier, DeletionRequestStatus?>(
      DeletionWithdrawalNotifier.new,
    );

class DeletionWithdrawalNotifier extends Notifier<DeletionRequestStatus?> {
  // Bumped by every build (a new user) and every withdrawal, so a late
  // answer for an earlier one changes nothing.
  int _generation = 0;

  @override
  DeletionRequestStatus? build() {
    ref.watch(authStateProvider.select((s) => s.value?.id));
    _generation++;
    return null;
  }

  /// Withdraws the request the banner shows as [shown]. Returns true when the
  /// server accepted it. On false, [shown] stays on screen until a retry
  /// succeeds or the queued delete reaches the server.
  Future<bool> withdraw(DeletionRequestStatus shown) async {
    final requests = ref.read(deletionRequestServiceProvider);
    final generation = ++_generation;
    final withdrawn = await requests.withdraw();
    if (!ref.mounted || generation != _generation) return withdrawn;
    if (withdrawn) {
      state = null;
      return true;
    }
    state = shown;
    unawaited(
      requests.pendingWritesSent().then((sent) {
        if (sent && ref.mounted && generation == _generation) state = null;
      }),
    );
    return false;
  }
}
