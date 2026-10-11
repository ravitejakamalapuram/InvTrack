// A41 (#784): xirr_viewed from the investment detail: only when the screen
// shows a real XIRR (not the dash or a short holding's absolute return), once
// per process, and after the frame.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_detail_stats_section.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../../../helpers/analytics_privacy.dart';
import '../../../../helpers/build_aware_analytics.dart';

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

final _inr = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

final _openFd = InvestmentEntity(
  id: 'fd-1',
  name: 'Cumulative FD',
  type: InvestmentType.fixedDeposit,
  status: InvestmentStatus.open,
  createdAt: DateTime(2025, 1, 1),
  updatedAt: DateTime(2025, 1, 1),
  startDate: DateTime(2025, 1, 1),
  currency: 'INR',
);

/// Open FD of Rs1,00,000 with a current value entered by the user: a real
/// XIRR after more than 90 days.
final _withUserValue = InvestmentStats(
  totalInvested: 100000,
  principal: 100000,
  totalReturned: 0,
  netCashFlow: -100000,
  absoluteReturn: 7.19,
  moic: 1.0719,
  xirr: 0.0719,
  cashFlowCount: 1,
  firstCashFlowDate: DateTime(2025, 1, 1),
  lastCashFlowDate: DateTime(2025, 1, 1),
  currentValue: 107190,
  currentValueDate: DateTime(2026, 1, 1),
);

final _withEstimate = InvestmentStats(
  totalInvested: 100000,
  principal: 100000,
  totalReturned: 0,
  netCashFlow: -100000,
  absoluteReturn: 7,
  moic: 1.07,
  xirr: 0.07,
  cashFlowCount: 1,
  firstCashFlowDate: DateTime(2025, 1, 1),
  lastCashFlowDate: DateTime(2025, 1, 1),
  currentValue: 107000,
  currentValueDate: DateTime(2026, 1, 1),
  currentValueIsEstimate: true,
  currentValueRate: 7,
);

/// What calculateStats returns for a single INVEST and no value.
final _investOnly = InvestmentStats(
  totalInvested: 100000,
  principal: 100000,
  totalReturned: 0,
  netCashFlow: -100000,
  absoluteReturn: -100,
  moic: 0,
  xirr: 0,
  xirrMethod: XirrMethod.undefined,
  cashFlowCount: 1,
  firstCashFlowDate: DateTime(2025, 1, 1),
  lastCashFlowDate: DateTime(2025, 1, 1),
);

void main() {
  late BuildAwareAnalytics analytics;
  late ProviderContainer container;

  setUp(() {
    analytics = BuildAwareAnalytics();
    container = ProviderContainer(
      overrides: [
        analyticsServiceProvider.overrideWithValue(analytics),
        privacyModeProvider.overrideWith(_PrivacyOff.new),
        currencyCodeProvider.overrideWith((ref) => 'INR'),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> pumpDetail(
    WidgetTester tester,
    InvestmentStats stats, {
    bool privacy = false,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: InvestmentDetailStatsSection(
                stats: stats,
                investment: _openFd,
                isDark: false,
                currencyFormat: _inr,
                isPrivacyMode: privacy,
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

  testWidgets('a real XIRR is logged once for the detail surface', (
    tester,
  ) async {
    for (var i = 0; i < 3; i++) {
      await pumpDetail(tester, _withUserValue);
    }

    expect(xirrEvents(), hasLength(1));
    expect(xirrEvents().single.parameters, {
      'surface': 'investment_detail',
      'is_estimate': 0,
    });
    expectPrivacySafe(
      xirrEvents().single,
      allowedStrings: {
        'surface': {'investment_detail'},
      },
    );
    expect(analytics.loggedWhileBuilding, [false]);
  });

  testWidgets('an estimated current value logs is_estimate 1', (tester) async {
    await pumpDetail(tester, _withEstimate);

    expect(xirrEvents().single.parameters, {
      'surface': 'investment_detail',
      'is_estimate': 1,
    });
  });

  testWidgets('an XIRR hidden by privacy mode is not viewed until it is '
      'shown', (tester) async {
    await pumpDetail(tester, _withUserValue, privacy: true);
    expect(xirrEvents(), isEmpty);

    await pumpDetail(tester, _withUserValue);

    expect(xirrEvents(), hasLength(1));
  });

  testWidgets('an open investment without a current value shows the dash and '
      'logs nothing', (tester) async {
    await pumpDetail(tester, _investOnly);

    expect(find.text('Awaiting first payout'), findsOneWidget);
    expect(xirrEvents(), isEmpty);
  });
}
