import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/providers/in_app_update_provider.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/core/review/review_prompt_service.dart';

/// Provider for [ReviewPromptService], built off [sharedPreferencesProvider]
/// mirroring the placement and error handling of `in_app_update_provider.dart`.
///
/// [ReviewPromptService.maybeRequestAfterExitRecorded] is invoked after a
/// scheduling delay from a screen that may already be disposed by then, so
/// the pending-update check is wired here via `ref.read` (this provider's
/// own long-lived `ref`, not the screen's) rather than a value the caller
/// captured ahead of time.
final reviewPromptServiceProvider = Provider<ReviewPromptService>((ref) {
  return ReviewPromptService(
    prefs: ref.watch(sharedPreferencesProvider),
    launcher: const InAppReviewLauncher(),
    analytics: ref.watch(analyticsServiceProvider),
    isUpdatePending: () {
      final updateState = ref.read(inAppUpdateProvider);
      return updateState.hasUpdate || updateState.isDownloaded;
    },
  );
});
