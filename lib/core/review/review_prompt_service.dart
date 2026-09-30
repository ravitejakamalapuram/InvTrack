import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:in_app_review/in_app_review.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Narrow seam over the Play in-app review API so tests can inject a fake
/// instead of driving the real (platform-channel-backed) plugin.
abstract class ReviewLauncher {
  Future<bool> isAvailable();
  Future<void> requestReview();
}

/// Real adapter wrapping [InAppReview.instance].
class InAppReviewLauncher implements ReviewLauncher {
  const InAppReviewLauncher();

  @override
  Future<bool> isAvailable() => InAppReview.instance.isAvailable();

  @override
  Future<void> requestReview() => InAppReview.instance.requestReview();
}

/// Requests the Play in-app review sheet at most once per install, after a
/// genuine success moment (recording a return/exit cash flow).
///
/// See `company-brain/decisions/0001-invtrack-in-app-review-prompt.md` for the
/// gating rationale.
class ReviewPromptService {
  ReviewPromptService({
    required SharedPreferences prefs,
    required ReviewLauncher launcher,
    required AnalyticsService analytics,
    required bool Function() isUpdatePending,
    bool Function()? isSupportedPlatform,
  }) : _prefs = prefs,
       _launcher = launcher,
       _analytics = analytics,
       _isUpdatePending = isUpdatePending,
       _isSupportedPlatform =
           isSupportedPlatform ?? (() => !kIsWeb && Platform.isAndroid);

  final SharedPreferences _prefs;
  final ReviewLauncher _launcher;
  final AnalyticsService _analytics;

  /// Re-read at request time rather than a value the caller captured ahead
  /// of the scheduling delay, so an update that becomes pending during that
  /// window is still honored.
  final bool Function() _isUpdatePending;

  /// Defaults to the real `!kIsWeb && Platform.isAndroid` check; overridable
  /// so tests can exercise the Android path from a host test runner, where
  /// `Platform.isAndroid` is always false.
  final bool Function() _isSupportedPlatform;

  static const _requestedAtKey = 'review_prompt_v1_requested_at';

  /// Guards against two overlapping calls both reading `_requestedAtKey` as
  /// unset before either has written it.
  bool _isChecking = false;

  /// Call after a return/exit cash flow is recorded. Every check is local
  /// and every failure is swallowed; nothing here can throw into the caller.
  Future<void> maybeRequestAfterExitRecorded() async {
    if (_isChecking) return;
    _isChecking = true;
    try {
      if (!_isSupportedPlatform()) return;

      if (_prefs.containsKey(_requestedAtKey)) return;

      if (_isUpdatePending()) return;

      final available = await _launcher.isAvailable();
      if (!available) return;

      await _prefs.setInt(
        _requestedAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      await _launcher.requestReview();

      await _analytics.logEvent(name: 'review_prompt_requested');
    } catch (e, st) {
      LoggerService.warn(
        'Review prompt request failed',
        metadata: {'error': e.toString()},
        error: e,
        stackTrace: st,
      );
    } finally {
      _isChecking = false;
    }
  }
}
