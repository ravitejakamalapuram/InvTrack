// A119 (#893): a maturity date the user clears must not come back from the
// start date and tenure (InvestmentEntity.calculatedMaturityDate). Clearing
// it in the form clears the tenure too, says so, and after saving no score
// or estimate uses a maturity for the investment.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/calculations/current_value_calculator.dart';
import 'package:inv_tracker/core/calculations/modules/financial_module.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_investment_screen.dart';
import 'package:inv_tracker/features/portfolio_health/domain/entities/portfolio_health_score.dart';
import 'package:inv_tracker/features/portfolio_health/domain/services/portfolio_health_calculator.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../data/repositories/mock_investment_repository.dart';
import '../../../../mocks/mock_analytics_service.dart';
import '../../../../mocks/mock_notification_service.dart';

const _note = 'Tenure cleared too, so no maturity date is worked out from it.';

/// A 12-month cumulative FD at 7% from 1 Jan 2025, maturing 1 Jan 2026.
InvestmentEntity _fd({DateTime? maturityDate, bool withStartDate = true}) =>
    InvestmentEntity(
      id: 'inv-fd',
      name: 'SBI FD',
      type: InvestmentType.fixedDeposit,
      status: InvestmentStatus.open,
      notes: 'Old notes',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      maturityDate: maturityDate,
      startDate: withStartDate ? DateTime(2025, 1, 1) : null,
      tenureMonths: 12,
      expectedRate: 7.0,
      interestPayoutMode: InterestPayoutMode.cumulative,
      currency: 'INR',
    );

final _invested = CashFlowEntity(
  id: 'cf-1',
  investmentId: 'inv-fd',
  type: CashFlowType.invest,
  amount: 100000.00,
  currency: 'INR',
  date: DateTime(2025, 1, 1),
  createdAt: DateTime(2025, 1, 1),
);

PortfolioHealthScore _health(InvestmentEntity investment, DateTime asOf) {
  final terminalValues = {
    investment.id: CurrentValueCalculator.terminalValues(
      investments: [investment],
      cashFlows: [_invested],
      asOf: asOf,
    ),
  };
  return PortfolioHealthCalculator.calculate(
    investments: [investment],
    investmentStats: FinancialCalculatorModule().calculateStatsByInvestment([
      _invested,
    ], terminalValues: terminalValues),
    allCashFlows: [_invested],
    goalProgress: const [],
    terminalValues: terminalValues,
    asOf: asOf,
  )!;
}

Finder _editableWithText(String text) => find.byWidgetPredicate(
  (w) => w is EditableText && w.controller.text == text,
);

