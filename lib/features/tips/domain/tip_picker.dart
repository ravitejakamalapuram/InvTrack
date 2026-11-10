/// Picks the next daily tip: random, and none twice until all have been seen.
library;

import 'dart:math';

import 'package:inv_tracker/features/tips/domain/tip.dart';

class TipPick {
  const TipPick(this.tip, this.seen);
  final Tip tip;

  /// Seen ids including [tip].
  final Set<String> seen;
}

/// [pool] must not be empty. [lastId] is the tip shown last, so a new cycle
/// does not open with the tip the user has just read.
TipPick pickTip(
  List<Tip> pool,
  Set<String> seen,
  Random random, {
  String? lastId,
}) {
  final poolIds = pool.map((t) => t.id).toSet();
  var kept = seen.intersection(poolIds);
  var candidates = pool.where((t) => !kept.contains(t.id)).toList();
  if (candidates.isEmpty) {
    kept = {};
    candidates = pool.where((t) => pool.length == 1 || t.id != lastId).toList();
  }
  final tip = candidates[random.nextInt(candidates.length)];
  return TipPick(tip, {...kept, tip.id});
}
