// Shared by card_guard_360_test.dart and card_guard_411_test.dart.
//
// Alignment of the details inside cards, on the real widgets with demo data:
//  - the Overview hero: the return badge shares the figure's baseline, and the
//    stats are equal columns that end on the card padding;
//  - the goal cards: the footer text ends on the same edge as the progress ring
//    and the chip is never cut in the middle of a word; the carousel card fits
//    its slot;
//  - the Investment detail: the XIRR and MOIC tiles share a top, a height and a
//    value baseline;
//  - the Overview quick stats (MOIC, cash flows): two tiles share a top and a
//    height.
// Each is also checked with privacy mode on and read right to left, and fails on
// any overflow. The rules are in design/system/README.md ("Card alignment").
import 'package:flutter_test/flutter_test.dart';

import 'card_guard_detail.dart';
import 'card_guard_goals.dart';
import 'card_guard_harness.dart';
import 'card_guard_hero.dart';
import 'card_guard_quickstats.dart';
import 'layout_guard_harness.dart' show guardTextScales;

/// One `testWidgets` per card and text scale at [width] dp.
void defineCardGuardTests({required double width}) {
  final w = width.toInt();
  for (final scale in guardTextScales) {
    testWidgets('hero stats line up at ${w}dp, text x$scale', (tester) async {
      await runCardGuard(
        tester,
        width: width,
        textScale: scale,
        body: checkHeroCards,
      );
    });
    testWidgets('goal cards end their footer on the ring edge at ${w}dp, '
        'text x$scale', (tester) async {
      await runCardGuard(
        tester,
        width: width,
        textScale: scale,
        body: checkGoalCards,
      );
    });
    testWidgets('the goal carousel card fits its slot at ${w}dp, '
        'text x$scale', (tester) async {
      await runCardGuard(
        tester,
        width: width,
        textScale: scale,
        body: checkGoalCarousel,
      );
    });
    testWidgets('quick stats tiles share a top and a height at ${w}dp, '
        'text x$scale', (tester) async {
      await runCardGuard(
        tester,
        width: width,
        textScale: scale,
        body: checkQuickStats,
      );
    });
    testWidgets('detail XIRR and MOIC tiles line up at ${w}dp, '
        'text x$scale', (tester) async {
      await runCardGuard(
        tester,
        width: width,
        textScale: scale,
        body: checkDetailTiles,
      );
    });
  }

  // The system "bold text" setting makes the glyphs wider at the same size, so
  // a footer or a badge that just fitted can stop fitting: every card again at
  // the text size a user with large text and bold text has.
  final cards = <(String, Future<void> Function(CardGuard))>[
    ('hero stats', checkHeroCards),
    ('goal cards', checkGoalCards),
    ('the goal carousel card', checkGoalCarousel),
    ('quick stats tiles', checkQuickStats),
    ('detail XIRR and MOIC tiles', checkDetailTiles),
  ];
  for (final (name, body) in cards) {
    testWidgets('$name hold with bold text at ${w}dp, text x1.3', (
      tester,
    ) async {
      await runCardGuard(
        tester,
        width: width,
        textScale: 1.3,
        boldText: true,
        body: body,
      );
    });
  }
}
