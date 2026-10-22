// A23 / INV-04: an archived investment's detail screen is read-only. Its cash
// flows live in the archive collection, so add, edit and delete wrote to the
// active collection: silent no-ops and orphaned flows.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/income_projection/presentation/providers/expected_cash_flow_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_detail_fab_widgets.dart';
import 'package:inv_tracker/features/investment/presentation/screens/investment_detail_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/mock_currency_conversion_service.dart';

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

/// Archive calls succeed and record the ids.
class _FakeInvestmentNotifier extends InvestmentNotifier {
  final archived = <String>[];
  final restored = <String>[];

  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  @override
  Future<void> archiveInvestment(String id) async {
    archived.add(id);
  }

  @override
  Future<void> unarchiveInvestment(String id) async {
    restored.add(id);
  }
}

final _fund = InvestmentEntity(
  id: 'inv-1',
  name: 'Index fund',
  type: InvestmentType.stocks,
  status: InvestmentStatus.open,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  currency: 'INR',
);

final _flows = [
  CashFlowEntity(
    id: 'cf-1',
    investmentId: 'inv-1',
    type: CashFlowType.invest,
    amount: 100000,
    currency: 'INR',
    date: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
  ),
];

/// Opens the detail screen from a launcher, so that going back is possible.
Future<void> _pump(
  WidgetTester tester, {
  required _FakeInvestmentNotifier notifier,
  bool archived = false,
  List<CashFlowEntity>? flows,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final investment = _fund.copyWith(isArchived: archived);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        privacyModeProvider.overrideWith(_PrivacyOff.new),
        currencyCodeProvider.overrideWithValue('INR'),
        currencyConversionServiceProvider.overrideWithValue(
          MockCurrencyConversionService(),
        ),
        investmentNotifierProvider.overrideWith(() => notifier),
        cashFlowsByInvestmentProvider(
          'inv-1',
        ).overrideWith((ref) => Stream.value(flows ?? _flows)),
        archivedCashFlowsByInvestmentProvider(
          'inv-1',
        ).overrideWith((ref) => Stream.value(flows ?? _flows)),
        expectedCashFlowsByInvestmentProvider(
          'inv-1',
        ).overrideWith((ref) => Stream.value([])),
        documentsByInvestmentProvider(
          'inv-1',
        ).overrideWith((ref) => Stream.value([])),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      InvestmentDetailScreen(investment: investment),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first));

Future<void> _openOptions(WidgetTester tester) async {
  await tester.tap(find.byTooltip(_l10n(tester).tooltipMoreOptions));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('archived: no add button, no swipe actions, banner says why', (
    tester,
  ) async {
    await _pump(tester, notifier: _FakeInvestmentNotifier(), archived: true);

    expect(find.byType(TransactionFab), findsNothing);
    expect(find.byType(Dismissible), findsNothing);
    expect(find.text(_l10n(tester).archivedReadOnlyBanner), findsOneWidget);
  });

  testWidgets('archived: Docs tab offers no add button', (tester) async {
    await _pump(tester, notifier: _FakeInvestmentNotifier(), archived: true);

    await tester.tap(find.text(_l10n(tester).segmentDocs));
    await tester.pumpAndSettle();

    expect(find.byType(DocumentFab), findsNothing);
  });

  testWidgets('archived: options offer unarchive and delete, not edit or '
      'close', (tester) async {
    await _pump(tester, notifier: _FakeInvestmentNotifier(), archived: true);

    await _openOptions(tester);

    expect(find.text('Unarchive Investment'), findsOneWidget);
    expect(find.text('Delete Investment'), findsOneWidget);
    expect(find.text('Edit Investment'), findsNothing);
    expect(find.text('Close Investment'), findsNothing);
  });

  testWidgets('active: keeps the add button and swipe actions, no banner', (
    tester,
  ) async {
    await _pump(tester, notifier: _FakeInvestmentNotifier());

    expect(find.byType(TransactionFab), findsOneWidget);
    expect(find.byType(Dismissible), findsOneWidget);
    expect(find.text(_l10n(tester).archivedReadOnlyBanner), findsNothing);

    await _openOptions(tester);
    expect(find.text('Edit Investment'), findsOneWidget);
    expect(find.text('Close Investment'), findsOneWidget);
  });

  testWidgets('archived and empty: no instruction to tap a missing add '
      'button; active and empty keeps it', (tester) async {
    await _pump(
      tester,
      notifier: _FakeInvestmentNotifier(),
      archived: true,
      flows: const [],
    );
    expect(find.text('No Cash Flows Yet'), findsOneWidget);
    expect(find.text('Tap + Add to start tracking'), findsNothing);
  });

  testWidgets('active and empty keeps the add instruction', (tester) async {
    await _pump(tester, notifier: _FakeInvestmentNotifier(), flows: const []);
    expect(find.text('Tap + Add to start tracking'), findsOneWidget);
  });
}
