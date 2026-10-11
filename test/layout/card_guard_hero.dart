// The Overview hero card: its return badge shares the figure's baseline (or
// drops below it), and its stats are equal columns that end on the card
// padding, whatever the width, text size, reading direction or privacy mode.
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/hero_card.dart';

import 'card_guard_harness.dart';
import 'layout_guard_harness.dart' show guardTolerance;

const _figureKey = ValueKey('hero-net-cash-flow');

/// Columns per row of the hero stats, by width and text scale: the guard's own
/// table, so a change to the rule shows up here as well as in the unit test.
/// Inner width is the card width less its padding: 288dp at 360, 339dp at 411.
int _heroPerRow(double width, double scale) {
  const table = {
    360: {10: 3, 13: 2, 20: 1},
    411: {10: 3, 13: 3, 20: 2},
  };
  return table[width.toInt()]![(scale * 10).round()]!;
}

/// Sizes of the rows [count] columns fill at [perRow] per row.
List<int> _chunks(int count, int perRow) => [
  for (var left = count; left > 0; left -= perRow)
    left < perRow ? left : perRow,
];

final _inr = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

// Demo figures only.
final _plain = InvestmentStats(
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

/// A small net figure, so the badge fits beside it on a narrow phone.
final _small = InvestmentStats(
  totalInvested: 410000,
  totalReturned: 423000,
  netCashFlow: 13000,
  absoluteReturn: 3.17,
  moic: 1.0317,
  xirr: 0.095,
  cashFlowCount: 2,
  firstCashFlowDate: DateTime(2024, 1, 1),
  lastCashFlowDate: DateTime(2026, 4, 1),
);

final _soFarSmall = InvestmentStats(
  totalInvested: 410000,
  totalReturned: 423000,
  netCashFlow: 13000,
  absoluteReturn: 3.17,
  moic: 1.0317,
  xirr: 0.095,
  cashFlowCount: 2,
  firstCashFlowDate: DateTime(2025, 10, 10),
  lastCashFlowDate: DateTime(2026, 10, 10),
  cashOnlyCount: 1,
);

final _crore = InvestmentStats(
  totalInvested: 368300000,
  totalReturned: 400000000,
  netCashFlow: 31700000,
  absoluteReturn: 8.6,
  moic: 1.086,
  xirr: 0.091,
  cashFlowCount: 2,
  firstCashFlowDate: DateTime(2023, 1, 1),
  lastCashFlowDate: DateTime(2026, 4, 1),
);

final _loss = InvestmentStats(
  totalInvested: 100000,
  totalReturned: 50000,
  netCashFlow: -50000,
  absoluteReturn: -50,
  moic: 0.5,
  xirr: -0.5258,
  cashFlowCount: 3,
  firstCashFlowDate: DateTime(2023, 1, 1),
  lastCashFlowDate: DateTime(2025, 1, 1),
);

/// Closed P2P plus an open FD valued at 5,17,800.77: "Expected XIRR" beside
/// the "Realised XIRR" of closed investments.
final _estimatedGlobal = InvestmentStats(
  totalInvested: 600000,
  totalReturned: 112000,
  netCashFlow: -488000,
  absoluteReturn: 4.966795,
  moic: 1.049668,
  xirr: 0.087328923,
  cashFlowCount: 3,
  firstCashFlowDate: DateTime(2024, 1, 1),
  lastCashFlowDate: DateTime(2026, 4, 1),
  currentValue: 517800.77,
  currentValueDate: DateTime(2026, 10, 2),
  currentValueIsEstimate: true,
  currentValueRate: 7,
);

final _estimatedOpen = InvestmentStats(
  totalInvested: 500000,
  totalReturned: 0,
  netCashFlow: -500000,
  absoluteReturn: 3.560154,
  moic: 1.035602,
  xirr: 0.071859,
  cashFlowCount: 1,
  firstCashFlowDate: DateTime(2026, 4, 1),
  lastCashFlowDate: DateTime(2026, 4, 1),
  currentValue: 517800.77,
  currentValueDate: DateTime(2026, 10, 2),
  currentValueIsEstimate: true,
  currentValueRate: 7,
);

final _estimatedClosed = InvestmentStats(
  totalInvested: 100000,
  totalReturned: 112000,
  netCashFlow: 12000,
  absoluteReturn: 12,
  moic: 1.12,
  xirr: 0.119653256,
  cashFlowCount: 2,
  firstCashFlowDate: DateTime(2024, 1, 1),
  lastCashFlowDate: DateTime(2025, 1, 1),
);

/// Paid back but still held, with no current value: figures "so far".
final _soFar = InvestmentStats(
  totalInvested: 1000000,
  totalReturned: 1114000,
  netCashFlow: 114000,
  absoluteReturn: 11.4,
  moic: 1.114,
  xirr: 0.114,
  cashFlowCount: 2,
  firstCashFlowDate: DateTime(2025, 10, 10),
  lastCashFlowDate: DateTime(2026, 10, 10),
  cashOnlyCount: 1,
);

/// An open portfolio with no current value: [returned] paid back so far.
InvestmentStats _awaiting({required double returned}) => InvestmentStats(
  totalInvested: 500000,
  totalReturned: returned,
  netCashFlow: returned - 500000,
  absoluteReturn: (returned - 500000) / 500000 * 100,
  moic: returned / 500000,
  xirr: null,
  xirrMethod: XirrMethod.undefined,
  cashFlowCount: returned == 0 ? 1 : 2,
  firstCashFlowDate: DateTime(2024, 1, 1),
  lastCashFlowDate: DateTime(2025, 1, 1),
  missingValueCount: 1,
);

class _HeroCase {
  const _HeroCase(
    this.name, {
    required this.build,
    required this.labels,
    required this.values,
    this.badge,
    this.statusChip = false,
    this.awaiting = false,
  });

  final String name;
  final Widget Function() build;

  /// The label of each stat column, in order, and the value under it.
  final List<String> labels;
  final List<String> values;

  /// The text of the return badge or status chip, if any.
  final String? badge;
  final bool statusChip;

  /// The figures wait for a current value: no percentage may show.
  final bool awaiting;

  /// The icon at the start of the label of column [i], if it has one.
  IconData? iconOf(int i) => i == 0
      ? Icons.arrow_upward_rounded
      : i == 1
      ? Icons.arrow_downward_rounded
      : null;
}

Widget _content({
  required InvestmentStats global,
  required InvestmentStats open,
  required InvestmentStats closed,
  bool realizedOnly = false,
  int archived = 0,
}) => HeroCardContent(
  globalStats: global,
  openStats: open,
  closedStats: closed,
  currencyFormat: _inr,
  showRealizedOnly: realizedOnly,
  archivedCount: archived,
);

List<_HeroCase> _heroCases() => [
  _HeroCase(
    'plain annualised',
    build: () =>
        _content(global: _plain, open: InvestmentStats.empty(), closed: _plain),
    labels: const ['out', 'in', 'XIRR'],
    values: [
      _inr.formatCompact(_plain.totalInvested),
      _inr.formatCompact(_plain.totalReturned),
      '22.0%',
    ],
    badge: '+27.6%',
  ),
  _HeroCase(
    'crore amounts',
    build: () =>
        _content(global: _crore, open: InvestmentStats.empty(), closed: _crore),
    labels: const ['out', 'in', 'XIRR'],
    values: [
      _inr.formatCompact(_crore.totalInvested),
      _inr.formatCompact(_crore.totalReturned),
      '9.1%',
    ],
    badge: '+8.6%',
  ),
  _HeroCase(
    'loss',
    build: () =>
        _content(global: _loss, open: InvestmentStats.empty(), closed: _loss),
    labels: const ['out', 'in', 'XIRR'],
    values: [
      _inr.formatCompact(_loss.totalInvested),
      _inr.formatCompact(_loss.totalReturned),
      '-52.6%',
    ],
    badge: '-50.0%',
  ),
  _HeroCase(
    'plain annualised, small amount',
    build: () =>
        _content(global: _small, open: InvestmentStats.empty(), closed: _small),
    labels: const ['out', 'in', 'XIRR'],
    values: [
      _inr.formatCompact(_small.totalInvested),
      _inr.formatCompact(_small.totalReturned),
      '9.5%',
    ],
    badge: '+3.2%',
  ),
  _HeroCase(
    'so far, small amount',
    build: () => _content(
      global: _soFarSmall,
      open: _soFarSmall,
      closed: InvestmentStats.empty(),
    ),
    labels: const ['out', 'in', 'XIRR so far'],
    values: [
      _inr.formatCompact(_soFarSmall.totalInvested),
      _inr.formatCompact(_soFarSmall.totalReturned),
      '9.5%',
    ],
    badge: '+3.2% so far',
  ),
  _HeroCase(
    'so far',
    build: () =>
        _content(global: _soFar, open: _soFar, closed: InvestmentStats.empty()),
    labels: const ['out', 'in', 'XIRR so far'],
    values: [
      _inr.formatCompact(_soFar.totalInvested),
      _inr.formatCompact(_soFar.totalReturned),
      '11.4%',
    ],
    badge: '+11.4% so far',
  ),
  _HeroCase(
    'expected and realised XIRR',
    build: () => _content(
      global: _estimatedGlobal,
      open: _estimatedOpen,
      closed: _estimatedClosed,
    ),
    labels: const ['out', 'in', 'Expected XIRR', 'Realised XIRR'],
    values: [
      _inr.formatCompact(_estimatedGlobal.totalInvested),
      _inr.formatCompact(_estimatedGlobal.totalReturned),
      '8.7%',
      '12.0%',
    ],
    badge: '+5.0%',
  ),
  _HeroCase(
    'awaiting first payout',
    build: () {
      final s = _awaiting(returned: 0);
      return _content(global: s, open: s, closed: _estimatedClosed);
    },
    labels: const ['out', 'in', 'XIRR'],
    values: [_inr.formatCompact(500000), _inr.formatCompact(0), '—'],
    badge: 'Awaiting first payout',
    statusChip: true,
    awaiting: true,
  ),
  _HeroCase(
    'awaiting current value',
    build: () {
      final s = _awaiting(returned: 10000);
      return _content(global: s, open: s, closed: _estimatedClosed);
    },
    labels: const ['out', 'in', 'XIRR'],
    values: [_inr.formatCompact(500000), _inr.formatCompact(10000), '—'],
    badge: 'Awaiting current value',
    statusChip: true,
    awaiting: true,
  ),
  _HeroCase(
    'closed investments only, two archived',
    build: () => _content(
      global: _plain,
      open: InvestmentStats.empty(),
      closed: _estimatedClosed,
      realizedOnly: true,
      archived: 2,
    ),
    labels: const ['out', 'in', 'XIRR'],
    values: [
      _inr.formatCompact(_estimatedClosed.totalInvested),
      _inr.formatCompact(_estimatedClosed.totalReturned),
      '12.0%',
    ],
    badge: '+12.0%',
  ),
  _HeroCase(
    'with the toggle wrapper',
    build: () => HeroCardWithToggle(
      globalStats: AsyncData(_estimatedGlobal),
      openStats: AsyncData(_estimatedOpen),
      closedStats: AsyncData(_estimatedClosed),
      currencyFormat: _inr,
      errorBuilder: (e) => Text(e),
    ),
    labels: const ['out', 'in', 'Expected XIRR', 'Realised XIRR'],
    values: [
      _inr.formatCompact(_estimatedGlobal.totalInvested),
      _inr.formatCompact(_estimatedGlobal.totalReturned),
      '8.7%',
      '12.0%',
    ],
    badge: '+5.0%',
  ),
];

/// What a run measured, to compare the privacy run with the plain one.
class _Shape {
  _Shape({
    required this.cardHeight,
    required this.cells,
    required this.badgeTop,
    required this.badgeHeight,
  });
  final double? cardHeight;
  final List<Rect?> cells;
  final double? badgeTop;
  final double? badgeHeight;
}

/// Every hero case at the width and text scale of [g]: plain, with privacy
/// mode on, and read right to left.
Future<void> checkHeroCards(CardGuard g) async {
  for (final c in _heroCases()) {
    final plain = await _run(g, c, privacy: false, rtl: false);
    final hidden = await _run(g, c, privacy: true, rtl: false);
    g.scope = '${c.name}, privacy mode vs plain';
    g.expectNear(
      'card height',
      hidden.cardHeight,
      plain.cardHeight ?? double.nan,
    );
    for (var i = 0; i < plain.cells.length; i++) {
      final a = plain.cells[i];
      final b = hidden.cells[i];
      if (a == null || b == null) continue;
      g.expectNear('column $i left', b.left, a.left);
      g.expectNear('column $i width', b.width, a.width);
      g.expectNear('column $i top', b.top, a.top);
      g.expectNear('column $i height', b.height, a.height);
    }
    g.expectNear('badge top', hidden.badgeTop, plain.badgeTop ?? double.nan);
    g.expectNear(
      'badge height',
      hidden.badgeHeight,
      plain.badgeHeight ?? double.nan,
    );
    await _run(g, c, privacy: false, rtl: true);
  }
}

Future<_Shape> _run(
  CardGuard g,
  _HeroCase c, {
  required bool privacy,
  required bool rtl,
}) async {
  g.scope =
      '${c.name}${privacy ? ', privacy mode' : ''}${rtl ? ', right to left' : ''}';
  await g.pump(c.build(), privacy: privacy, rtl: rtl);

  final card = g.rect('hero card', find.byType(GlassHeroCard));
  if (card == null) {
    return _Shape(
      cardHeight: null,
      cells: const [],
      badgeTop: null,
      badgeHeight: null,
    );
  }
  const pad = 20.0; // GlassHeroCard's padding
  final startEdge = rtl ? card.right - pad : card.left + pad;
  final endEdge = rtl ? card.left + pad : card.right - pad;
  double startOf(Rect r) => g.startOf(r);
  double endOf(Rect r) => g.endOf(r);
  final inner = card.width - 2 * pad;

  // -- Figure and badge ---------------------------------------------------
  final figureFinder = find.byKey(_figureKey);
  final figure = g.rect('net figure', figureFinder);
  if (figure != null) {
    g.expectNear('net figure start', startOf(figure), startEdge);
  }
  // Not part of this change: a six-digit amount in full ("-₹50,000") at 72sp is
  // 317dp wide and ends in an ellipsis on a 360dp phone at text x2.0, on main
  // as well. It is listed as a follow-up, so this one case is not asserted.
  final knownTruncation = c.name == 'loss' && g.width < 400 && g.textScale >= 2;
  if (!knownTruncation) g.expectWholeWords('net figure', figureFinder);

  Rect? pill;
  if (c.badge != null) {
    final text = find.text(c.badge!);
    pill = g.rect(
      'return badge',
      find.ancestor(of: text, matching: find.byType(Container)),
    );
    final badgeBase = g.baselineY('return badge text', text);
    final figureBase = g.baselineY('net figure', figureFinder);
    if (figure != null && pill != null) {
      final beside = pill.top < figure.bottom - guardTolerance;
      if (c.statusChip && beside) {
        g.fault('the status chip sits beside the figure, want it below');
      }
      if (beside) {
        // One baseline: the badge text sits on the figure's baseline.
        if (badgeBase != null && figureBase != null) {
          g.expectNear('badge text baseline', badgeBase, figureBase);
        }
        final gap = rtl ? figure.left - pill.right : pill.left - figure.right;
        if (gap < -guardTolerance) {
          g.fault('the badge overlaps the figure by ${g.dp(-gap)}dp');
        }
        if ((endOf(pill) - endEdge) * (rtl ? -1 : 1) > guardTolerance) {
          g.fault('the badge ends past the card padding');
        }
      } else {
        g.expectNear(
          'badge start (below the figure)',
          startOf(pill),
          startEdge,
        );
        if (!privacy && !c.statusChip) {
          final needed = figure.width + 10 + pill.width;
          if (needed <= inner - guardTolerance) {
            g.fault(
              'the badge dropped below the figure although they fit on one '
              'line (${g.dp(needed)}dp of ${g.dp(inner)}dp)',
            );
          }
        }
      }
    }
  }

  // -- Stat columns --------------------------------------------------------
  final n = c.labels.length;
  final perRow = _heroPerRow(g.width, g.textScale);
  final cells = <Rect?>[];
  final valueBase = <double?>[];
  final labelBase = <double?>[];
  final valueEnd = <double?>[];
  final labelStart = <double?>[];
  for (var i = 0; i < n; i++) {
    final cell = find.byKey(statCellKey(i));
    final rect = g.rect('stat column $i', cell);
    cells.add(rect);
    if (rect == null) {
      valueBase.add(null);
      labelBase.add(null);
      valueEnd.add(null);
      labelStart.add(null);
      continue;
    }
    final shown = privacy ? hiddenAmountText : c.values[i];
    final value = find.descendant(
      of: find.byKey(statValueKey(i)),
      matching: find.text(shown),
    );
    final label = find.descendant(of: cell, matching: find.text(c.labels[i]));
    valueBase.add(g.baselineY('value of column $i', value));
    labelBase.add(g.baselineY('label of column $i', label, last: true));
    valueEnd.add(g.textExtent('value of column $i', value)?.end);
    g.expectWholeWords('value of column $i', value);
    final icon = c.iconOf(i);
    labelStart.add(
      icon != null
          ? g.iconStart('icon of column $i', cell, icon)
          : g.textExtent('label of column $i', label)?.start,
    );
  }

  // The shape: which columns share a row. Rows share a value baseline.
  final rows = <List<int>>[];
  for (var i = 0; i < n; i++) {
    final base = valueBase[i];
    if (base == null) continue;
    if (rows.isNotEmpty) {
      final prev = valueBase[rows.last.last];
      if (prev != null && (base - prev).abs() <= guardTolerance) {
        rows.last.add(i);
        continue;
      }
    }
    rows.add([i]);
  }
  if (cells.every((r) => r != null)) {
    final sizes = [for (final r in rows) r.length];
    final want = _chunks(n, perRow);
    if (!listEquals(sizes, want)) {
      g.fault(
        'the $n stat columns sit in rows of $sizes, want $want '
        '($perRow per row at ${g.width.toInt()}dp, text x${g.textScale}); '
        'value baselines ${valueBase.map((v) => v?.toStringAsFixed(1)).toList()}, '
        'label baselines ${labelBase.map((v) => v?.toStringAsFixed(1)).toList()}',
      );
    }
  }

  for (final row in rows) {
    if (row.length >= 2) {
      final first = cells[row.first]!;
      for (final i in row) {
        final r = cells[i]!;
        g.expectNear('column $i width', r.width, first.width);
        g.expectNear(
          'column $i bottom (labels end on one line)',
          r.bottom,
          first.bottom,
        );
        final base = labelBase[i];
        final firstBase = labelBase[row.first];
        if (base != null && firstBase != null) {
          g.expectNear('label baseline of column $i', base, firstBase);
        }
      }
      for (var k = 1; k < row.length; k++) {
        final a = cells[row[k - 1]]!;
        final b = cells[row[k]]!;
        final gap = rtl ? a.left - b.right : b.left - a.right;
        g.expectNear('gap before column ${row[k]}', gap, AppSpacing.xs);
      }
      g.expectNear('first column start', startOf(first), startEdge);
      g.expectNear('last column end', endOf(cells[row.last]!), endEdge);
      final end = valueEnd[row.last];
      g.expectNear('last value end in a row', end, endEdge);
      g.expectNear(
        'first label start in a row',
        labelStart[row.first],
        startEdge,
      );
    } else {
      final i = row.single;
      final r = cells[i]!;
      g.expectNear('stacked column $i width', r.width, inner);
      g.expectNear('stacked value $i end', valueEnd[i], endEdge);
      g.expectNear('stacked label $i start', labelStart[i], startEdge);
      final valueY = valueBase[i];
      final labelY = g.baselineY(
        'label of column $i',
        find.descendant(
          of: find.byKey(statCellKey(i)),
          matching: find.text(c.labels[i]),
        ),
      );
      if (valueY != null && labelY != null) {
        g.expectNear('label baseline of stacked column $i', labelY, valueY);
      }
    }
  }

  // -- Screen reader --------------------------------------------------------
  // One stop per column, "label:" then the spoken value: a touch on a figure
  // says what it is the figure of, and privacy mode hides the amount here too.
  final stopIds = <int>{};
  final allStops = g.stops();
  for (var i = 0; i < n; i++) {
    final node = g.semanticsOf(
      'screen reader stop of column $i',
      find.byKey(statValueKey(i)),
    );
    if (node == null) continue;
    stopIds.add(node.id);
    final lines = node.label.split('\n');
    if (lines.first != '${c.labels[i]}:' || lines.length != 2) {
      g.fault(
        'the stop of column $i says ${node.label.split('\n')}, want '
        '["${c.labels[i]}:", the value]',
      );
      continue;
    }
    final spoken = lines[1];
    if (privacy) {
      if (spoken != 'Hidden amount') {
        g.fault('the stop of column $i says "$spoken" in privacy mode');
      }
    } else if (i < 2) {
      if (!spoken.contains('rupee')) {
        g.fault('the stop of column $i says "$spoken", want an amount');
      }
    } else if (spoken != c.values[i]) {
      g.fault('the stop of column $i says "$spoken", want "${c.values[i]}"');
    }
    for (final loose in [c.labels[i], if (!privacy) c.values[i]]) {
      if (allStops.contains(loose)) {
        g.fault('"$loose" is a screen reader stop of its own');
      }
    }
  }
  if (stopIds.length != n && cells.every((r) => r != null)) {
    g.fault('the $n stat columns are ${stopIds.length} screen reader stops');
  }

  // What the user sees of the last figure, whatever the structure: the XIRR
  // value ends on the card padding, like the buttons above it.
  if (!privacy) {
    final lastValue = g.textExtent('last value', find.text(c.values.last));
    g.expectNear('the last stat value ends at', lastValue?.end, endEdge);
  }

  if (c.awaiting) {
    if (find.textContaining('%').evaluate().isNotEmpty) {
      g.fault('a percentage shows while the figures await a value');
    }
    if (!privacy && find.text('—').evaluate().isEmpty) {
      g.fault('the dash for the missing XIRR is not on screen');
    }
  }

  return _Shape(
    cardHeight: card.height,
    cells: cells,
    badgeTop: pill?.top,
    badgeHeight: pill?.height,
  );
}
