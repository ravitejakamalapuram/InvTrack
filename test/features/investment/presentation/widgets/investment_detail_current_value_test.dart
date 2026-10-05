// A10 (#754): the detail screen shows an open investment's current value,
// says whether it is estimated, labels the XIRR "Expected" until the user
// confirms the value, and offers Add/Update. Privacy mode hides the amount,
// including from screen readers (money rule 8).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_detail_stats_section.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class _Privacy extends PrivacyModeNotifier {
  _Privacy(this.value);
  final bool value;
  @override
  bool build() => value;
}

final _inr = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

InvestmentEntity _fd({InvestmentStatus status = InvestmentStatus.open}) =>
    InvestmentEntity(
      id: 'fd-1',
      name: 'Cumulative FD',
      type: InvestmentType.fixedDeposit,
      status: status,
      createdAt: DateTime(2025, 10, 2),
      updatedAt: DateTime(2025, 10, 2),
      expectedRate: 7,
      compoundingFrequency: CompoundingFrequency.quarterly,
      interestPayoutMode: InterestPayoutMode.cumulative,
      currency: 'INR',
    );

/// CALC-01 S1 with its accrued value as the terminal inflow.
InvestmentStats _s1({bool estimate = true, DateTime? date}) => InvestmentStats(
  totalInvested: 100000,
  totalReturned: 0,
  netCashFlow: -100000,
  absoluteReturn: 7.185903,
  moic: 1.07185903,
  xirr: 0.07185903,
  cashFlowCount: 1,
  firstCashFlowDate: DateTime(2025, 10, 2),
  lastCashFlowDate: DateTime(2025, 10, 2),
  currentValue: 107185.90,
  currentValueDate: date ?? DateTime(2026, 10, 2),
  currentValueIsEstimate: estimate,
  currentValueRate: estimate ? 7 : null,
);

final _noValue = InvestmentStats(
  totalInvested: 100000,
  totalReturned: 0,
  netCashFlow: -100000,
  absoluteReturn: -100,
  moic: 0,
  xirr: 0,
  xirrMethod: XirrMethod.undefined,
  cashFlowCount: 1,
  firstCashFlowDate: DateTime(2025, 10, 2),
  lastCashFlowDate: DateTime(2025, 10, 2),
  missingValueCount: 1,
);

Future<void> _pump(
  WidgetTester tester, {
  required InvestmentStats stats,
  InvestmentEntity? investment,
  bool privacy = false,
  VoidCallback? onUpdate,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [privacyModeProvider.overrideWith(() => _Privacy(privacy))],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: InvestmentDetailStatsSection(
              stats: stats,
              investment: investment ?? _fd(),
              isDark: false,
              currencyFormat: _inr,
              isPrivacyMode: privacy,
              onUpdateCurrentValue: onUpdate,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('estimated value: amount, basis, Expected XIRR and MOIC', (
    tester,
  ) async {
    var tapped = 0;
    await _pump(tester, stats: _s1(), onUpdate: () => tapped++);

    expect(find.text('Current value'), findsOneWidget);
    expect(find.text('₹1,07,186'), findsOneWidget);
    expect(find.text('Estimated at 7% p.a.'), findsOneWidget);
    expect(find.text('Expected XIRR'), findsOneWidget);
    expect(find.text('Based on 7% p.a.'), findsOneWidget);
    expect(find.text('1.07x'), findsOneWidget);
    // Return badge and XIRR are both 7.2%.
    expect(find.text('+7.2%'), findsNWidgets(2));
    expect(find.text('Awaiting first payout'), findsNothing);
    expect(find.text('Net cash flow so far'), findsOneWidget);

    expect(
      find.bySemanticsLabel(
        RegExp('Current value.*1,07,186.*Estimated at 7% p.a.'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Update'));
    expect(tapped, 1);
  });

  testWidgets('user-confirmed value shows its date and plain XIRR', (
    tester,
  ) async {
    await _pump(
      tester,
      stats: _s1(estimate: false, date: DateTime(2026, 9, 30)),
      onUpdate: () {},
    );

    expect(find.text('Updated Sep 30, 2026'), findsOneWidget);
    expect(find.text('XIRR'), findsOneWidget);
    expect(find.text('Expected XIRR'), findsNothing);
  });

  testWidgets('no value yet asks for one and keeps the dashes', (tester) async {
    var tapped = 0;
    await _pump(tester, stats: _noValue, onUpdate: () => tapped++);

    expect(find.text('No current value yet'), findsOneWidget);
    expect(find.text('Awaiting first payout'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(2));
    await tester.tap(find.text('Add current value'));
    expect(tapped, 1);
  });

  testWidgets('privacy mode hides the value from sight and screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, stats: _s1(), privacy: true, onUpdate: () {});

    expect(find.text('Current value'), findsOneWidget);
    expect(find.textContaining('1,07,186'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('1,07,186')), findsNothing);
    expect(find.bySemanticsLabel(RegExp('107186|107,186')), findsNothing);
    handle.dispose();
  });

  testWidgets('closed investments have no current value card', (tester) async {
    await _pump(
      tester,
      stats: _s1(),
      investment: _fd(status: InvestmentStatus.closed),
      onUpdate: () {},
    );

    expect(find.text('Current value'), findsNothing);
    expect(find.text('Update'), findsNothing);
  });
}
