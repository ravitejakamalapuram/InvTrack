/// Today's tip for the Overview card. One tip a day, picked at random from
/// the tips not yet seen; what was seen stays on the device only.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/features/tips/domain/tip.dart';
import 'package:inv_tracker/features/tips/domain/tip_picker.dart';

const dailyTipSeenKey = 'daily_tip_seen_ids';
const dailyTipTodayIdKey = 'daily_tip_today_id';
const dailyTipTodayDateKey = 'daily_tip_today_date';
const dailyTipDismissedDateKey = 'daily_tip_dismissed_date';
const dailyTipReadDateKey = 'daily_tip_read_date';

/// The tips bundled with the app.
final tipsPoolProvider = FutureProvider<List<Tip>>((ref) async {
  final raw = await rootBundle.loadString('assets/tips/tips.json');
  return [
    for (final e in jsonDecode(raw) as List)
      Tip.fromJson(e as Map<String, dynamic>),
  ];
});

/// The clock and the dice; tests replace them.
final dailyTipClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
final dailyTipRandomProvider = Provider<Random>((ref) => Random());

String _dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class DailyTipNotifier extends AsyncNotifier<Tip?> {
  @override
  Future<Tip?> build() async {
    final pool = await ref.watch(tipsPoolProvider.future);
    if (pool.isEmpty) return null;
    final prefs = ref.read(sharedPreferencesProvider);
    final today = _dayKey(ref.read(dailyTipClockProvider)());

    if (prefs.getString(dailyTipDismissedDateKey) == today) return null;

    final todayId = prefs.getString(dailyTipTodayIdKey);
    if (prefs.getString(dailyTipTodayDateKey) == today) {
      for (final t in pool) {
        if (t.id == todayId) return t;
      }
    }

    final pick = pickTip(
      pool,
      (prefs.getStringList(dailyTipSeenKey) ?? const []).toSet(),
      ref.read(dailyTipRandomProvider),
      lastId: todayId,
    );
    await prefs.setStringList(dailyTipSeenKey, pick.seen.toList());
    await prefs.setString(dailyTipTodayIdKey, pick.tip.id);
    await prefs.setString(dailyTipTodayDateKey, today);
    return pick.tip;
  }

  /// Hide the tip until tomorrow.
  Future<void> dismiss() async {
    final today = _dayKey(ref.read(dailyTipClockProvider)());
    state = const AsyncData(null);
    await ref
        .read(sharedPreferencesProvider)
        .setString(dailyTipDismissedDateKey, today);
    await ref.read(dailyTipUnreadProvider.notifier).markRead();
  }
}

final dailyTipProvider = AsyncNotifierProvider<DailyTipNotifier, Tip?>(
  DailyTipNotifier.new,
);

/// True until today's tip is opened from the bell or dismissed on the card.
class DailyTipUnreadNotifier extends Notifier<bool> {
  String get _today => _dayKey(ref.read(dailyTipClockProvider)());

  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getString(dailyTipReadDateKey) !=
      _today;

  Future<void> markRead() async {
    if (!state) return;
    state = false;
    await ref
        .read(sharedPreferencesProvider)
        .setString(dailyTipReadDateKey, _today);
  }
}

final dailyTipUnreadProvider = NotifierProvider<DailyTipUnreadNotifier, bool>(
  DailyTipUnreadNotifier.new,
);

/// Today's tip first, then earlier ones, newest first, up to 7. Includes a tip
/// dismissed from the card.
final dailyTipHistoryProvider = FutureProvider<List<Tip>>((ref) async {
  final pool = await ref.watch(tipsPoolProvider.future);
  await ref.watch(dailyTipProvider.future);
  final seen =
      ref.read(sharedPreferencesProvider).getStringList(dailyTipSeenKey) ??
      const <String>[];
  final byId = {for (final t in pool) t.id: t};
  return [
    for (final id in seen.reversed)
      if (byId[id] != null) byId[id]!,
  ].take(7).toList();
});
