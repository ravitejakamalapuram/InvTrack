// A11 (#755, PLAN-03, PLAN-04, PLAN-06, PLAN-02): the FIRE screen shows the
// real multiple, "Not reachable" instead of age 100, where the corpus and
// the monthly savings come from, and asks the user to invest more only when
// they are short.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/planning_inputs_calculator.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_calculation_result.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/domain/services/fire_calculation_service.dart';
import 'package:inv_tracker/features/fire_number/presentation/providers/fire_providers.dart';
import 'package:inv_tracker/features/fire_number/presentation/screens/fire_dashboard_screen.dart';
import 'package:inv_tracker/features/fire_number/presentation/widgets/fire_dashboard_card.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:inv_tracker/l10n/generated/app_localizations_en.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _asOf = DateTime(2026, 10, 2);

FireSettingsEntity _settings({
  int birthYear = 1996,
  int targetFireAge = 45,
  String? currency = 'INR',
  double monthlyPassiveIncome = 0,
}) => FireSettingsEntity(
  id: 'fire',
  monthlyExpenses: 50000,
  birthYear: birthYear,
  targetFireAge: targetFireAge,
  monthlyPassiveIncome: monthlyPassiveIncome,
  isSetupComplete: true,
  currency: currency,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

FireCalculationResult _calculate(
  FireSettingsEntity settings, {
  required double corpus,
  required double savings,
  MonthlySavingsSource source = MonthlySavingsSource.history,
}) => FireCalculationService().calculate(
  settings: settings,
  currentPortfolioValue: corpus,
  currentMonthlySavings: savings,
  asOf: _asOf,
  inputs: FireInputsSummary(
    investmentsValue: corpus,
    principalWithoutValue: 0,
    otherAssets: 0,
    savingsSource: source,
  ),
);

/// The app's strings with the not-enough-history status texts marked, to
/// show the UI reads them from the ARB file rather than English in code.
class _MarkedL10n extends AppLocalizationsEn {
  @override
  String get fireStatusNotEnoughHistory => '[status: not enough history]';

  @override
  String get fireStatusShortNotEnoughHistory => '[short: too early]';
}

class _MarkedL10nDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _MarkedL10nDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) async => _MarkedL10n();

  @override
  bool shouldReload(_MarkedL10nDelegate old) => false;
}

