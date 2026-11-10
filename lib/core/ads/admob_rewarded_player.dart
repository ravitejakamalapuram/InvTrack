/// Shows a Google AdMob rewarded ad. Non-personalised only.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:inv_tracker/core/ads/rewarded_export_gate.dart';

/// Google's published test rewarded ad unit. Debug and test builds use it, so
/// we never click our own real ads.
const String _testRewardedAdUnit = 'ca-app-pub-3940256099942544/5224354917';

/// InvTrack's real rewarded ad unit "fy_export_csv" (public, safe to commit).
const String _liveRewardedAdUnit = 'ca-app-pub-7886969733687639/6600871162';

/// Release builds use the live unit; `--dart-define=REWARDED_AD_UNIT_ID=...`
/// overrides either.
const String rewardedAdUnitId = String.fromEnvironment(
  'REWARDED_AD_UNIT_ID',
  defaultValue: kReleaseMode ? _liveRewardedAdUnit : _testRewardedAdUnit,
);

class AdMobRewardedPlayer implements RewardedAdPlayer {
  static const _timeout = Duration(seconds: 20);

  @override
  Future<RewardedAdResult> play() async {
    try {
      // A release build without the real ad unit must not show test ads to
      // real users; the export just goes ahead.
      if (kReleaseMode && rewardedAdUnitId == _testRewardedAdUnit) {
        return RewardedAdResult.unavailable;
      }
      if (!await _consentAllowsAds()) return RewardedAdResult.unavailable;
      await MobileAds.instance.initialize();
      final ad = await _load();
      if (ad == null) return RewardedAdResult.unavailable;
      return await _show(ad);
    } catch (_) {
      // Any ad problem must never block the export.
      return RewardedAdResult.unavailable;
    }
  }

  /// Google's consent form (UMP). It appears only where the law requires it,
  /// such as the EU and UK; elsewhere this finishes without showing anything.
  Future<bool> _consentAllowsAds() async {
    // The timeout covers only the network update. The consent form itself
    // waits for the user, as long as they need.
    final updated = Completer<bool>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        if (!updated.isCompleted) updated.complete(true);
      },
      (_) {
        if (!updated.isCompleted) updated.complete(false);
      },
    );
    final ok = await updated.future.timeout(_timeout, onTimeout: () => false);
    if (ok) {
      final dismissed = Completer<void>();
      await ConsentForm.loadAndShowConsentFormIfRequired((_) {
        if (!dismissed.isCompleted) dismissed.complete();
      });
      await dismissed.future;
    }
    return ConsentInformation.instance.canRequestAds();
  }

  Future<RewardedAd?> _load() async {
    final loaded = Completer<RewardedAd?>();
    await RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(nonPersonalizedAds: true),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: loaded.complete,
        onAdFailedToLoad: (_) => loaded.complete(null),
      ),
    );
    return loaded.future.timeout(_timeout, onTimeout: () => null);
  }

  Future<RewardedAdResult> _show(RewardedAd ad) {
    final result = Completer<RewardedAdResult>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        result.complete(
          earned ? RewardedAdResult.earned : RewardedAdResult.dismissed,
        );
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        result.complete(RewardedAdResult.unavailable);
      },
    );
    ad.show(onUserEarnedReward: (_, _) => earned = true);
    return result.future;
  }
}
