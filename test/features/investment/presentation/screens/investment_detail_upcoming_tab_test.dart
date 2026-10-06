// A42: nothing generates expected cash flows yet, so the "Upcoming" tab on
// every investment could only ever say "No Expected Payments". While Income
// Guardian is hidden the tab is not shown and its Firestore query never runs.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/income_projection/presentation/providers/expected_cash_flow_providers.dart';
import 'package:inv_tracker/features/income_projection/presentation/widgets/expected_income_section.dart';
import 'package:inv_tracker/features/investment/presentation/providers/document_providers.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/document_list_widget.dart';
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

// Archived, so the screen reads archived flows, which keeps the test free of
// the live multi-currency stats stack. The tab bar is the same either way.
final _fd = InvestmentEntity(
  id: 'fd-1',
  name: 'Bank FD',
  type: InvestmentType.fixedDeposit,
  status: InvestmentStatus.open,
  isArchived: true,
  createdAt: DateTime(2026, 4, 1),
  updatedAt: DateTime(2026, 4, 1),
  currency: 'INR',
);

final _flows = [
  CashFlowEntity(
    id: 'cf-1',
    investmentId: 'fd-1',
    type: CashFlowType.invest,
    amount: 100000,
    currency: 'INR',
    date: DateTime(2026, 4, 1),
    createdAt: DateTime(2026, 4, 1),
  ),
];

Future<bool> _pump(
  WidgetTester tester, {
  required bool overridesAllowed,
  Map<String, Object> stored = const {},
}) async {
  SharedPreferences.setMockInitialValues(stored);
  final prefs = await SharedPreferences.getInstance();
  var expectedFlowsQueried = false;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        featureFlagOverridesAllowedProvider.overrideWithValue(overridesAllowed),
        privacyModeProvider.overrideWith(_PrivacyOff.new),
        currencyCodeProvider.overrideWithValue('INR'),
        currencyConversionServiceProvider.overrideWithValue(
          _SameCurrencyService(),
        ),
        archivedCashFlowsByInvestmentProvider(
          'fd-1',
        ).overrideWith((ref) => Stream.value(_flows)),
        expectedCashFlowsByInvestmentProvider('fd-1').overrideWith((ref) {
          expectedFlowsQueried = true;
          return Stream.value([]);
        }),
        documentsByInvestmentProvider(
          'fd-1',
        ).overrideWith((ref) => Stream.value([])),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InvestmentDetailScreen(investment: _fd),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return expectedFlowsQueried;
}

void main() {
  testWidgets('Income Guardian hidden: no Upcoming tab and no query', (
    tester,
  ) async {
    final queried = await _pump(tester, overridesAllowed: false);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(InvestmentDetailScreen)),
    );

    expect(find.text(l10n.segmentActivity), findsOneWidget);
    expect(find.text(l10n.segmentDocs), findsOneWidget);
    expect(find.text(l10n.segmentUpcoming), findsNothing);
    expect(find.bySemanticsLabel(l10n.segmentUpcoming), findsNothing);
    expect(find.bySemanticsLabel(l10n.segmentActivity), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.segmentDocs), findsOneWidget);
    expect(queried, isFalse);
  });

  testWidgets('Docs still opens the documents list when Upcoming is hidden', (
    tester,
  ) async {
    await _pump(tester, overridesAllowed: false);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(InvestmentDetailScreen)),
    );

    expect(find.byType(DocumentListWidget), findsNothing);
    await tester.tap(find.text(l10n.segmentDocs));
    await tester.pumpAndSettle();

    expect(find.byType(DocumentListWidget), findsOneWidget);
    expect(find.byType(ExpectedIncomeSection), findsNothing);
  });

  testWidgets('with the flag on (Debug Settings) the Upcoming tab is back', (
    tester,
  ) async {
    final queried = await _pump(
      tester,
      overridesAllowed: true,
      stored: {'feature_flag_income_guardian': true},
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(InvestmentDetailScreen)),
    );

    expect(find.text(l10n.segmentUpcoming), findsOneWidget);
    expect(queried, isTrue);
  });
}