Future<void> _pump(
  WidgetTester tester,
  FireSettingsEntity settings,
  FireCalculationResult result, {
  Widget home = const FireDashboardScreen(),
  bool markedStrings = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currencyCodeProvider.overrideWith((ref) => 'INR'),
        currencySymbolProvider.overrideWith((ref) => '₹'),
        currencyLocaleProvider.overrideWith((ref) => 'en_IN'),
        fireSettingsProvider.overrideWith((ref) => Stream.value(settings)),
        fireCalculationProvider.overrideWithValue(AsyncValue.data(result)),
      ],
      child: MaterialApp(
        localizationsDelegates: markedStrings
            ? const [
                _MarkedL10nDelegate(),
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ]
            : AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a user ahead of schedule is not told to invest more', (
    tester,
  ) async {
    // S5: saving ₹60k against ₹10.8k needed (gap −₹49,235.22).
    final settings = _settings(birthYear: 1998, targetFireAge: 50);
    await _pump(
      tester,
      settings,
      _calculate(settings, corpus: 3660000, savings: 60000),
    );

    expect(find.textContaining('more to stay on track'), findsNothing);
    expect(find.text('Ahead of Schedule'), findsOneWidget);
  });

  testWidgets('a behind user with a surplus is not told to invest more', (
    tester,
  ) async {
    final settings = _settings();
    final behind = _calculate(settings, corpus: 1402551.73, savings: 0);
    final withSurplus = FireCalculationResult(
      fireNumber: behind.fireNumber,
      coastFireNumber: behind.coastFireNumber,
      baristaFireNumber: behind.baristaFireNumber,
      currentPortfolioValue: behind.currentPortfolioValue,
      progressPercentage: behind.progressPercentage,
      status: FireProgressStatus.behind,
      requiredMonthlySavings: 40000,
      currentMonthlySavingsRate: 49200,
      projectedFireAge: 46,
      inflationAdjustedFireNumber: behind.inflationAdjustedFireNumber,
      inflationAdjustedMonthlyExpenses: behind.inflationAdjustedMonthlyExpenses,
      portfolioGap: behind.portfolioGap,
      monthlyGap: -9200,
      milestones: behind.milestones,
      achievedMilestones: behind.achievedMilestones,
      emergencyFundNeeded: behind.emergencyFundNeeded,
      healthcareCorpusNeeded: behind.healthcareCorpusNeeded,
      coreRetirementCorpus: behind.coreRetirementCorpus,
      expenseMultiple: behind.expenseMultiple,
      inputs: behind.inputs,
      calculatedAt: _asOf,
    );
    await _pump(tester, settings, withSurplus);

    expect(find.textContaining('more to stay on track'), findsNothing);
  });

  testWidgets('a user who is short is told how much more to invest', (
    tester,
  ) async {
    final settings = _settings();
    await _pump(
      tester,
      settings,
      _calculate(settings, corpus: 1402551.73, savings: 0),
    );

    expect(find.textContaining('more to stay on track'), findsOneWidget);
    expect(find.text('Age 76'), findsOneWidget);
  });

  testWidgets('shows the real multiple and the FIRE number breakdown', (
    tester,
  ) async {
    final settings = _settings();
    await _pump(
      tester,
      settings,
      _calculate(settings, corpus: 1402551.73, savings: 0),
    );

    expect(find.textContaining('30.5× your annual expenses'), findsOneWidget);
    expect(find.textContaining('25x'), findsNothing);
    expect(find.text('Healthcare buffer'), findsOneWidget);
    expect(find.text('Emergency fund'), findsOneWidget);
  });

  testWidgets('shows Not reachable instead of age 100', (tester) async {
    final settings = _settings();
    await _pump(tester, settings, _calculate(settings, corpus: 0, savings: 0));

    expect(find.text('Not reachable'), findsWidgets);
    expect(find.text('Age 100'), findsNothing);
  });

  testWidgets('says when there is not enough history to estimate savings', (
    tester,
  ) async {
    final settings = _settings();
    await _pump(
      tester,
      settings,
      _calculate(
        settings,
        corpus: 1000000,
        savings: 0,
        source: MonthlySavingsSource.notEnoughHistory,
      ),
    );

    expect(find.textContaining('Not enough history'), findsWidgets);
    expect(find.textContaining('more to stay on track'), findsNothing);
    // Nothing is told from an assumed ₹0 a month (PLAN-02): no status,
    // no projected age or date, no nudge to invest more.
    expect(find.text('Not Enough History'), findsOneWidget);
    // The heading and the short status under the projected date.
    expect(find.text('Too early to tell'), findsNWidgets(2));
    expect(find.text('Behind Schedule'), findsNothing);
    expect(find.text('Action Needed'), findsNothing);
    expect(find.textContaining('Boost your monthly investments'), findsNothing);
    expect(find.textContaining('Age 8'), findsNothing);
    expect(find.text('Not reachable'), findsNothing);
  });

  testWidgets('a user past the target age is asked to move it', (tester) async {
    // Age 46, target 45: nothing more is required each month, so the gap
    // is not positive, but the user is behind.
    final settings = _settings(birthYear: 1980);
    await _pump(
      tester,
      settings,
      _calculate(settings, corpus: 1402551.73, savings: 0),
    );

    expect(find.text("You're needs focus!"), findsNothing);
    expect(find.text('Keep up your current investment rate.'), findsNothing);
    expect(find.textContaining('Move your target age'), findsOneWidget);
  });

  testWidgets('the FIRE number breakdown adds up with passive income', (
    tester,
  ) async {
    // ₹1.83 Cr of buffers less ₹10,000 × 12 × 25 = ₹30L is ₹1.53 Cr.
    final settings = _settings(monthlyPassiveIncome: 10000);
    final result = _calculate(settings, corpus: 1402551.73, savings: 0);
    await _pump(tester, settings, result);

    expect(find.text('Less passive income and pension'), findsOneWidget);
    expect(
      find.text(
        '−${formatCompactCurrency(3000000, symbol: '₹', locale: 'en_IN')}',
      ),
      findsOneWidget,
    );
  });

  testWidgets('settings saved without a currency ask for nothing', (
    tester,
  ) async {
    // A base-currency change stamps them with the old base currency (the
    // A03 backfill), so there is no card to confirm it and nothing that can
    // fail when tapped.
    final settings = _settings(currency: null);
    await _pump(
      tester,
      settings,
      _calculate(settings, corpus: 1402551.73, savings: 0),
    );

    expect(find.textContaining('Confirm INR'), findsNothing);
    expect(find.textContaining('read in INR'), findsNothing);
  });

  testWidgets('Retry reloads a missing exchange rate', (tester) async {
    // Settings in INR, base currency USD, and no rate on the first try.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    var rateBuilds = 0;

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currencyCodeProvider.overrideWith((ref) => 'USD'),
          currencySymbolProvider.overrideWith((ref) => 'US\$'),
          currencyLocaleProvider.overrideWith((ref) => 'en_US'),
          fireSettingsProvider.overrideWith((ref) => Stream.value(_settings())),
          firePortfolioInputsProvider.overrideWith(
            (ref) async => FirePortfolioInputs(
              corpus: const CorpusValue(currentValues: 12000),
              savings: const MonthlySavingsEstimate(
                amount: 500,
                monthsOfHistory: 24,
              ),
              currency: 'USD',
              asOf: _asOf,
            ),
          ),
          fireCurrencyRateProvider.overrideWith((ref, pair) async {
            rateBuilds++;
            if (rateBuilds == 1) throw Exception('no rate offline');
            return 1 / 83;
          }),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FireDashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(rateBuilds, 2);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('the not-enough-history status comes from the app strings', (
    tester,
  ) async {
    final settings = _settings();
    final result = _calculate(
      settings,
      corpus: 1000000,
      savings: 0,
      source: MonthlySavingsSource.notEnoughHistory,
    );

    await _pump(tester, settings, result, markedStrings: true);
    expect(find.text('[status: not enough history]'), findsOneWidget);
    expect(find.text('[short: too early]'), findsOneWidget);
    expect(find.text('Not Enough History'), findsNothing);

    await _pump(
      tester,
      settings,
      result,
      home: const Scaffold(body: FireDashboardCard()),
      markedStrings: true,
    );
    expect(find.text('[status: not enough history]'), findsOneWidget);
    expect(find.text('Not Enough History'), findsNothing);
  });
}
