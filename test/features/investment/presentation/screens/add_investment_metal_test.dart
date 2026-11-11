// The Metal choice of the add and edit investment form (#946): shown for
// Precious metals only, Gold by default, sent to the notifier as chosen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/app_text_field.dart';
import 'package:inv_tracker/core/widgets/gradient_button.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/metal.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/add_investment_keys.dart';

import 'add_investment_harness.dart';

const _wide = Size(411, 1400);

Future<void> _name(WidgetTester tester, String name) => tester.enterText(
  find.descendant(
    of: find.widgetWithText(AppTextField, 'Investment Name'),
    matching: find.byType(TextFormField),
  ),
  name,
);

Future<void> _pickType(WidgetTester tester, InvestmentType type) async {
  final chip = find.byKey(AddInvestmentKeys.typeChip(type));
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester, String label) async {
  final submit = find.widgetWithText(GradientButton, label);
  await tester.ensureVisible(submit);
  await tester.tap(submit);
  await tester.pumpAndSettle();
}

InvestmentEntity _coins(Metal? metal) => InvestmentEntity(
  id: 'inv-coins',
  name: 'Coins',
  type: InvestmentType.gold,
  status: InvestmentStatus.open,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  currency: 'INR',
  metal: metal,
);

void main() {
  group('Metal choice in the investment form', () {
    testWidgets('the type is named Precious metals', (tester) async {
      await pumpAddForm(tester, size: _wide);
      expect(find.text('Precious metals'), findsOneWidget);
      expect(find.text('Gold/Commodities'), findsNothing);
    });

    testWidgets('other types show no Metal choice and send none', (
      tester,
    ) async {
      final harness = await pumpAddForm(tester, size: _wide);
      expect(find.text('Metal'), findsNothing);
      await _name(tester, 'Grip FD');
      await _submit(tester, 'Add Investment');
      expect(harness.adds.single.metal, isNull);
    });

    testWidgets('Precious metals offers Gold and Silver, Gold chosen', (
      tester,
    ) async {
      final harness = await pumpAddForm(tester, size: _wide);
      await _pickType(tester, InvestmentType.gold);
      expect(find.text('Metal'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Gold'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Silver'), findsOneWidget);
      await _name(tester, 'Coins');
      await _submit(tester, 'Add Investment');
      expect(harness.adds.single.metal, Metal.gold);
    });

    testWidgets('choosing Silver sends silver', (tester) async {
      final harness = await pumpAddForm(tester, size: _wide);
      await _pickType(tester, InvestmentType.gold);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Silver'));
      await tester.pumpAndSettle();
      await _name(tester, 'Bars');
      await _submit(tester, 'Add Investment');
      expect(harness.adds.single.metal, Metal.silver);
    });

    testWidgets('editing keeps the chosen metal', (tester) async {
      final harness = await pumpAddForm(
        tester,
        size: _wide,
        edit: _coins(Metal.silver),
      );
      final silver = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Silver'),
      );
      expect(silver.selected, isTrue);
      await _submit(tester, 'Save Changes');
      expect(harness.updates.single['metal'], Metal.silver);
    });

    testWidgets('a record without a metal is edited as Gold', (tester) async {
      final harness = await pumpAddForm(
        tester,
        size: _wide,
        edit: _coins(null),
      );
      final gold = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Gold'),
      );
      expect(gold.selected, isTrue);
      await _submit(tester, 'Save Changes');
      expect(harness.updates.single['metal'], Metal.gold);
    });
  });
}
