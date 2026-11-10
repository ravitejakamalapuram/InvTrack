/// The one place an ad is shown: an opt-in rewarded ad before the Tax-Year
/// CSV export.
///
/// Rules (owner decisions 2026-11-10): never in the first 7 days, at most 3
/// ads a day, never while Privacy mode is on, and never forced. If no ad can
/// be shown, the export simply goes ahead; the user is never stuck because of
/// an ad problem.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/ads/admob_rewarded_player.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String adsFirstOpenKey = 'ads_first_open_ms';
const String adsDayKey = 'ads_day';
const String adsDayCountKey = 'ads_day_count';

/// Name sent to Analytics for the only ad spot. Never a path or an id.
const String rewardedPlacementFyExport = 'fy_export_csv';

enum RewardedAdResult { earned, dismissed, unavailable }

/// Shows one rewarded ad. Replaced in tests.
abstract class RewardedAdPlayer {
  Future<RewardedAdResult> play();
}

abstract final class AdPolicy {
  static const Duration adFreePeriod = Duration(days: 7);
  static const int maxPerDay = 3;

  static bool mayOffer({
    required DateTime now,
    required DateTime? firstOpen,
    required int shownToday,
    required bool privacyMode,
  }) {
    if (privacyMode || firstOpen == null) return false;
    if (now.difference(firstOpen) < adFreePeriod) return false;
    return shownToday < maxPerDay;
  }
}

/// Saves the date of the first app open, once. Run at app start.
Future<void> recordFirstOpen(SharedPreferences prefs, DateTime now) async {
  if (prefs.containsKey(adsFirstOpenKey)) return;
  await prefs.setInt(adsFirstOpenKey, now.millisecondsSinceEpoch);
}

class ExportAdGate {
  ExportAdGate({
    required SharedPreferences prefs,
    required RewardedAdPlayer player,
    DateTime Function()? clock,
    void Function(String event)? onEvent,
  }) : _prefs = prefs,
       _player = player,
       _clock = clock ?? DateTime.now,
       _onEvent = onEvent;

  final SharedPreferences _prefs;
  final RewardedAdPlayer _player;
  final DateTime Function() _clock;
  final void Function(String event)? _onEvent;

  /// True when the export may go ahead. [askUser] shows the "watch an ad?"
  /// prompt and answers whether the user agreed.
  Future<bool> mayExport({
    required bool privacyMode,
    required Future<bool> Function() askUser,
  }) async {
    final now = _clock();
    final today = _dayKey(now);
    final shownToday = _prefs.getString(adsDayKey) == today
        ? (_prefs.getInt(adsDayCountKey) ?? 0)
        : 0;
    final firstOpenMs = _prefs.getInt(adsFirstOpenKey);
    final offer = AdPolicy.mayOffer(
      now: now,
      firstOpen: firstOpenMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(firstOpenMs),
      shownToday: shownToday,
      privacyMode: privacyMode,
    );
    if (!offer) return true;

    _onEvent?.call(AnalyticsEvents.rewardedPromptShown);
    if (!await askUser()) {
      _onEvent?.call(AnalyticsEvents.rewardedPromptDeclined);
      return false;
    }

    final result = await _player.play();
    if (result == RewardedAdResult.unavailable) {
      _onEvent?.call(AnalyticsEvents.rewardedAdUnavailable);
      return true;
    }
    await _prefs.setString(adsDayKey, today);
    await _prefs.setInt(adsDayCountKey, shownToday + 1);
    if (result == RewardedAdResult.earned) {
      _onEvent?.call(AnalyticsEvents.rewardedAdEarned);
      return true;
    }
    _onEvent?.call(AnalyticsEvents.rewardedAdDismissed);
    return false;
  }

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final exportAdGateProvider = Provider<ExportAdGate>((ref) {
  final analytics = ref.watch(analyticsServiceProvider);
  return ExportAdGate(
    prefs: ref.watch(sharedPreferencesProvider),
    player: AdMobRewardedPlayer(),
    onEvent: (event) => unawaited(
      analytics.logEvent(
        name: event,
        parameters: {'placement': rewardedPlacementFyExport},
      ),
    ),
  );
});
