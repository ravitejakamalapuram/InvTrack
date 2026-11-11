import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/ads/rewarded_export_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePlayer implements RewardedAdPlayer {
  _FakePlayer(this.result);
  final RewardedAdResult result;
  int plays = 0;

  @override
  Future<RewardedAdResult> play() async {
    plays++;
    return result;
  }
}

final _firstOpen = DateTime(2026, 11, 1, 9);
final _afterAdFree = DateTime(2026, 11, 8, 9); // exactly 7 days later

Future<(ExportAdGate, _FakePlayer, SharedPreferences)> _gate(
  RewardedAdResult result, {
  DateTime? now,
  Map<String, Object> prefs = const {},
  void Function(String)? onEvent,
}) async {
  SharedPreferences.setMockInitialValues({
    adsFirstOpenKey: _firstOpen.millisecondsSinceEpoch,
    ...prefs,
  });
  final p = await SharedPreferences.getInstance();
  final player = _FakePlayer(result);
  return (
    ExportAdGate(
      prefs: p,
      player: player,
      clock: () => now ?? _afterAdFree,
      onEvent: onEvent,
    ),
    player,
    p,
  );
}

void main() {
  group('AdPolicy.mayOffer', () {
    bool offer({
      DateTime? now,
      DateTime? firstOpen,
      int shownToday = 0,
      bool privacy = false,
    }) => AdPolicy.mayOffer(
      now: now ?? _afterAdFree,
      firstOpen: firstOpen ?? _firstOpen,
      shownToday: shownToday,
      privacyMode: privacy,
    );

    test('no ad in the first 7 days', () {
      expect(offer(now: DateTime(2026, 11, 8, 8, 59)), isFalse);
      expect(offer(now: DateTime(2026, 11, 2)), isFalse);
    });

    test('an ad may be offered from the 7th day on', () {
      expect(offer(), isTrue);
    });

    test('at most 3 ads a day', () {
      expect(offer(shownToday: 2), isTrue);
      expect(offer(shownToday: 3), isFalse);
    });

    test('never while Privacy mode is on', () {
      expect(offer(privacy: true), isFalse);
    });

    test('never when the first open date is unknown', () {
      expect(
        AdPolicy.mayOffer(
          now: _afterAdFree,
          firstOpen: null,
          shownToday: 0,
          privacyMode: false,
        ),
        isFalse,
      );
    });
  });

  group('ExportAdGate.mayExport', () {
    test('export is free when no ad may be offered', () async {
      final (gate, player, _) = await _gate(
        RewardedAdResult.earned,
        now: DateTime(2026, 11, 3),
      );
      var asked = false;
      final ok = await gate.mayExport(
        privacyMode: false,
        askUser: () async => asked = true,
      );
      expect(ok, isTrue);
      expect(asked, isFalse);
      expect(player.plays, 0);
    });

    test('declining the prompt means no ad and no export', () async {
      final (gate, player, p) = await _gate(RewardedAdResult.earned);
      final ok = await gate.mayExport(
        privacyMode: false,
        askUser: () async => false,
      );
      expect(ok, isFalse);
      expect(player.plays, 0);
      expect(p.getInt(adsDayCountKey), isNull);
    });

    test('watching the whole ad allows the export and is counted', () async {
      final (gate, player, p) = await _gate(RewardedAdResult.earned);
      final ok = await gate.mayExport(
        privacyMode: false,
        askUser: () async => true,
      );
      expect(ok, isTrue);
      expect(player.plays, 1);
      expect(p.getString(adsDayKey), '2026-11-08');
      expect(p.getInt(adsDayCountKey), 1);
    });

    test('sends one event per step, and nothing else', () async {
      final events = <String>[];
      final (gate, _, _) = await _gate(
        RewardedAdResult.earned,
        onEvent: events.add,
      );
      await gate.mayExport(privacyMode: false, askUser: () async => true);
      expect(events, ['rewarded_prompt_shown', 'rewarded_ad_earned']);

      events.clear();
      final (declined, _, _) = await _gate(
        RewardedAdResult.earned,
        onEvent: events.add,
      );
      await declined.mayExport(privacyMode: false, askUser: () async => false);
      expect(events, ['rewarded_prompt_shown', 'rewarded_prompt_declined']);
    });

    test('closing the ad early does not allow the export', () async {
      final (gate, _, p) = await _gate(RewardedAdResult.dismissed);
      final ok = await gate.mayExport(
        privacyMode: false,
        askUser: () async => true,
      );
      expect(ok, isFalse);
      expect(p.getInt(adsDayCountKey), 1);
    });

    test(
      'no ad available never blocks the export, and is not counted',
      () async {
        final (gate, _, p) = await _gate(RewardedAdResult.unavailable);
        final ok = await gate.mayExport(
          privacyMode: false,
          askUser: () async => true,
        );
        expect(ok, isTrue);
        expect(p.getInt(adsDayCountKey), isNull);
      },
    );

    test('the third ad of the day is the last', () async {
      final (gate, player, _) = await _gate(
        RewardedAdResult.earned,
        prefs: {adsDayKey: '2026-11-08', adsDayCountKey: 3},
      );
      var asked = false;
      final ok = await gate.mayExport(
        privacyMode: false,
        askUser: () async => asked = true,
      );
      expect(ok, isTrue);
      expect(asked, isFalse);
      expect(player.plays, 0);
    });

    test('the count starts again on a new day', () async {
      final (gate, _, p) = await _gate(
        RewardedAdResult.earned,
        prefs: {adsDayKey: '2026-11-07', adsDayCountKey: 3},
      );
      final ok = await gate.mayExport(
        privacyMode: false,
        askUser: () async => true,
      );
      expect(ok, isTrue);
      expect(p.getString(adsDayKey), '2026-11-08');
      expect(p.getInt(adsDayCountKey), 1);
    });

    test('Privacy mode skips the ad completely', () async {
      final (gate, player, _) = await _gate(RewardedAdResult.earned);
      var asked = false;
      final ok = await gate.mayExport(
        privacyMode: true,
        askUser: () async => asked = true,
      );
      expect(ok, isTrue);
      expect(asked, isFalse);
      expect(player.plays, 0);
    });
  });

  group('ExportAdGate.offerAfterExport', () {
    test('declining just ends it, nothing is shown or counted', () async {
      final (gate, player, p) = await _gate(RewardedAdResult.earned);
      await gate.offerAfterExport(
        privacyMode: false,
        askUser: () async => false,
      );
      expect(player.plays, 0);
      expect(p.getInt(adsDayCountKey), isNull);
    });

    test('agreeing plays one ad and counts it', () async {
      final (gate, player, p) = await _gate(RewardedAdResult.earned);
      await gate.offerAfterExport(
        privacyMode: false,
        askUser: () async => true,
      );
      expect(player.plays, 1);
      expect(p.getInt(adsDayCountKey), 1);
    });

    test('nothing is asked in Privacy mode or in the first 7 days', () async {
      var asked = 0;
      final (gate, player, _) = await _gate(RewardedAdResult.earned);
      await gate.offerAfterExport(
        privacyMode: true,
        askUser: () async => ++asked > 0,
      );
      final (early, _, _) = await _gate(
        RewardedAdResult.earned,
        now: DateTime(2026, 11, 3),
      );
      await early.offerAfterExport(
        privacyMode: false,
        askUser: () async => ++asked > 0,
      );
      expect(asked, 0);
      expect(player.plays, 0);
    });
  });

  group('recordFirstOpen', () {
    test('saves the first date once and never overwrites it', () async {
      SharedPreferences.setMockInitialValues({});
      final p = await SharedPreferences.getInstance();
      await recordFirstOpen(p, DateTime(2026, 11, 1));
      await recordFirstOpen(p, DateTime(2026, 12, 25));
      expect(
        p.getInt(adsFirstOpenKey),
        DateTime(2026, 11, 1).millisecondsSinceEpoch,
      );
    });
  });
}
