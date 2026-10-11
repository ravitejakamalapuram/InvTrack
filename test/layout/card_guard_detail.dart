// The XIRR and MOIC tiles of the Investment detail: both tiles share a top and
// a height, and the two values share a baseline, whatever the width, text size,
// reading direction or privacy mode. No part of the section may overflow.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/core/utils/number_format_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/presentation/utils/return_display.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_detail_stats_section.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import 'card_guard_harness.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

final _inr = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

InvestmentEntity _investment({
  InvestmentStatus status = InvestmentStatus.open,
  DateTime? maturityDate,
  double? currentValue,
}) => InvestmentEntity(
  id: 'fd-1',
  name: 'Cumulative FD',
  type: InvestmentType.fixedDeposit,
  status: status,
  currentValue: currentValue,
  currentValueDate: currentValue == null ? null : DateTime(2026, 10, 1),
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  startDate: DateTime(2024, 1, 1),
  maturityDate: maturityDate,
  currency: 'INR',
);

// Demo figures only.
final _annualised = InvestmentStats(
  totalInvested: 100000,
  totalReturned: 149000,
  netCashFlow: 49000,
  absoluteReturn: 49,
  moic: 1.49,
  xirr: 0.275,
  cashFlowCount: 2,
  firstCashFlowDate: DateTime(2024, 1, 1),
  lastCashFlowDate: DateTime(2025, 11, 25),
);

