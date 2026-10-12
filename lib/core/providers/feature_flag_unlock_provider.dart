/// Lets a release build open the feature-flag toggles (#1012).
///
/// Tapping the app version five times in About switches this on. It is held in
/// memory only, so it ends when the app restarts, and it ends when the
/// signed-in account changes or signs out. It opens the feature-flag screen and
/// nothing else: the data tools in Debug Settings (demo-data seeding, the
/// crash button) stay behind `developerToolsAvailableProvider`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';

/// Whether the feature-flag toggles are unlocked for the current account.
final featureFlagUnlockProvider =
    NotifierProvider<FeatureFlagUnlockNotifier, bool>(
      FeatureFlagUnlockNotifier.new,
    );

class FeatureFlagUnlockNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Watching the account id rebuilds this to locked when it changes.
    ref.watch(authStateProvider.select((user) => user.value?.id));
    return false;
  }

  /// Unlocks, or locks again when it is already unlocked.
  void toggle() => state = !state;
}
