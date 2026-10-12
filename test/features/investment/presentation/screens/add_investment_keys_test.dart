// A40 (#783) PR-2: the integration robot finds the add investment form by key,
// not by position or by text (the new form's title and button both read "Add
// Investment", and its amount field is a second text field). The same keys
// must be on today's form and on the first investment flow form.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/gradient_button.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/add_investment_keys.dart';

import '../../../../helpers/inter_font.dart';
import 'add_investment_harness.dart';

void main() {
  setUpAll(loadInterFont);

  for (final flagOn in [false, true]) {
    group('flag ${flagOn ? 'on' : 'off'}', () {
      Future<FormHarness> open(WidgetTester tester) => pumpAddForm(
        tester,
        flagOn: flagOn,
        size: flagOn ? const Size(411, 842) : const Size(1080, 3200),
      );

      testWidgets('name, submit and all 14 type chips have their keys', (
        tester,
      ) async {
        await open(tester);

        expect(find.byKey(AddInvestmentKeys.name), findsOneWidget);
        expect(fieldIn(AddInvestmentKeys.name), findsOneWidget);
        expect(find.byKey(AddInvestmentKeys.submit), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(AddInvestmentKeys.submit),
            matching: find.byType(ElevatedButton),
          ),
          findsOneWidget,
        );
        expect(find.byType(GradientButton), findsOneWidget);
        for (final type in InvestmentType.values) {
          expect(
            find.byKey(AddInvestmentKeys.typeChip(type)),
            findsOneWidget,
            reason: type.name,
          );
        }
      });

      testWidgets('the notes field is reachable by key', (tester) async {
        await open(tester);
        if (flagOn) {
          expect(find.byKey(AddInvestmentKeys.notes), findsNothing);
          await tester.ensureVisible(find.byKey(AddInvestmentKeys.moreDetails));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(AddInvestmentKeys.moreDetails));
          await tester.pumpAndSettle();
        }

        expect(find.byKey(AddInvestmentKeys.notes), findsOneWidget);
        expect(fieldIn(AddInvestmentKeys.notes), findsOneWidget);
      });

      testWidgets('the keyed fields take text and the chip selects a type', (
        tester,
      ) async {
        final harness = await open(tester);
        final chip = find.byKey(
          AddInvestmentKeys.typeChip(InvestmentType.gold),
        );

        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        await tester.tap(chip);
        await tester.pumpAndSettle();
        await tester.enterText(nameField(), 'SGB 2026');
        final submit = find.byKey(AddInvestmentKeys.submit);
        await tester.ensureVisible(submit);
        await tester.pumpAndSettle();
        await tester.tap(submit);
        await tester.pumpAndSettle();

        expect(harness.adds.single.type, InvestmentType.gold);
        expect(harness.adds.single.name, 'SGB 2026');
      });
    });
  }

  testWidgets('the keys are unique', (tester) async {
    final keys = <Key>{
      AddInvestmentKeys.name,
      AddInvestmentKeys.amount,
      AddInvestmentKeys.notes,
      AddInvestmentKeys.moreDetails,
      AddInvestmentKeys.submit,
      for (final type in InvestmentType.values)
        AddInvestmentKeys.typeChip(type),
    };

    expect(keys, hasLength(5 + InvestmentType.values.length));
  });
}
