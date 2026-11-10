/// Shows a Google AdMob rewarded ad. Non-personalised only.
library;

import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:inv_tracker/core/ads/rewarded_export_gate.dart';

/// Google's published test rewarded ad unit. Release builds must pass the real
/// one: `--dart-define=REWARDED_AD_UNIT_ID=ca-app-pub-.../...`.
const String _testRewardedAdUnit = 'ca-app-pub-3940256099942544/5224354917';
const String rewardedAdUnitId = String.fromEnvironment(
  'REWARDED_AD_UNIT_ID',
  defaultValue: _testRewardedAdUnit,
);

class AdMobRewardedPlayer implements RewardedAdPlayer {
  static const _timeout = Duration(seconds: 20);

  @override
  Future<RewardedAdResult> play() async {
    try {
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
    final done = Completer<void>();
    void finish() {
      if (!done.isCompleted) done.complete();
    }

    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired((_) => finish()),
      (_) => finish(),
    );
    await done.future.timeout(_timeout, onTimeout: () {});
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
