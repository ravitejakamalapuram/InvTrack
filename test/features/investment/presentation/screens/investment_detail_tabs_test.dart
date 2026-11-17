// An investment has two tabs, Activity and Docs.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
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

Future<void> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  // The archived banner adds a line, which pushed the lazily built Docs list
  // past the default 800x600 view.
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        privacyModeProvider.overrideWith(_PrivacyOff.new),
        currencyCodeProvider.overrideWithValue('INR'),
        currencyConversionServiceProvider.overrideWithValue(
          _SameCurrencyService(),
        ),
        archivedCashFlowsByInvestmentProvider(
          'fd-1',
        ).overrideWith((ref) => Stream.value(_flows)),
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
}

void main() {
  testWidgets('an investment has an Activity tab and a Docs tab only', (
    tester,
  ) async {
    await _pump(tester);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(InvestmentDetailScreen)),
    );

    expect(find.text(l10n.segmentActivity), findsOneWidget);
    expect(find.text(l10n.segmentDocs), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.segmentActivity), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.segmentDocs), findsOneWidget);
  });

  testWidgets('Docs opens the documents list', (tester) async {
    await _pump(tester);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(InvestmentDetailScreen)),
    );

    expect(find.byType(DocumentListWidget), findsNothing);
    await tester.tap(find.text(l10n.segmentDocs));
    await tester.pumpAndSettle();

    expect(find.byType(DocumentListWidget), findsOneWidget);
  });
}
