import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/presentation/utils/return_display.dart';
import 'package:inv_tracker/l10n/generated/app_localizations_en.dart';

InvestmentStats _stats({
  required double invested,
  required double returned,
  required DateTime first,
  required DateTime last,
  double xirr = 0,
  XirrMethod xirrMethod = XirrMethod.exact,
  int count = 2,
  int cashOnly = 0,
  int missing = 0,
  double? currentValue,
  bool estimate = false,
}) {
  return InvestmentStats(
    totalInvested: invested,
    totalReturned: returned,
    netCashFlow: returned - invested,
    absoluteReturn: invested > 0 ? (returned - invested) / invested * 100 : 0,
    moic: invested > 0 ? returned / invested : 0,
    xirr: xirr,
    xirrMethod: xirrMethod,
    cashFlowCount: count,
    firstCashFlowDate: first,
    lastCashFlowDate: last,
    currentValue: currentValue,
    currentValueIsEstimate: estimate,
    missingValueCount: missing,
    cashOnlyCount: cashOnly,
  );
}

void main() {
  final l10n = AppLocalizationsEn();

  group('ReturnDisplay.resolve', () {
    test(
      'open investment with only an INVEST flow awaits its first payout',
      () {
        final stats = _stats(
          invested: 100000,
          returned: 0,
          first: DateTime(2026, 1, 1),
          last: DateTime(2026, 1, 1),
          xirrMethod: XirrMethod.undefined,
          count: 1,
        );

        final display = ReturnDisplay.resolve(stats: stats, openStats: stats);

        expect(display.kind, ReturnDisplayKind.awaitingFirstPayout);
        expect(display.isAwaitingValue, isTrue);
        expect(display.statusLabel(l10n), 'Awaiting first payout');
        expect(display.primaryText(l10n), '—');
        expect(
          display.secondaryText(l10n),
          'Add a payout or current value to calculate',
        );
      },
    );

    test('open FD with payouts but principal outstanding is not a loss', () {
      // ANLY-01: Rs10L FD with three quarterly payouts of Rs17,500. The flows
      // alone give about -99% XIRR because the principal is still out.
      final stats = _stats(
        invested: 1000000,
        returned: 52500,
        first: DateTime(2026, 1, 1),
        last: DateTime(2026, 10, 1),
        xirr: -0.9932,
        count: 4,
      );

      final display = ReturnDisplay.resolve(stats: stats, openStats: stats);

      expect(display.kind, ReturnDisplayKind.awaitingCurrentValue);
      expect(display.statusLabel(l10n), 'Awaiting current value');
      expect(display.primaryText(l10n), '—');
    });

    test('open investment that has returned its capital shows its XIRR '
        'so far', () {
      // #954: the figure is the cash-only one, a minimum, so it says so. The
      // test used to expect the plain "XIRR", which the owner ruled out.
      final stats = _stats(
        invested: 100000,
        returned: 110000,
        first: DateTime(2023, 1, 1),
        last: DateTime(2024, 1, 1),
        xirr: 0.10,
        cashOnly: 1,
      );

      final display = ReturnDisplay.resolve(stats: stats, openStats: stats);

      expect(display.kind, ReturnDisplayKind.annualised);
      expect(display.isSoFar, isTrue);
      expect(display.statusLabel(l10n), isNull);
      expect(display.metricLabel(l10n), 'XIRR so far');
      expect(display.primaryText(l10n), '+10.0%');
      expect(display.badgeText(l10n), '+10.0% so far');
      expect(display.pillText(l10n), '+10.0% IRR so far');
      expect(display.moicLabel(l10n), 'MOIC so far');
      expect(display.paidBackHint(l10n), 'Fully paid back? Mark it closed');
    });

    test(
      'stats built without values that got the cost back are so far too',
      () {
        final stats = _stats(
          invested: 100000,
          returned: 110000,
          first: DateTime(2023, 1, 1),
          last: DateTime(2024, 1, 1),
          xirr: 0.10,
        );

        final display = ReturnDisplay.resolve(stats: stats, openStats: stats);

        expect(display.isSoFar, isTrue);
        expect(display.metricLabel(l10n), 'XIRR so far');
      },
    );

    test('a short so-far holding labels its absolute return', () {
      final stats = _stats(
        invested: 100000,
        returned: 100500,
        first: DateTime(2026, 9, 1),
        last: DateTime(2026, 9, 21),
        xirr: 0.09,
        cashOnly: 1,
      );

      final display = ReturnDisplay.resolve(stats: stats, openStats: stats);

      expect(display.kind, ReturnDisplayKind.shortHolding);
      expect(display.isSoFar, isTrue);
      expect(display.primaryText(l10n), '+0.5% in 20 days');
      expect(display.metricLabel(l10n), 'Return so far');
      expect(display.badgeText(l10n), '+0.5% so far');
      expect(display.pillText(l10n), '+0.5% in 20 days so far');
    });

    test('waiting for a value wins over so far', () {
      // One holding has paid back, another has not: the whole is unknown.
      final stats = _stats(
        invested: 200000,
        returned: 110000,
        first: DateTime(2023, 1, 1),
        last: DateTime(2024, 1, 1),
        xirr: -0.4,
        cashOnly: 1,
        missing: 1,
      );

      final display = ReturnDisplay.resolve(stats: stats, openStats: stats);

      expect(display.kind, ReturnDisplayKind.awaitingCurrentValue);
      expect(display.isSoFar, isFalse);
      expect(display.primaryText(l10n), '—');
      expect(display.paidBackHint(l10n), isNull);
    });

    test(
      'an estimated value with a paid-back holding is Expected XIRR so far',
      () {
        // Overview: an FD estimated at its accrued value, plus a holding that
        // paid back and has no value.
        final stats = _stats(
          invested: 200000,
          returned: 110000,
          first: DateTime(2023, 1, 1),
          last: DateTime(2026, 6, 1),
          xirr: 0.08,
          cashOnly: 1,
          currentValue: 107000,
          estimate: true,
        );

        final display = ReturnDisplay.resolve(stats: stats, openStats: stats);

        expect(display.kind, ReturnDisplayKind.annualised);
        expect(display.isSoFar, isTrue);
        expect(display.metricLabel(l10n), 'Expected XIRR so far');
      },
    );

    test('a closed investment is final: never so far', () {
      final stats = _stats(
        invested: 100000,
        returned: 110000,
        first: DateTime(2023, 1, 1),
        last: DateTime(2024, 1, 1),
        xirr: 0.10,
        cashOnly: 1,
      );

      final display = ReturnDisplay.resolve(stats: stats);

      expect(display.isSoFar, isFalse);
      expect(display.metricLabel(l10n), 'XIRR');
      expect(display.badgeText(l10n), '+10.0%');
      expect(display.pillText(l10n), '+10.0% IRR');
      expect(display.moicLabel(l10n), 'MOIC');
      expect(display.paidBackHint(l10n), isNull);
    });

    test('an open investment with a current value is not so far', () {
      final stats = _stats(
        invested: 100000,
        returned: 10000,
        first: DateTime(2023, 1, 1),
        last: DateTime(2024, 1, 1),
        xirr: 0.05,
        currentValue: 110000,
      );

      final display = ReturnDisplay.resolve(stats: stats, openStats: stats);

      expect(display.isSoFar, isFalse);
      expect(display.metricLabel(l10n), 'XIRR');
      expect(display.moicLabel(l10n), 'MOIC');
    });

    test('so-far semantics say what the figure leaves out', () {
      final stats = _stats(
        invested: 100000,
        returned: 110000,
        first: DateTime(2023, 1, 1),
        last: DateTime(2024, 1, 1),
        xirr: 0.10,
        cashOnly: 1,
      );
      final open = ReturnDisplay.resolve(stats: stats, openStats: stats);
      final closed = ReturnDisplay.resolve(stats: stats);

      expect(
        open.semanticsFigure(l10n, 'Return: positive 10.0 percent'),
        'Return: positive 10.0 percent so far. Counts money received only, '
        'not any value still held.',
      );
      expect(
        closed.semanticsFigure(l10n, 'Return: positive 10.0 percent'),
        'Return: positive 10.0 percent',
      );
    });

    test('closed investment with zero inflow keeps its real loss', () {
      final stats = _stats(
        invested: 100000,
        returned: 0,
        first: DateTime(2023, 1, 1),
        last: DateTime(2024, 1, 1),
        xirr: -1.0,
        xirrMethod: XirrMethod.approximate,
      );

      final display = ReturnDisplay.resolve(stats: stats);

      expect(display.isAwaitingValue, isFalse);
      expect(display.statusLabel(l10n), isNull);
    });

    test(
      'closed investment with a single INVEST flow is not a short holding',
      () {
        // Closed with zero inflow: first and last cash flow are the same day, so
        // there is no holding period to report "in under a day" against.
        final stats = _stats(
          invested: 100000,
          returned: 0,
          first: DateTime(2023, 1, 1),
          last: DateTime(2023, 1, 1),
          xirrMethod: XirrMethod.undefined,
          count: 1,
        );

        final display = ReturnDisplay.resolve(stats: stats);

        expect(display.kind, ReturnDisplayKind.undefined);
        expect(display.metricLabel(l10n), 'XIRR');
        expect(display.primaryText(l10n), '—');
        expect(display.secondaryText(l10n), isNull);
      },
    );

    test('closed same-day round trip with a payout keeps its real return', () {
      final stats = _stats(
        invested: 100000,
        returned: 101000,
        first: DateTime(2026, 1, 1),
        last: DateTime(2026, 1, 1),
        xirrMethod: XirrMethod.undefined,
      );

      final display = ReturnDisplay.resolve(stats: stats);

      expect(display.kind, ReturnDisplayKind.shortHolding);
      expect(display.primaryText(l10n), '+1.0% in under a day');
    });

    test('3-day holding shows absolute return as the primary figure', () {
      final stats = _stats(
        invested: 100000,
        returned: 102000,
        first: DateTime(2026, 1, 1),
        last: DateTime(2026, 1, 4),
        xirr: 10.126388779444367,
        xirrMethod: XirrMethod.approximate,
      );

      final display = ReturnDisplay.resolve(stats: stats);

      expect(display.kind, ReturnDisplayKind.shortHolding);
      expect(display.holdingDays, 3);
      expect(display.primaryText(l10n), '+2.0% in 3 days');
      expect(display.secondaryText(l10n), 'annualised >1000%');
      expect(display.metricLabel(l10n), 'Return');
    });

    test('approximate XIRR is labelled approx.', () {
      final stats = _stats(
        invested: 100000,
        returned: 50000,
        first: DateTime(2023, 1, 1),
        last: DateTime(2025, 1, 1),
        xirr: -0.5258,
        xirrMethod: XirrMethod.approximate,
      );

      final display = ReturnDisplay.resolve(stats: stats);

      expect(display.kind, ReturnDisplayKind.annualised);
      expect(display.primaryText(l10n), '-52.6% approx.');
      expect(display.metricLabel(l10n), 'XIRR');
    });

    test('XIRR above 1000% renders >1000%, not 0.0% or blank', () {
      final stats = _stats(
        invested: 100000,
        returned: 1300000,
        first: DateTime(2025, 1, 1),
        last: DateTime(2026, 1, 1),
        xirr: 12.0,
      );

      final display = ReturnDisplay.resolve(stats: stats);

      expect(display.primaryText(l10n), '>1000%');
    });

    test('undefined XIRR renders as a dash', () {
      final stats = _stats(
        invested: 100000,
        returned: 150000,
        first: DateTime(2024, 1, 1),
        last: DateTime(2025, 1, 1),
        xirrMethod: XirrMethod.undefined,
      );

      final display = ReturnDisplay.resolve(stats: stats);

      expect(display.kind, ReturnDisplayKind.undefined);
      expect(display.primaryText(l10n), '—');
    });

    test('the pill of an undefined XIRR is a bare dash, so far or not', () {
      // #954: a dash has nothing to qualify. A paid-back open investment
      // (so far) whose XIRR cannot be solved must not read "— IRR so far".
      final stats = _stats(
        invested: 100000,
        returned: 110000,
        first: DateTime(2023, 1, 1),
        last: DateTime(2024, 1, 1),
        xirrMethod: XirrMethod.undefined,
        cashOnly: 1,
      );

      final soFar = ReturnDisplay.resolve(stats: stats, openStats: stats);
      expect(soFar.kind, ReturnDisplayKind.undefined);
      expect(soFar.isSoFar, isTrue);
      expect(soFar.primaryText(l10n), '—');
      expect(soFar.pillText(l10n), '—');

      final closed = ReturnDisplay.resolve(stats: stats);
      expect(closed.kind, ReturnDisplayKind.undefined);
      expect(closed.isSoFar, isFalse);
      expect(closed.pillText(l10n), '—');
    });

    test(
      'portfolio view awaits value when its open part has not paid back',
      () {
        // Closed profits make the whole portfolio look positive, but the open
        // part still has principal outstanding, so the aggregate XIRR is
        // missing a terminal value. Payouts were received overall, so the chip
        // must not claim the user is still waiting for a first payout.
        final global = _stats(
          invested: 300000,
          returned: 320000,
          first: DateTime(2023, 1, 1),
          last: DateTime(2026, 6, 1),
          xirr: 0.02,
        );
        final open = _stats(
          invested: 100000,
          returned: 0,
          first: DateTime(2026, 1, 1),
          last: DateTime(2026, 1, 1),
          count: 1,
        );

        final display = ReturnDisplay.resolve(stats: global, openStats: open);

        expect(display.kind, ReturnDisplayKind.awaitingCurrentValue);
        expect(display.primaryText(l10n), '—');
      },
    );
  });

  group('ReturnDisplay pill wording lives in the ARB file', () {
    test('the plain pill is the localized "returnPill" string', () {
      expect(l10n.returnPill('+4.9%'), '+4.9% IRR');
      expect(l10n.returnPillSoFar('+4.9%'), '+4.9% IRR so far');
    });
  });
}
