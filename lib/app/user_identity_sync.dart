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
  String? desiredUid;
  String? syncedUid;
  // "Nothing sent yet" is not the same as "sent, and it was null": starting
  // signed out has to clear both IDs once, which a null/null comparison
  // alone would skip.
  var hasSynced = false;
  int emissionVersion = 0;
  bool applying = false;

  // Declared before the listener: `fireImmediately` runs the listener during
  // this build, so the function has to exist by then.
  Future<void> drain() async {
    if (applying) return;
    applying = true;
    try {
      while (!hasSynced || desiredUid != syncedUid) {
        final targetUid = desiredUid;
        final targetVersion = emissionVersion;
        // Either service may change even if this attempt fails. Invalidate
        // the old sync so returning to its UID still reapplies both IDs.
        hasSynced = false;
        final ok = await _apply(ref, targetUid);
        if (ok && desiredUid == targetUid) {
          syncedUid = targetUid;
          hasSynced = true;
        }

        // If the update failed and no newer auth emission arrived, leave the
        // target unsynced so the next auth emission retries it. If an emission
        // arrived while this attempt was pending, retry even when the UID is
        // unchanged.
        if (!ok && emissionVersion == targetVersion) break;
      }
    } finally {
      applying = false;
    }
  }

  ref.listen(authStateProvider, (_, next) {
    // Loading or failed: keep the IDs we have.
    if (!next.hasValue) return;
    desiredUid = next.value?.id;
    emissionVersion++;

    // A token refresh/link can emit the same UID while the previous update is
    // still in flight. Keep that emission as durable demand so a failure of
    // the in-flight update cannot silently discard the retry.
    if (applying || (hasSynced && syncedUid == desiredUid)) return;
    unawaited(drain());
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
