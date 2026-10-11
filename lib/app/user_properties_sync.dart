import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';

/// Keeps the Analytics user properties `is_guest` and `base_currency` equal to
/// the signed-in account's state, and empty when no one is signed in.
///
/// The one place these properties are set. Each is sent when it changes, not
/// on every emission: linking a guest to Google keeps the UID, so only the
/// property changes. A write that fails is sent again at the next sync.
/// Nothing about the portfolio (how many investments, goals)
/// is sent until the user can turn analytics off (A34). Watch it once, from
/// the app root.
final userPropertiesSyncProvider = Provider<void>((ref) {
  // What was last sent, by property. Absent until sent: starting signed out
  // has to clear both once, which comparing null with null would skip.
  final sent = <String, String?>{};

  void sync() {
    final auth = ref.read(authStateProvider);
    // Loading or failed: keep what was sent.
    if (!auth.hasValue) return;
    final user = auth.value;
    final desired = <String, String?>{
      'is_guest': user == null ? null : '${user.isAnonymous}',
      'base_currency': user == null ? null : ref.read(currencyCodeProvider),
    };
    for (final MapEntry(:key, :value) in desired.entries) {
      if (sent.containsKey(key) && sent[key] == value) continue;
      // Marked at once, so a sync while the write is in flight does not repeat
      // it. A failed write is unmarked, so the next sync sends it again, unless
      // a newer value has been sent since.
      sent[key] = value;
      unawaited(
        _set(ref, key, value).then((written) {
          if (!written && sent.containsKey(key) && sent[key] == value) {
            sent.remove(key);
          }
        }),
      );
    }
  }

  ref.listen(authStateProvider, (_, _) => sync(), fireImmediately: true);
  ref.listen(currencyCodeProvider, (_, _) => sync());
});

/// Whether the property was written. Never throws.
Future<bool> _set(Ref ref, String name, String? value) async {
  try {
    return await ref
        .read(analyticsServiceProvider)
        .setUserProperty(name: name, value: value);
  } catch (e, st) {
    // Losing a property update must never break sign-in or sign-out.
    LoggerService.warn(
      'Could not update an analytics user property',
      error: e,
      stackTrace: st,
    );
    return false;
  }
}
