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

    test('open investment that has returned its capital shows its XIRR', () {
      final stats = _stats(
        invested: 100000,
        returned: 110000,
        first: DateTime(2023, 1, 1),
        last: DateTime(2024, 1, 1),
        xirr: 0.10,
      );

      final display = ReturnDisplay.resolve(stats: stats, openStats: stats);

      expect(display.kind, ReturnDisplayKind.annualised);
      expect(display.statusLabel(l10n), isNull);
      expect(display.primaryText(l10n), '+10.0%');
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
}