void main() {
  late FakeInvestmentRepository repository;

  setUp(() => repository = FakeInvestmentRepository());

  /// Opens the edit form for [investment], runs [edit], saves, and returns
  /// the stored investment.
  Future<InvestmentEntity> editAndSave(
    WidgetTester tester,
    InvestmentEntity investment,
    Future<void> Function(Finder scrollable) edit,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    repository.seed(investments: [investment], cashFlows: [_invested]);

    final router = GoRouter(
      initialLocation: '/edit',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Detail')),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (_, _) =>
                  AddInvestmentScreen(investmentToEdit: investment),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currencyCodeProvider.overrideWithValue('INR'),
          currencySymbolProvider.overrideWithValue('₹'),
          currencyLocaleProvider.overrideWithValue('en_IN'),
          analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
          investmentRepositoryProvider.overrideWithValue(repository),
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scrollable = find.byType(Scrollable).first;

    await edit(scrollable);

    final save = find.text('Save Changes');
    await tester.scrollUntilVisible(save, 200, scrollable: scrollable);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Detail'), findsOneWidget, reason: 'the form saved');
    return repository.investments.single;
  }

  testWidgets('clearing the maturity date clears the tenure and says so', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var notesShown = 0;
    SemanticsNode? noteSemantics;
    var tenureFieldsLeft = -1;
    final stored = await editAndSave(
      tester,
      _fd(maturityDate: DateTime(2026, 1, 1)),
      (scrollable) async {
        final clear = find.byTooltip('Clear maturity date');
        await tester.scrollUntilVisible(clear, 200, scrollable: scrollable);
        await tester.tap(clear);
        await tester.pumpAndSettle();

        final note = find.text(_note);
        notesShown = note.evaluate().length;
        if (notesShown == 1) noteSemantics = tester.getSemantics(note);
        tenureFieldsLeft = _editableWithText('12').evaluate().length;
      },
    );
    semantics.dispose();

    expect(stored.maturityDate, isNull);
    expect(stored.tenureMonths, isNull);
    expect(stored.calculatedMaturityDate, isNull);
    // Untouched fields are kept.
    expect(stored.startDate, DateTime(2025, 1, 1));
    expect(stored.expectedRate, 7.0);

    // The form said so, also to a screen reader, and the field is empty.
    expect(notesShown, 1);
    expect(noteSemantics, containsSemantics(label: _note, isLiveRegion: true));
    expect(tenureFieldsLeft, 0);

    // Health: 47 days before the old date, nothing is maturing soon
    // (main: 100%), and after it nothing is an overdue renewal (main: 1).
    expect(
      _health(stored, DateTime(2025, 11, 15)).liquidity.description,
      '0% maturing in 90 days',
    );
    final actions = _health(stored, DateTime(2026, 10, 5)).actionReadiness;
    expect(
      actions.suggestions.where((s) => s.contains('overdue renewals')),
      isEmpty,
    );
    // Only the stale-investment action is left (main: 2 pending actions).
    expect(actions.description, '1 pending actions');

    // The A10 estimate no longer stops at the old maturity: ₹1,00,000 at 7%
    // for 642 days (actual/365) = ₹1,12,637.56 on 5 Oct 2026.
    final value = CurrentValueCalculator.valuationOf(stored, [
      _invested,
    ], asOf: DateTime(2026, 10, 5))!;
    expect(value.date, DateTime(2026, 10, 5));
    expect(value.amount, closeTo(112637.56, 0.005));
  });

  testWidgets('the screen-reader clear action clears the tenure too', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var notesShown = 0;
    final stored = await editAndSave(
      tester,
      _fd(maturityDate: DateTime(2026, 1, 1)),
      (scrollable) async {
        final picker = find.bySemanticsLabel('Select Maturity Date');
        await tester.scrollUntilVisible(picker, 200, scrollable: scrollable);
        tester.semantics.customAction(
          find.semantics.byLabel('Select Maturity Date'),
          const CustomSemanticsAction(label: 'Clear maturity date'),
        );
        await tester.pumpAndSettle();
        notesShown = find.text(_note).evaluate().length;
      },
    );
    semantics.dispose();

    expect(stored.maturityDate, isNull);
    expect(stored.tenureMonths, isNull);
    expect(notesShown, 1);
  });

  testWidgets('the note stays when a new date is picked after clearing', (
    tester,
  ) async {
    var notesShown = -1;
    final stored = await editAndSave(
      tester,
      _fd(maturityDate: DateTime(2026, 1, 1)),
      (scrollable) async {
        final clear = find.byTooltip('Clear maturity date');
        await tester.scrollUntilVisible(clear, 200, scrollable: scrollable);
        await tester.tap(clear);
        await tester.pumpAndSettle();

        await tester.tap(find.text('No maturity date set'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        notesShown = find.text(_note).evaluate().length;
      },
    );

    // The picked date is saved without a tenure, and the form said so.
    expect(stored.maturityDate, isNotNull);
    expect(stored.tenureMonths, isNull);
    expect(notesShown, 1);
  });

  testWidgets('with no start date, clearing the date keeps the tenure', (
    tester,
  ) async {
    var notesShown = -1;
    final stored = await editAndSave(
      tester,
      _fd(maturityDate: DateTime(2026, 1, 1), withStartDate: false),
      (scrollable) async {
        final clear = find.byTooltip('Clear maturity date');
        await tester.scrollUntilVisible(clear, 200, scrollable: scrollable);
        await tester.tap(clear);
        await tester.pumpAndSettle();
        notesShown = find.text(_note).evaluate().length;
      },
    );

    // Without a start date the tenure cannot work the date out again.
    expect(stored.maturityDate, isNull);
    expect(stored.tenureMonths, 12);
    expect(stored.calculatedMaturityDate, isNull);
    expect(notesShown, 0);
  });

  testWidgets('control: an edit that keeps the date keeps the tenure', (
    tester,
  ) async {
    final stored = await editAndSave(
      tester,
      _fd(maturityDate: DateTime(2026, 1, 1)),
      (_) async {
        await tester.enterText(_editableWithText('Old notes'), 'New notes');
        await tester.pumpAndSettle();
      },
    );

    expect(find.text(_note), findsNothing);
    expect(stored.notes, 'New notes');
    expect(stored.maturityDate, DateTime(2026, 1, 1));
    expect(stored.tenureMonths, 12);

    // The estimate stops at maturity: ₹1,00,000 at 7% for 365 days.
    final value = CurrentValueCalculator.valuationOf(stored, [
      _invested,
    ], asOf: DateTime(2026, 10, 5))!;
    expect(value.date, DateTime(2026, 1, 1));
    expect(value.amount, closeTo(107000.00, 0.005));
  });

  test('control: a tenure with no maturity date ever entered still gives '
      'one', () {
    expect(_fd().calculatedMaturityDate, DateTime(2026, 1, 1));
  });
}
