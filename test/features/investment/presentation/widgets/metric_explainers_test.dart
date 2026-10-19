// A44: XIRR, MOIC and Net Position carry a tap-to-read explanation with an
// example, wherever they appear.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_detail_stats_section.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/overview_quick_stats.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:inv_tracker/l10n/generated/app_localizations_en.dart';

import '../../../../mocks/mock_analytics_service.dart';

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

final _inr = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

/// Rs1,00,000 in, Rs1,25,000 back over two years.
final _closed = InvestmentStats(
  totalInvested: 100000,
  totalReturned: 125000,
  netCashFlow: 25000,
  absoluteReturn: 25,
  moic: 1.25,
  xirr: 0.118,
  cashFlowCount: 2,
  firstCashFlowDate: DateTime(2024, 1, 1),
  lastCashFlowDate: DateTime(2026, 1, 1),
);

InvestmentEntity _investment(InvestmentStatus status) => InvestmentEntity(
  id: 'fd-1',
  name: 'FD',
  type: InvestmentType.fixedDeposit,
  status: status,
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
  startDate: DateTime(2024, 1, 1),
  currency: 'INR',
);

Finder _tip(String start) => find.byWidgetPredicate(
  (w) => w is Tooltip && (w.message ?? '').startsWith(start),
);

const _xirrTip = 'Your yearly return';
const _moicTip = 'Money multiple';
const _netTip = 'Money received minus';

Future<void> _pump(WidgetTester tester, Widget body) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currencyCodeProvider.overrideWith((ref) => 'INR'),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        privacyModeProvider.overrideWith(_PrivacyOff.new),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: body)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _detail(InvestmentStatus status) => InvestmentDetailStatsSection(
  stats: _closed,
  investment: _investment(status),
  isDark: false,
  currencyFormat: _inr,
  isPrivacyMode: false,
);

void main() {
  testWidgets(
    'detail of a closed investment explains XIRR, MOIC, Net Position',
    (tester) async {
      await _pump(tester, _detail(InvestmentStatus.closed));
      expect(_tip(_xirrTip), findsOneWidget);
      expect(_tip(_moicTip), findsOneWidget);
      expect(_tip(_netTip), findsOneWidget);
    },
  );

  testWidgets('detail of an open investment explains net cash flow so far', (
    tester,
  ) async {
    await _pump(tester, _detail(InvestmentStatus.open));
    expect(_tip(_netTip), findsOneWidget);
  });

  testWidgets('Overview quick stats explain MOIC', (tester) async {
    await _pump(
      tester,
      OverviewQuickStats(stats: _closed, openStats: InvestmentStats.empty()),
    );
    expect(_tip(_moicTip), findsOneWidget);
  });

  test('the FAQ does not say the add form asks for an amount', () {
    final text = AppLocalizationsEn().howToAddFirstInvestmentAnswer;
    expect(text.toLowerCase(), isNot(contains('amount')));
  });
}
