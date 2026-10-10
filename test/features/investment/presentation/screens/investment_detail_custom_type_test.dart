// #936: the detail screen's type chip shows an Other investment's custom
// label while the feature flag is on, and says Other for a legacy record or
// with the flag off. Mutation guard: without the flag check the second test
// fails.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
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

// Archived, so the screen reads archived flows, which keeps the test free of
// the live multi-currency stats stack. The chip is the same either way.
InvestmentEntity _album({String? label, InvestmentType? type}) =>
    InvestmentEntity(
      id: 'inv-1',
      name: 'Stamp album',
      type: type ?? InvestmentType.other,
      status: InvestmentStatus.open,
      isArchived: true,
      createdAt: DateTime(2026, 4, 1),
      updatedAt: DateTime(2026, 4, 1),
      currency: 'INR',
      customTypeLabel: label,
    );

final _flows = [
  CashFlowEntity(
    id: 'cf-1',
    investmentId: 'inv-1',
    type: CashFlowType.invest,
    amount: 100000,
    currency: 'INR',
    date: DateTime(2026, 4, 1),
    createdAt: DateTime(2026, 4, 1),
  ),
];

Future<void> _pump(
  WidgetTester tester,
  InvestmentEntity investment, {
  required bool flag,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isCustomInvestmentTypesEnabledProvider.overrideWithValue(flag),
        privacyModeProvider.overrideWith(_PrivacyOff.new),
        currencyCodeProvider.overrideWithValue('INR'),
        currencyConversionServiceProvider.overrideWithValue(
          _SameCurrencyService(),
        ),
        archivedCashFlowsByInvestmentProvider(
          'inv-1',
        ).overrideWith((ref) => Stream.value(_flows)),
        documentsByInvestmentProvider(
          'inv-1',
        ).overrideWith((ref) => Stream.value([])),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InvestmentDetailScreen(investment: investment),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('flag on: the chip shows the custom label', (tester) async {
    await _pump(tester, _album(label: 'Stamps'), flag: true);

    expect(find.text('Stamps'), findsOneWidget);
    expect(find.text('Other'), findsNothing);
  });

  testWidgets('flag off: the chip says Other and the label is not shown', (
    tester,
  ) async {
    await _pump(tester, _album(label: 'Stamps'), flag: false);

    expect(find.text('Other'), findsOneWidget);
    expect(find.text('Stamps'), findsNothing);
  });

  testWidgets('a legacy Other investment says Other with the flag on', (
    tester,
  ) async {
    await _pump(tester, _album(), flag: true);

    expect(find.text('Other'), findsOneWidget);
  });

  testWidgets('a built-in type never shows a label', (tester) async {
    await _pump(
      tester,
      _album(label: 'Stamps', type: InvestmentType.bonds),
      flag: true,
    );

    expect(find.text('Bonds/Debentures'), findsOneWidget);
    expect(find.text('Stamps'), findsNothing);
  });
}
