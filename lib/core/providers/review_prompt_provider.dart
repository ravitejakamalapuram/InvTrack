import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/core/review/review_prompt_service.dart';

/// Provider for [ReviewPromptService], built off [sharedPreferencesProvider]
/// mirroring the placement and error handling of `in_app_update_provider.dart`.
final reviewPromptServiceProvider = Provider<ReviewPromptService>((ref) {
  return ReviewPromptService(
    prefs: ref.watch(sharedPreferencesProvider),
    launcher: const InAppReviewLauncher(),
    analytics: ref.watch(analyticsServiceProvider),
  );
});
