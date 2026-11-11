// Weight row on the Add Cash Flow screen (#946): shown for gold on Invest and
// Return, optional, saved with the typed amount, never for other types.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/unit_holding.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_notifier.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_transaction_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Saved {
  _Saved(this.amount, this.quantity, this.unit);
  final double amount;
  final double? quantity;
  final QuantityUnit? unit;
}

class _Recorder extends InvestmentNotifier {
  _Recorder(this.saved);
  final List<_Saved> saved;

  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  @override
  Future<void> addCashFlow({
    required String investmentId,
    required CashFlowType type,
    required double amount,
    required DateTime date,
    String? notes,
    String? currency,
    double? quantity,
    QuantityUnit? quantityUnit,
  }) async {
    saved.add(_Saved(amount, quantity, quantityUnit));
  }

  @override
  Future<void> updateCashFlow({
    required String id,
    required String investmentId,
    required CashFlowType type,
    required double amount,
    required DateTime date,
    String? notes,
    required DateTime createdAt,
    String? currency,
    double? quantity,
    QuantityUnit? quantityUnit,
  }) async {
    saved.add(_Saved(amount, quantity, quantityUnit));
  }
}

InvestmentEntity _inv(InvestmentType type) => InvestmentEntity(
  id: 'inv-1',
  name: 'Gold',
  type: type,
  status: InvestmentStatus.open,
  createdAt: DateTime(2026, 4, 1),
  updatedAt: DateTime(2026, 4, 1),
  currency: 'INR',
);

Future<void> _open(
  WidgetTester tester,
  InvestmentType type,
  List<_Saved> saved, {
  CashFlowType flow = CashFlowType.invest,
  CashFlowEntity? edit,
  bool investmentLoads = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/add',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox()),
      GoRoute(
        path: '/add',
        builder: (_, _) => AddTransactionScreen(
          investmentId: 'inv-1',
          initialType: flow,
          cashFlowToEdit: edit,
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currencyCodeProvider.overrideWithValue('INR'),
        investmentByIdProvider('inv-1').overrideWith(
          (ref) => investmentLoads
              ? Future.value(_inv(type))
              : Completer<InvestmentEntity?>().future,
        ),
        investmentNotifierProvider.overrideWith(() => _Recorder(saved)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.text('Save Cash Flow'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('gold on Invest shows an optional Weight field and Unit', (
    tester,
  ) async {
    await _open(tester, InvestmentType.gold, []);
    expect(find.text('Weight'), findsWidgets);
    expect(find.text('Unit'), findsOneWidget);
  });

  testWidgets('other types never show the weight row', (tester) async {
    await _open(tester, InvestmentType.fixedDeposit, []);
    expect(find.text('Weight'), findsNothing);
  });

  testWidgets('gold Income and Fee have no weight row', (tester) async {
    await _open(tester, InvestmentType.gold, [], flow: CashFlowType.income);
    expect(find.text('Weight'), findsNothing);
  });

  testWidgets('weight is saved with the typed amount, in grams by default', (
    tester,
  ) async {
    final saved = <_Saved>[];
    await _open(tester, InvestmentType.gold, saved);
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '64500');
    await tester.enterText(find.widgetWithText(TextField, 'Weight'), '10');
    await _save(tester);
    expect(saved, hasLength(1));
    expect(saved.single.amount, 64500);
    expect(saved.single.quantity, 10);
    expect(saved.single.unit, QuantityUnit.gram);
  });

  testWidgets('leaving the weight empty saves the flow without one', (
    tester,
  ) async {
    final saved = <_Saved>[];
    await _open(tester, InvestmentType.gold, saved);
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '64500');
    await _save(tester);
    expect(saved.single.quantity, isNull);
    expect(saved.single.unit, isNull);
  });

  testWidgets('a zero weight is refused', (tester) async {
    final saved = <_Saved>[];
    await _open(tester, InvestmentType.gold, saved);
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '64500');
    await tester.enterText(find.widgetWithText(TextField, 'Weight'), '0');
    await _save(tester);
    expect(saved, isEmpty);
    expect(find.text('Weight must be above 0'), findsOneWidget);
  });

  testWidgets('editing a weighted flow keeps its weight while the investment '
      'is still loading', (tester) async {
    final saved = <_Saved>[];
    final edit = CashFlowEntity(
      id: 'cf1',
      investmentId: 'inv-1',
      date: DateTime(2026, 11, 3),
      type: CashFlowType.invest,
      amount: 64500,
      createdAt: DateTime(2026, 11, 3),
      currency: 'INR',
      quantity: 10,
      quantityUnit: QuantityUnit.gram,
    );
    await _open(
      tester,
      InvestmentType.gold,
      saved,
      edit: edit,
      investmentLoads: false,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Notes (Optional)'),
      'x',
    );
    await _save(tester);
    expect(saved, hasLength(1));
    expect(saved.single.quantity, 10);
    expect(saved.single.unit, QuantityUnit.gram);
  });

  testWidgets('the implied price per unit is shown as a hint', (tester) async {
    await _open(tester, InvestmentType.gold, []);
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '64500');
    await tester.enterText(find.widgetWithText(TextField, 'Weight'), '10');
    await tester.pump();
    expect(find.textContaining('6,450'), findsOneWidget);
  });
}
