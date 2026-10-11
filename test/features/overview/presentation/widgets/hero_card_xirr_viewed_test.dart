// A41 (#784): xirr_viewed is the "saw their return" step of the activation
// funnel. It is logged only when the hero shows a real XIRR (never for the
// dash, money rule 4), once per process, and after the frame.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/hero_card.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../../../helpers/analytics_privacy.dart';
import '../../../../helpers/build_aware_analytics.dart';

class _Privacy extends PrivacyModeNotifier {
  @override
  bool build() => false;

  void set(bool hidden) => state = hidden;
}

final _inr = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

/// A closed investment held for a year: a real, exact XIRR of 11.97%.
final _closed = InvestmentStats(
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

/// An open FD valued by estimate: the XIRR is an "Expected XIRR".
final _openEstimated = InvestmentStats(
  totalInvested: 500000,
  totalReturned: 0,
  netCashFlow: -500000,
  absoluteReturn: 3.560154,
  moic: 1.035602,
  xirr: 0.071859,
  cashFlowCount: 1,
  firstCashFlowDate: DateTime(2025, 4, 1),
  lastCashFlowDate: DateTime(2025, 4, 1),
  currentValue: 517800.77,
  currentValueDate: DateTime(2026, 10, 2),
  currentValueIsEstimate: true,
  currentValueRate: 7,
);

/// Open, nothing received, no current value: the hero shows a dash.
final _awaitingFirstPayout = InvestmentStats(
  totalInvested: 100000,
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

void main() {
  late BuildAwareAnalytics analytics;
  late ProviderContainer container;

  setUp(() {
    analytics = BuildAwareAnalytics();
    container = ProviderContainer(
      overrides: [
        analyticsServiceProvider.overrideWithValue(analytics),
        privacyModeProvider.overrideWith(_Privacy.new),
        currencyCodeProvider.overrideWith((ref) => 'INR'),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> pumpHero(
    WidgetTester tester, {
    required InvestmentStats global,
    required InvestmentStats open,
    required InvestmentStats closed,
    required bool realizedOnly,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: HeroCardContent(
                globalStats: global,
                openStats: open,
                closedStats: closed,
                currencyFormat: _inr,
                showRealizedOnly: realizedOnly,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Iterable<({String name, Map<String, Object>? parameters})> xirrEvents() =>
      analytics.loggedEvents.where((e) => e.name == 'xirr_viewed');

  testWidgets('a real XIRR is logged once, however often the hero rebuilds', (
    tester,
  ) async {
    for (var i = 0; i < 3; i++) {
      await pumpHero(
        tester,
        global: _closed,
        open: InvestmentStats.empty(),
        closed: _closed,
        realizedOnly: true,
      );
    }

    expect(xirrEvents(), hasLength(1));
    expect(xirrEvents().single.parameters, {
      'surface': 'overview',
      'is_estimate': 0,
    });
    expectPrivacySafe(
      xirrEvents().single,
      allowedStrings: {
        'surface': {'overview'},
      },
    );
  });

  testWidgets('an Expected XIRR is logged as an estimate', (tester) async {
    await pumpHero(
      tester,
      global: _openEstimated,
      open: _openEstimated,
      closed: InvestmentStats.empty(),
      realizedOnly: false,
    );

    expect(find.text('Expected XIRR'), findsOneWidget);
    expect(xirrEvents().single.parameters, {
      'surface': 'overview',
      'is_estimate': 1,
    });
  });

  testWidgets('the dash is not a viewed XIRR: nothing is logged', (
    tester,
  ) async {
    await pumpHero(
      tester,
      global: _awaitingFirstPayout,
      open: _awaitingFirstPayout,
      closed: InvestmentStats.empty(),
      realizedOnly: false,
    );

    expect(find.text('Awaiting first payout'), findsOneWidget);
    expect(xirrEvents(), isEmpty);
  });

  testWidgets('a later XIRR on the same surface is not logged again', (
    tester,
  ) async {
    await pumpHero(
      tester,
      global: _awaitingFirstPayout,
      open: _awaitingFirstPayout,
      closed: InvestmentStats.empty(),
      realizedOnly: false,
    );
    expect(xirrEvents(), isEmpty);

    // The user adds a current value: now a real XIRR is on screen.
    await pumpHero(
      tester,
      global: _openEstimated,
      open: _openEstimated,
      closed: InvestmentStats.empty(),
      realizedOnly: false,
    );
    expect(xirrEvents(), hasLength(1));

    // Toggling to the realised view shows another XIRR on the same surface.
    await pumpHero(
      tester,
      global: _closed,
      open: InvestmentStats.empty(),
      closed: _closed,
      realizedOnly: true,
    );
    expect(xirrEvents(), hasLength(1));
  });

  testWidgets('an XIRR hidden by privacy mode is not viewed until it is '
      'shown', (tester) async {
    (container.read(privacyModeProvider.notifier) as _Privacy).set(true);
    await pumpHero(
      tester,
      global: _closed,
      open: InvestmentStats.empty(),
      closed: _closed,
      realizedOnly: true,
    );
    expect(xirrEvents(), isEmpty);

    (container.read(privacyModeProvider.notifier) as _Privacy).set(false);
    await tester.pump();

    expect(xirrEvents(), hasLength(1));
  });

  testWidgets('it is logged after the frame, never while building', (
    tester,
  ) async {
    await pumpHero(
      tester,
      global: _closed,
      open: InvestmentStats.empty(),
      closed: _closed,
      realizedOnly: true,
    );

    expect(analytics.loggedWhileBuilding, [false]);
  });
}
