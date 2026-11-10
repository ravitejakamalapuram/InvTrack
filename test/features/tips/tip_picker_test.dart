// Daily tip picker: random, never repeats until every tip has been seen.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/tips/domain/tip.dart';
import 'package:inv_tracker/features/tips/domain/tip_picker.dart';

List<Tip> _pool(int n) => [
  for (var i = 0; i < n; i++) Tip(id: 't$i', title: 'T$i', body: 'B$i'),
];

void main() {
  test('picks only tips that have not been seen', () {
    final pool = _pool(3);
    final pick = pickTip(pool, {'t0', 't2'}, Random(1));
    expect(pick.tip.id, 't1');
    expect(pick.seen, {'t0', 't1', 't2'});
  });

  test('going through the whole pool shows every tip exactly once', () {
    final pool = _pool(10);
    var seen = <String>{};
    final shown = <String>[];
    for (var i = 0; i < 10; i++) {
      final pick = pickTip(pool, seen, Random(i));
      shown.add(pick.tip.id);
      seen = pick.seen;
    }
    expect(shown.toSet().length, 10);
  });

  test('starts a new cycle when all are seen, not repeating the last tip', () {
    final pool = _pool(4);
    for (var seed = 0; seed < 50; seed++) {
      final pick = pickTip(
        pool,
        {'t0', 't1', 't2', 't3'},
        Random(seed),
        lastId: 't2',
      );
      expect(pick.tip.id, isNot('t2'));
      expect(pick.seen, {pick.tip.id});
    }
  });

  test('ignores seen ids that are no longer in the pool', () {
    final pick = pickTip(_pool(2), {'gone', 't0'}, Random(1));
    expect(pick.tip.id, 't1');
    expect(pick.seen, {'t0', 't1'});
  });

  test('a one-tip pool repeats that tip', () {
    final pick = pickTip(_pool(1), {'t0'}, Random(1), lastId: 't0');
    expect(pick.tip.id, 't0');
  });
}
