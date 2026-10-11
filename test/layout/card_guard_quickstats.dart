// The Quick Stats row of the Overview (MOIC and cash flows): two tiles that
// sit side by side share a top and a height, however many lines each one
// needs. Before, the row centred them, so a MOIC tile with a duration line was
// taller than the cash flows tile and the two tops were 6.5dp apart.
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/overview_quick_stats.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/quick_stat_card.dart';

import 'card_guard_harness.dart';

// Demo figures only.
final _withDuration = InvestmentStats(
  totalInvested: 409000,
  totalReturned: 522000,
  netCashFlow: 113000,
  absoluteReturn: 27.63,
  moic: 1.276,
  xirr: 0.22,
  cashFlowCount: 2,
  firstCashFlowDate: DateTime(2024, 1, 1),
  lastCashFlowDate: DateTime(2026, 4, 1),
);

final _noDates = InvestmentStats(
  totalInvested: 409000,
  totalReturned: 522000,
  netCashFlow: 113000,
  absoluteReturn: 27.63,
  moic: 1.276,
  xirr: 0.22,
  cashFlowCount: 12,
);

/// An open portfolio with no current value: MOIC waits and says why.
final _awaiting = InvestmentStats(
  totalInvested: 500000,
  totalReturned: 10000,
  netCashFlow: -490000,
  absoluteReturn: -98,
  moic: 0.02,
  xirr: null,
  xirrMethod: XirrMethod.undefined,
  cashFlowCount: 2,
  firstCashFlowDate: DateTime(2024, 1, 1),
  lastCashFlowDate: DateTime(2025, 1, 1),
  missingValueCount: 1,
);

class _QuickCase {
  const _QuickCase(this.name, this.stats, this.open);
  final String name;
  final InvestmentStats stats;
  final InvestmentStats open;
}

final _quickCases = [
  _QuickCase('MOIC with a duration line', _withDuration, _withDuration),
  _QuickCase('MOIC without a duration line', _noDates, _noDates),
  _QuickCase('MOIC awaiting a current value', _awaiting, _awaiting),
];

/// Every case at the width and text scale of [g]: plain, with privacy mode on,
/// and read right to left.
Future<void> checkQuickStats(CardGuard g) async {
  for (final c in _quickCases) {
    for (final (privacy, rtl) in const [
      (false, false),
      (true, false),
      (false, true),
    ]) {
      g.scope =
          '${c.name}${privacy ? ', privacy mode' : ''}${rtl ? ', right to left' : ''}';
      await g.pump(
        OverviewQuickStats(stats: c.stats, openStats: c.open),
        privacy: privacy,
        rtl: rtl,
      );
      final tiles = [
        for (var k = 0; k < 2; k++)
          g.rect(
            'tile $k',
            find.descendant(
              of: find.byType(QuickStatCard).at(k),
              matching: find.byType(GlassCard),
            ),
          ),
      ];
      final a = tiles[0];
      final b = tiles[1];
      if (a == null || b == null) continue;
      // One top, one height, equal widths, in reading order.
      g.expectNear('cash flows tile top', b.top, a.top);
      g.expectNear('cash flows tile height', b.height, a.height);
      g.expectNear('cash flows tile width', b.width, a.width);
      final first = rtl ? b : a;
      final second = rtl ? a : b;
      if (first.center.dx >= second.center.dx) {
        g.fault('the tiles are not in reading order');
      }
    }
  }
}
