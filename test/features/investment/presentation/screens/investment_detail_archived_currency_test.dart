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

class _PrivacyOn extends PrivacyModeNotifier {
  @override
  bool build() => true;
}

/// Fixed rate: 1 USD = 83.12 INR.
class _FixedRateService implements CurrencyConversionService {
  double _rate(String from, String to) {
    if (from == to) return 1.0;
    if (from == 'USD' && to == 'INR') return 83.12;
    if (from == 'INR' && to == 'USD') return 1 / 83.12;
    throw StateError('No rate for $from->$to in this test');
  }

  @override
  Future<double> convert({
    required double amount,
    required String from,
    required String to,
    DateTime? date,
  }) async => amount * _rate(from, to);

  @override
  Future<Map<String, double>> batchConvertHistorical({
    required Map<String, ConversionRequest> requests,
    required String to,
  }) async => {
    for (final e in requests.entries)
      e.key: e.value.amount * _rate(e.value.from, to),
  };

  @override
  Future<double?> getLastKnownRate({
    required String from,
    required String to,
  }) async => _rate(from, to);

  @override
  Future<double> getRate({
    required String from,
    required String to,
    DateTime? date,
  }) async => _rate(from, to);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// An archived, still-open USD bond: USD 1,000 in, no payout yet, 7% p.a.
/// compounded quarterly for 3 years, interest paid at maturity.
final _archivedUsdBond = InvestmentEntity(
  id: 'bond-1',
  name: 'US Treasury',
  type: InvestmentType.bonds,
  status: InvestmentStatus.open,
  isArchived: true,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  startDate: DateTime(2026, 1, 1),
  expectedRate: 7,
  tenureMonths: 36,
  compoundingFrequency: CompoundingFrequency.quarterly,
  interestPayoutMode: InterestPayoutMode.cumulative,
  currency: 'USD',
);

final _flows = [
  CashFlowEntity(
    id: 'cf-1',
    investmentId: 'bond-1',
    type: CashFlowType.invest,
    amount: 1000,
    currency: 'USD',
    date: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
  ),
];

Future<void> _pump(WidgetTester tester, {bool privacy = false}) async {
  // The screen reads feature flags (the Upcoming tab), which read prefs.
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        privacyModeProvider.overrideWith(
          privacy ? _PrivacyOn.new : _PrivacyOff.new,
        ),
        currencyCodeProvider.overrideWithValue('INR'),
        currencyConversionServiceProvider.overrideWithValue(
          _FixedRateService(),
        ),
        archivedCashFlowsByInvestmentProvider(
          'bond-1',
        ).overrideWith((ref) => Stream.value(_flows)),
        expectedCashFlowsByInvestmentProvider(
          'bond-1',
        ).overrideWith((ref) => Stream.value([])),
        documentsByInvestmentProvider(
          'bond-1',
        ).overrideWith((ref) => Stream.value([])),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InvestmentDetailScreen(investment: _archivedUsdBond),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Archived non-base-currency investment detail', () {
    testWidgets(
      'projects maturity from the principal converted to the base currency',
      (tester) async {
        await _pump(tester);

        // USD 1,000 x 83.12 = Rs83,120; x 1.0175^12 = Rs1,02,357.24.
        expect(
          find.text('Projected at maturity ₹1,02,357 (7.19% p.a.)'),
          findsOneWidget,
        );
        // The unconverted USD projection under the rupee symbol.
        expect(find.textContaining('₹1,231'), findsNothing);
      },
    );

    testWidgets('privacy mode hides the converted projection', (tester) async {
      await _pump(tester, privacy: true);

      expect(find.textContaining('Projected at maturity'), findsNothing);
      expect(find.textContaining('1,02,357'), findsNothing);
    });
  });
}
