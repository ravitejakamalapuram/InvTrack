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
  int emissionVersion = 0;
  bool applying = false;

  ref.listen(authStateProvider, (_, next) {
    // Loading or failed: keep the IDs we have.
    if (!next.hasValue) return;
    desiredUid = next.value?.id;
    final version = ++emissionVersion;

    // A token refresh/link can emit the same UID while the previous update is
    // still in flight. Keep that emission as durable demand so a failure of
    // the in-flight update cannot silently discard the retry.
    if (applying || syncedUid == desiredUid && version == emissionVersion) {
      if (applying) return;
      return;
    }
    unawaited(_drain(ref));
  }, fireImmediately: true);

  Future<void> _drain(Ref ref) async {
    if (applying) return;
    applying = true;
    try {
      while (desiredUid != syncedUid) {
        final targetUid = desiredUid;
        final targetVersion = emissionVersion;
        final ok = await _apply(ref, targetUid);
        if (ok && desiredUid == targetUid) {
          syncedUid = targetUid;
        }

        // If the update failed and no newer auth emission arrived, leave the
        // target unsynced so the next auth emission retries it. If an emission
        // arrived while this attempt was pending, retry even when the UID is
        // unchanged.
        if (!ok && emissionVersion == targetVersion) break;
      }
    } finally {
      applying = false;
      if (desiredUid != syncedUid && emissionVersion > 0) {
        // A new emission may have arrived just after the loop observed its
        // condition. Schedule another drain rather than losing that demand.
        unawaited(_drain(ref));
      }
    }
  }
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
