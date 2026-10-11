// A40 (#783) PR-2: with the first investment flow flag off the add form is
// exactly today's form. CHARACTERISATION: these pass on main before the new
// form exists and must keep passing. They are the guard that the flag-on code
// path is not reachable by default, next to the unchanged add_investment_screen
// tests.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/app_text_field.dart';
import 'package:inv_tracker/core/widgets/gradient_button.dart';
import 'package:inv_tracker/core/widgets/type_selector.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';

import 'add_investment_harness.dart';

// The legacy form overflows the test font at phone width; the old tests use
// this size too.
const _wide = Size(1080, 3200);

void main() {
  group('flag off', () {
    testWidgets('shows today\'s form: Quick Start, type grid, optional date', (
      tester,
    ) async {
      await pumpAddForm(tester, size: _wide);

      expect(find.text('⚡ Quick Start'), findsOneWidget);
      expect(find.byType(TypeSelector<InvestmentType>), findsOneWidget);
      final selector = tester.widget<TypeSelector<InvestmentType>>(
        find.byType(TypeSelector<InvestmentType>),
      );
      expect(selector.gridLayout, isTrue);
      expect(find.text('Start Date (Optional)'), findsOneWidget);
      expect(find.text('When did you invest?'), findsOneWidget);
      expect(find.widgetWithText(GradientButton, 'Add Investment'), findsOne);
      expect(find.text('Amount invested in INR'), findsNothing);
    });

    testWidgets('saves with no id, no amount and no write callback', (
      tester,
    ) async {
      final harness = await pumpAddForm(tester, size: _wide);

      await tester.enterText(
        find.descendant(
          of: find.widgetWithText(AppTextField, 'Investment Name'),
          matching: find.byType(TextFormField),
        ),
        'Grip FD',
      );
      final submit = find.widgetWithText(GradientButton, 'Add Investment');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(harness.adds, hasLength(1));
      final call = harness.adds.single;
      expect(call.name, 'Grip FD');
      expect(call.id, isNull);
      expect(call.initialAmount, isNull);
      expect(call.startDate, isNull);
      expect(call.reportsWriteResult, isFalse);
      expect(call.currency, 'INR');
      expect(find.text('Opener'), findsOneWidget, reason: 'popped back');
      expect(harness.detailVisits, isEmpty);
    });

    testWidgets('a failed save shows today\'s message and keeps the form', (
      tester,
    ) async {
      final harness = await pumpAddForm(tester, size: _wide);
      harness.notifier.failures = 1;

      await tester.enterText(
        find.descendant(
          of: find.widgetWithText(AppTextField, 'Investment Name'),
          matching: find.byType(TextFormField),
        ),
        'Grip FD',
      );
      final submit = find.widgetWithText(GradientButton, 'Add Investment');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(find.text('Failed to create investment'), findsOneWidget);
      expect(find.text('Grip FD'), findsOneWidget);
      expect(find.text('Opener'), findsNothing);
    });
  });
}
