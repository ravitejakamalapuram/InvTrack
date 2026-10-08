import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';

/// Keeps the Analytics user ID and the Crashlytics user identifier equal to
/// the signed-in account's UID, and empty when no one is signed in.
///
/// The one place these IDs are set, so a guest start, a link, a merge into
/// a Google account, a sign-out and a deletion all stay in step. Only the
/// UID is sent, never the email or name (CLAUDE.md rule 7). Watch it once,
/// from the app root.
final userIdentitySyncProvider = Provider<void>((ref) {
  String? syncedUid;
  var synced = false;
  ref.listen(authStateProvider, (_, next) {
    // Loading or failed: keep the IDs we have.
    if (!next.hasValue) return;
    final uid = next.value?.id;
    // A token refresh or a link re-emits the same UID.
    if (synced && uid == syncedUid) return;
    synced = true;
    syncedUid = uid;
    unawaited(
      _apply(ref, uid).then((ok) {
        // A failed update stays due, so the next emission of this UID (a
        // token refresh) tries again instead of keeping a stale ID.
        if (!ok && syncedUid == uid) synced = false;
      }),
    );
  }, fireImmediately: true);
});

/// Sets both IDs to [uid], or clears them when it is null. Returns whether
/// both calls succeeded.
Future<bool> _apply(Ref ref, String? uid) async {
  try {
    final analytics = ref.read(analyticsServiceProvider);
    final crashlytics = ref.read(crashlyticsServiceProvider);
    await Future.wait([
      analytics.setUserId(uid),
      uid == null
          ? crashlytics.clearUserIdentifier()
          : crashlytics.setUserIdentifier(uid),
    ]);
    return true;
  } catch (e, st) {
    // Losing an ID update must never break sign-in or sign-out.
    LoggerService.warn(
      'Could not update the user ID for analytics and crash reports',
      error: e,
      stackTrace: st,
    );
    return false;
  }
}
