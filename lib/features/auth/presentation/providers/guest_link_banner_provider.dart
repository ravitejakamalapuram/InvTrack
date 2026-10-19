/// Whether the Overview guest link banner (A43, #786) is visible.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/sample_data_provider.dart';

const guestLinkBannerDismissedKey = 'guest_link_banner_dismissed_at';
const guestLinkBannerSnooze = Duration(days: 14);

/// When the guest last dismissed the banner (device-local), or null.
class GuestLinkBannerDismissNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() {
    final ms = ref
        .watch(sharedPreferencesProvider)
        .getInt(guestLinkBannerDismissedKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> dismiss() async {
    final now = DateTime.now();
    state = now;
    await ref
        .read(sharedPreferencesProvider)
        .setInt(guestLinkBannerDismissedKey, now.millisecondsSinceEpoch);
  }
}

final guestLinkBannerDismissProvider =
    NotifierProvider<GuestLinkBannerDismissNotifier, DateTime?>(
      GuestLinkBannerDismissNotifier.new,
    );

/// True for a guest, with the flag on, outside sample-data mode, and not
/// within 14 days of a dismiss.
final guestLinkBannerVisibleProvider = Provider<bool>((ref) {
  if (!ref.watch(isGuestLinkBannerEnabledProvider)) return false;
  if (!(ref.watch(authStateProvider).value?.isAnonymous ?? false)) {
    return false;
  }
  if (ref.watch(sampleDataModeProvider).isActive) return false;
  final dismissed = ref.watch(guestLinkBannerDismissProvider);
  return dismissed == null ||
      DateTime.now().difference(dismissed) >= guestLinkBannerSnooze;
});