final _estimated = InvestmentStats(
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

final _awaitingFirstPayout = InvestmentStats(
  totalInvested: 100000,
  principal: 100000,
  totalReturned: 0,
  netCashFlow: -100000,
  absoluteReturn: -100,
  moic: 0,
  xirr: 0,
  xirrMethod: XirrMethod.undefined,
  cashFlowCount: 1,
  firstCashFlowDate: DateTime(2026, 1, 1),
  lastCashFlowDate: DateTime(2026, 1, 1),
);

final _shortHolding = InvestmentStats(
  totalInvested: 100000,
  totalReturned: 102000,
  netCashFlow: 2000,
  absoluteReturn: 2.0,
  moic: 1.02,
  xirr: 10.126388779444367,
  xirrMethod: XirrMethod.approximate,
  cashFlowCount: 2,
  firstCashFlowDate: DateTime(2026, 1, 1),
  lastCashFlowDate: DateTime(2026, 1, 4),
);

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

class _DetailCase {
  _DetailCase(this.name, this.investment, this.stats);
  final String name;
  final InvestmentEntity investment;
  final InvestmentStats stats;

  late final ReturnDisplay display = ReturnDisplay.resolve(
    stats: stats,
    openStats: investment.isOpen ? stats : null,
  );
  late final String xirrLabel = display.metricLabel(_l10n);
  late final String xirrValue = display.primaryText(_l10n);
  late final String moicLabel = display.moicLabel(_l10n);
  late final String moicValue = display.isAwaitingValue
      ? ReturnDisplay.dash
      : formatMultiplier(stats.moic);
  late final String? xirrNote = display.secondaryText(_l10n);
  late final String? moicNote = display.isAwaitingValue
      ? null
      : stats.durationFormatted;
}

List<_DetailCase> _detailCases() => [
  _DetailCase(
    'annualised, MOIC has a duration',
    _investment(status: InvestmentStatus.closed),
    _annualised,
  ),
  _DetailCase(
    'annualised, matured long ago',
    _investment(
      status: InvestmentStatus.closed,
      maturityDate: DateTime(2025, 11, 25),
    ),
    _annualised,
  ),
  _DetailCase(
    'expected XIRR from an estimated value',
    _investment(currentValue: 517800.77),
    _estimated,
  ),
  _DetailCase(
    'awaiting the first payout',
    _investment(maturityDate: DateTime(2030, 1, 1)),
    _awaitingFirstPayout,
  ),
  _DetailCase(
    'short holding',
    _investment(status: InvestmentStatus.closed),
    _shortHolding,
  ),
  _DetailCase('so far', _investment(), _soFar),
];

Rect? _tileAround(CardGuard g, String what, Finder label) {
  final l = g.rect('$what label', label);
  if (l == null) return null;
  Rect? best;
  final cards = find.byType(GlassCard);
  for (var k = 0; k < cards.evaluate().length; k++) {
    final r = g.tester.getRect(cards.at(k)).inflate(0.5);
    if (r.contains(l.topLeft) && r.contains(l.bottomRight)) {
      if (best == null || r.width * r.height < best.width * best.height) {
        best = r;
      }
    }
  }
  if (best == null) {
    g.fault('$what: no card around its label');
    return null;
  }
  return best.deflate(0.5);
}

/// Every detail case at the width and text scale of [g]: plain, with privacy
/// mode on, and read right to left.
Future<void> checkDetailTiles(CardGuard g) async {
  for (final c in _detailCases()) {
    final plain = await _runDetail(g, c, privacy: false, rtl: false);
    final hidden = await _runDetail(g, c, privacy: true, rtl: false);
    g.scope = '${c.name}, privacy mode vs plain';
    for (var i = 0; i < 2; i++) {
      final a = plain[i];
      final b = hidden[i];
      if (a == null || b == null) continue;
      g.expectNear('tile $i left', b.left, a.left);
      g.expectNear('tile $i width', b.width, a.width);
    }
    await _runDetail(g, c, privacy: false, rtl: true);
  }
}

/// Pumps [c] and returns the XIRR and MOIC tiles.
Future<List<Rect?>> _runDetail(
  CardGuard g,
  _DetailCase c, {
  required bool privacy,
  required bool rtl,
}) async {
  g.scope =
      '${c.name}${privacy ? ', privacy mode' : ''}${rtl ? ', right to left' : ''}';
  await g.pump(
    InvestmentDetailStatsSection(
      stats: c.stats,
      investment: c.investment,
      isDark: false,
      currencyFormat: _inr,
      isPrivacyMode: privacy,
      onUpdateCurrentValue: c.investment.isOpen ? () {} : null,
    ),
    privacy: privacy,
    rtl: rtl,
  );

  final xirrLabel = find.text(c.xirrLabel);
  final moicLabel = find.text(c.moicLabel);
  final xirrTile = _tileAround(g, 'XIRR tile', xirrLabel);
  final moicTile = _tileAround(g, 'MOIC tile', moicLabel);
  if (xirrTile == null || moicTile == null) return [xirrTile, moicTile];

  // One top, one height.
  g.expectNear('MOIC tile top', moicTile.top, xirrTile.top);
  g.expectNear('MOIC tile height', moicTile.height, xirrTile.height);
  // Side by side, equal, in reading order.
  g.expectNear('MOIC tile width', moicTile.width, xirrTile.width);
  final first = rtl ? moicTile : xirrTile;
  final second = rtl ? xirrTile : moicTile;
  if (first.center.dx >= second.center.dx) {
    g.fault('the tiles are not in reading order');
  }

  // Labels share their last line, values share one baseline.
  g.expectNear(
    'MOIC label baseline',
    g.baselineY('MOIC label', moicLabel, last: true),
    g.baselineY('XIRR label', xirrLabel, last: true) ?? double.nan,
  );
  if (!privacy) {
    final xirrValue = find.descendant(
      of: find.byType(InvestmentDetailStatsSection),
      matching: find.text(c.xirrValue),
    );
    final moicValue = find.descendant(
      of: find.byType(InvestmentDetailStatsSection),
      matching: find.text(c.moicValue),
    );
    // A dash is both values when the figures await a value: tell them apart
    // by their tile.
    final xv = _inTile(g, 'XIRR value', xirrValue, xirrTile);
    final mv = _inTile(g, 'MOIC value', moicValue, moicTile);
    if (xv != null && mv != null) {
      g.expectNear('MOIC value baseline', mv.baseline, xv.baseline);
      g.expectNear(
        'XIRR value centred in its tile',
        (xv.rect.center.dx - xirrTile.center.dx).abs(),
        0,
      );
      g.expectNear(
        'MOIC value centred in its tile',
        (mv.rect.center.dx - moicTile.center.dx).abs(),
        0,
      );
      g.expectWholeWords('XIRR value', xv.finder);
      g.expectWholeWords('MOIC value', mv.finder);
      for (final (note, tile, value) in [
        (c.xirrNote, xirrTile, xv),
        (c.moicNote, moicTile, mv),
      ]) {
        if (note == null) continue;
        final n = _inTile(g, 'note $note', find.text(note), tile);
        if (n != null && n.rect.top < value.rect.bottom - 0.5) {
          g.fault('the note "$note" is not below its value');
        }
      }
    }
    if (c.display.isAwaitingValue &&
        (c.xirrValue != ReturnDisplay.dash ||
            c.moicValue != ReturnDisplay.dash)) {
      g.fault('an open investment without a value must show dashes');
    }
  }
  return [xirrTile, moicTile];
}

class _Found {
  _Found(this.finder, this.rect, this.baseline);
  final Finder finder;
  final Rect rect;
  final double baseline;
}

/// The match of [finder] that lies inside [tile].
_Found? _inTile(CardGuard g, String what, Finder finder, Rect tile) {
  final count = finder.evaluate().length;
  for (var k = 0; k < count; k++) {
    final one = finder.at(k);
    final r = g.tester.getRect(one);
    if (tile.inflate(0.5).contains(r.center)) {
      final base = g.baselineY(what, one);
      if (base == null) return null;
      return _Found(one, r, base);
    }
  }
  g.fault('$what: not inside its tile');
  return null;
}
