// #994: picking a template must not put a rate or a term into the form.
// A template sets the type and the structural defaults (payout mode,
// compounding, income frequency, risk). Its typical rate is the hint of the
// empty rate field (AppTextField shows a hint while the field is focused) and
// is never saved. A rate and a tenure left empty mean no
// maturity date, no maturity reminder, no estimated value, and an XIRR that is
// "—" until a current value exists (money rule 4).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/calculations/current_value_calculator.dart';
import 'package:inv_tracker/core/calculations/modules/financial_module.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/app_text_field.dart';
import 'package:inv_tracker/core/widgets/gradient_button.dart';
import 'package:inv_tracker/core/widgets/type_selector.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/models/investment_template.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_investment_screen.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/template_selector.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../data/repositories/mock_investment_repository.dart';
import '../../../../mocks/mock_analytics_service.dart';
import '../../../../mocks/mock_notification_service.dart';

const _rateLabel = 'Expected Return Rate (% p.a.)';
const _tenureLabel = 'Tenure (Months)';

/// The typical rate each template shows as a hint, as the rate field spells it.
const _hintByTemplate = <String, String>{
  'fd': 'e.g. 7',
  'p2p': 'e.g. 12',
  'gold': 'e.g. 2.5',
  'bonds': 'e.g. 9',
  'rd': 'e.g. 6.5',
  'rental': 'e.g. 3',
};

Finder _field(String label) => find.descendant(
  of: find.widgetWithText(AppTextField, label),
  matching: find.byType(EditableText),
);

String _textOf(WidgetTester tester, String label) =>
    tester.widget<EditableText>(_field(label)).controller.text;

