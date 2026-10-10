// #942: the detail page showed the investment name twice at the top, once in
// the pinned app bar and again in the expanded header right below it. The name
// now shows once when the page opens; the app bar carries it only after the
// expanded header has scrolled away.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/income_projection/presentation/providers/expected_cash_flow_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/document_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/investment_detail_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

class _SameCurrencyService implements CurrencyConversionService {
  @override
  Future<double> convert({
    required double amount,
    required String from,
    required String to,
    DateTime? date,
  }) async => amount;

  @override
  Future<Map<String, double>> batchConvertHistorical({
    required Map<String, ConversionRequest> requests,
    required String to,
  }) async => {for (final e in requests.entries) e.key: e.value.amount};

  @override
  Future<double?> getLastKnownRate({
    required String from,
    required String to,
  }) async => 1.0;

  @override
  Future<double> getRate({
    required String from,
    required String to,
    DateTime? date,
  }) async => 1.0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _name = 'Bhive RBF - EX Myntra';

final _investment = InvestmentEntity(
  id: 'rbf-1',
  name: _name,
  type: InvestmentType.other,
  status: InvestmentStatus.open,
  notes: 'BHIVE COWORKING 27 LLP',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  currency: 'INR',
);

final _flows = [
  CashFlowEntity(
    id: 'cf-1',
    investmentId: 'rbf-1',
    type: CashFlowType.invest,
    amount: 1000000,
    currency: 'INR',
    date: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
  ),
  for (var i = 0; i < 12; i++)
    CashFlowEntity(
      id: 'cf-income-$i',
      investmentId: 'rbf-1',
      type: CashFlowType.income,
      amount: 95000,
      currency: 'INR',
      date: DateTime(2026, 2 + i ~/ 2, 1 + i),
      createdAt: DateTime(2026, 2, 1),
    ),
];

Future<void> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        privacyModeProvider.overrideWith(_PrivacyOff.new),
        currencyCodeProvider.overrideWithValue('INR'),
        currencyConversionServiceProvider.overrideWithValue(
          _SameCurrencyService(),
        ),
        cashFlowsByInvestmentProvider(
          'rbf-1',
        ).overrideWith((ref) => Stream.value(_flows)),
        expectedCashFlowsByInvestmentProvider(
          'rbf-1',
        ).overrideWith((ref) => Stream.value([])),
        documentsByInvestmentProvider(
          'rbf-1',
        ).overrideWith((ref) => Stream.value([])),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InvestmentDetailScreen(investment: _investment),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Semantics headers whose label is the investment name.
SemanticsFinder _nameHeaders() => find.semantics.byPredicate(
  (node) => node.label.contains(_name) && node.flagsCollection.isHeader,
  describeMatch: (_) => 'header semantics node labelled "$_name"',
);

/// The name in the pinned app bar's toolbar. The expanded header lives in the
/// app bar's flexible space, outside the toolbar.
Finder _nameInToolbar() => find.descendant(
  of: find.byType(NavigationToolbar),
  matching: find.text(_name),
);

void main() {
  testWidgets('shows the investment name once when the page opens', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(InvestmentDetailScreen)),
    );

    expect(find.text(_name), findsOneWidget);
    expect(_nameInToolbar(), findsNothing);
    // The name stays reachable as the page heading, exactly once.
    expect(_nameHeaders(), findsOneWidget);
    // The rest of the expanded header and the app bar buttons are unchanged.
    expect(find.text('BHIVE COWORKING 27 LLP'), findsOneWidget);
    expect(find.byTooltip(l10n.tooltipBack), findsOneWidget);
    expect(find.byTooltip(l10n.tooltipMoreOptions), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the app bar carries the name once the header scrolls away', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(InvestmentDetailScreen)),
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(_nameInToolbar(), findsOneWidget);
    expect(_nameHeaders(), findsOneWidget);
    expect(find.byTooltip(l10n.tooltipBack), findsOneWidget);
    expect(find.byTooltip(l10n.tooltipMoreOptions), findsOneWidget);

    // Scrolling back to the top returns to the single expanded heading.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 1200));
    await tester.pumpAndSettle();
    expect(find.text(_name), findsOneWidget);
    expect(_nameInToolbar(), findsNothing);
    expect(_nameHeaders(), findsOneWidget);
    semantics.dispose();
  });
}