Future<void> _enter(WidgetTester tester, String label, String text) async {
  final field = _field(label);
  await tester.scrollUntilVisible(
    field,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

/// Taps the field so it is focused: AppTextField keeps its label inline and
/// withholds the hint until then.
Future<void> _focus(WidgetTester tester, String label) async {
  final field = _field(label);
  await tester.scrollUntilVisible(
    field,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(field);
  await tester.pumpAndSettle();
}

/// The opacity of [hint] in the field named [label]: 1.0 when the field shows
/// it. `find.text` also matches the hint at opacity 0, so it cannot tell.
double _hintOpacity(WidgetTester tester, String label, String hint) {
  final text = find.descendant(
    of: find.widgetWithText(AppTextField, label),
    matching: find.text(hint),
  );
  return tester
      .widget<AnimatedOpacity>(
        find.ancestor(of: text, matching: find.byType(AnimatedOpacity)).first,
      )
      .opacity;
}

/// Picks today in the start date picker.
Future<void> _pickToday(WidgetTester tester) async {
  final when = find.text('When did you invest?');
  await _scrollTo(tester, when);
  await tester.tap(when);
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );
}

void main() {
  late FakeInvestmentRepository repository;
  late FakeNotificationService notifications;

  setUp(() {
    repository = FakeInvestmentRepository();
    notifications = FakeNotificationService();
  });

  /// Opens the new-investment form (with [template] pre-selected, as the
  /// Overview chips do) over a real notifier, the in-memory repository and the
  /// recording notification service.
  Future<void> pumpForm(
    WidgetTester tester, {
    InvestmentTemplate? template,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/add',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Overview')),
          routes: [
            GoRoute(
              path: 'add',
              builder: (_, _) =>
                  AddInvestmentScreen(preselectedTemplate: template),
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
          notificationServiceProvider.overrideWithValue(notifications),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Names the investment, saves it and returns what was stored.
  Future<InvestmentEntity> saveNamed(WidgetTester tester) async {
    await tester.enterText(find.byType(EditableText).first, 'My deposit');
    final save = find.byType(GradientButton);
    await _scrollTo(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Overview'), findsOneWidget, reason: 'the form saved');
    return repository.investments.single;
  }

  group('picking a template', () {
    testWidgets('FD leaves the rate and tenure empty and hints the rate', (
      tester,
    ) async {
      await pumpForm(tester, template: InvestmentTemplates.fixedDeposit);

      expect(_textOf(tester, _rateLabel), isEmpty);
      expect(_textOf(tester, _tenureLabel), isEmpty);
      // The typical rate is the hint in the empty rate field, nothing else.
      expect(
        find.descendant(
          of: find.widgetWithText(AppTextField, _rateLabel),
          matching: find.text('e.g. 7'),
        ),
        findsOneWidget,
      );
      expect(find.text('e.g. 7.5'), findsNothing);
      // The tenure field keeps its own hint.
      expect(
        find.descendant(
          of: find.widgetWithText(AppTextField, _tenureLabel),
          matching: find.text('e.g. 12'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the FD hint is shown once the empty rate field is focused', (
      tester,
    ) async {
      await pumpForm(tester, template: InvestmentTemplates.fixedDeposit);
      await _focus(tester, _rateLabel);

      expect(_hintOpacity(tester, _rateLabel, 'e.g. 7'), 1.0);
      // Showing the hint puts nothing in the field.
      expect(_textOf(tester, _rateLabel), isEmpty);
    });

    for (final entry in _hintByTemplate.entries) {
      testWidgets('${entry.key} hints "${entry.value}" in the empty rate field '
          'and fills no number', (tester) async {
        await pumpForm(tester, template: InvestmentTemplates.byId(entry.key));

        expect(_textOf(tester, _rateLabel), isEmpty);
        expect(
          find.descendant(
            of: find.widgetWithText(AppTextField, _rateLabel),
            matching: find.text(entry.value),
          ),
          findsOneWidget,
        );
        await _focus(tester, _rateLabel);
        expect(_hintOpacity(tester, _rateLabel, entry.value), 1.0);
        expect(_textOf(tester, _rateLabel), isEmpty);
        // A form without the tenure field has no tenure to be filled.
        if (find
            .widgetWithText(AppTextField, _tenureLabel)
            .evaluate()
            .isNotEmpty) {
          expect(_textOf(tester, _tenureLabel), isEmpty);
        }
      });
    }

    testWidgets('without a template the rate hint is the generic example', (
      tester,
    ) async {
      await pumpForm(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(TypeSelector<InvestmentType>),
          matching: find.text('Fixed Deposit'),
        ),
      );
      await tester.pumpAndSettle();

      expect(_textOf(tester, _rateLabel), isEmpty);
      expect(find.text('e.g. 7.5'), findsOneWidget);
    });

    testWidgets('the form selector fills no rate or tenure either', (
      tester,
    ) async {
      await pumpForm(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(TemplateSelector),
          matching: find.text('Fixed Deposit'),
        ),
      );
      await tester.pumpAndSettle();

      expect(_textOf(tester, _rateLabel), isEmpty);
      expect(_textOf(tester, _tenureLabel), isEmpty);
      expect(find.text('e.g. 7'), findsOneWidget);
      // The card may still say what the template typically earns.
      expect(find.text('~7% p.a.'), findsWidgets);
    });

    testWidgets('a rate the user already typed is kept', (tester) async {
      await pumpForm(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(TypeSelector<InvestmentType>),
          matching: find.text('Fixed Deposit'),
        ),
      );
      await tester.pumpAndSettle();
      await _enter(tester, _rateLabel, '8.1');
      await _enter(tester, _tenureLabel, '24');

      await _scrollTo(tester, find.byType(TemplateSelector));
      await tester.tap(
        find.descendant(
          of: find.byType(TemplateSelector),
          matching: find.text('Fixed Deposit'),
        ),
      );
      await tester.pumpAndSettle();

      expect(_textOf(tester, _rateLabel), '8.1');
      expect(_textOf(tester, _tenureLabel), '24');
    });

    testWidgets('the hint goes when the type no longer matches the template', (
      tester,
    ) async {
      await pumpForm(tester, template: InvestmentTemplates.fixedDeposit);
      expect(find.text('e.g. 7'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(TypeSelector<InvestmentType>),
          matching: find.text('Bonds/Debentures'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('e.g. 7'), findsNothing);
      expect(find.text('e.g. 7.5'), findsOneWidget);
    });
  });

  group('saving a template investment', () {
    for (final template in InvestmentTemplates.all) {
      testWidgets('${template.id}: stores no rate, tenure or maturity and '
          'schedules no maturity reminder', (tester) async {
        await pumpForm(tester, template: template);
        final stored = await saveNamed(tester);

        expect(stored.expectedRate, isNull);
        expect(stored.tenureMonths, isNull);
        expect(stored.maturityDate, isNull);
        expect(stored.calculatedMaturityDate, isNull);
        expect(notifications.scheduledMaturityReminders, isEmpty);
        // The type and the structural defaults are still the template's.
        expect(stored.type, template.type);
        expect(stored.interestPayoutMode, template.defaultPayoutMode);
        expect(
          stored.compoundingFrequency,
          template.defaultCompoundingFrequency,
        );
        expect(stored.incomeFrequency, template.defaultIncomeFrequency);
        expect(stored.riskLevel, template.defaultRiskLevel);
      });
    }

    // The headline promise of #994: no maturity date and no reminder unless the
    // user typed a tenure. A start date alone must not invent one (a "default
    // tenure" in the maturity calculation would).
    for (final template in InvestmentTemplates.all) {
      testWidgets('${template.id}: a start date without a typed tenure stores '
          'no maturity date and schedules no reminder', (tester) async {
        await pumpForm(tester, template: template);
        await _pickToday(tester);

        final stored = await saveNamed(tester);

        expect(stored.startDate, isNotNull, reason: 'the date was picked');
        expect(stored.expectedRate, isNull);
        expect(stored.tenureMonths, isNull);
        expect(stored.maturityDate, isNull);
        expect(stored.calculatedMaturityDate, isNull);
        expect(notifications.scheduledMaturityReminders, isEmpty);
      });
    }

    for (final template in const [
      InvestmentTemplates.fixedDeposit,
      InvestmentTemplates.recurringDeposit,
    ]) {
      testWidgets('${template.id}: a deposit without a rate has no estimated '
          'value and its XIRR and MOIC are "—" until a current value exists', (
        tester,
      ) async {
        await pumpForm(tester, template: template);
        final stored = await saveNamed(tester);

        final invested = CashFlowEntity(
          id: 'cf-1',
          investmentId: stored.id,
          type: CashFlowType.invest,
          amount: 100000.00,
          currency: 'INR',
          date: DateTime(2026, 1, 1),
          createdAt: DateTime(2026, 1, 1),
        );
        final asOf = DateTime(2026, 10, 11);

        // No estimate: a deposit whose interest accrues until maturity needs a
        // rate. (P2P and Bonds pay out periodically, so the calculator values
        // them at their outstanding principal whatever the rate: that is
        // existing behaviour and does not depend on the template.)
        expect(
          CurrentValueCalculator.valuationOf(stored, [invested], asOf: asOf),
          isNull,
        );
        final terminalValues = CurrentValueCalculator.terminalValues(
          investments: [stored],
          cashFlows: [invested],
          asOf: asOf,
        );
        final stats = FinancialCalculatorModule().calculateStats([
          invested,
        ], terminalValues: terminalValues);
        expect(stats.currentValue, isNull);
        expect(stats.xirr, isNull);
        expect(stats.xirrMethod, XirrMethod.undefined);
        // The screens show "—" for XIRR, MOIC and return % while this is set.
        expect(stats.missingValueCount, 1);
        expect(stats.totalInvested, 100000.00);
      });
    }

    testWidgets('a typed rate and tenure still set the maturity date, the '
        'reminder and an estimate', (tester) async {
      await pumpForm(tester, template: InvestmentTemplates.fixedDeposit);
      await _enter(tester, _rateLabel, '7.25');
      await _enter(tester, _tenureLabel, '12');

      // Pick today as the start date: the maturity date follows from it.
      await _pickToday(tester);

      final stored = await saveNamed(tester);
      final start = stored.startDate!;

      expect(stored.expectedRate, 7.25);
      expect(stored.tenureMonths, 12);
      final feb29 = start.month == 2 && start.day == 29;
      expect(
        stored.maturityDate,
        DateTime(start.year + 1, start.month, feb29 ? 28 : start.day),
      );
      expect(notifications.scheduledMaturityReminders, [stored.id]);

      // With a typed rate the deposit has an estimated value.
      final invested = CashFlowEntity(
        id: 'cf-1',
        investmentId: stored.id,
        type: CashFlowType.invest,
        amount: 100000.00,
        currency: 'INR',
        date: start,
        createdAt: start,
      );
      final valuation = CurrentValueCalculator.valuationOf(stored, [
        invested,
      ], asOf: start);
      expect(valuation, isNotNull);
      expect(valuation!.source, ValuationSource.accruedInterest);
      expect(valuation.rate, 7.25);
    });
  });

  group('template cards', () {
    testWidgets('say the typical rate the rate hint says', (tester) async {
      tester.view.physicalSize = const Size(3000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TemplateSelector(onTemplateSelected: (_) {})),
        ),
      );

      // Recurring Deposit (6.5) and Gold (2.5) are not rounded to 7 and 3:
      // the card and the hint spell the same number.
      expect(find.text('~6.5% p.a.'), findsOneWidget);
      expect(find.text('~2.5% p.a.'), findsOneWidget);
      expect(find.text('~7% p.a.'), findsOneWidget);
      expect(find.text('~3% p.a.'), findsOneWidget);
      for (final entry in _hintByTemplate.entries) {
        final rate = entry.value.substring('e.g. '.length);
        expect(find.text('~$rate% p.a.'), findsWidgets, reason: entry.key);
      }
    });
  });
}
