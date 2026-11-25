// The optional Weight row of the add investment form, for Precious metals
// only: the weight is sent with the amount paid so both land on the first
// cash flow. A weight with no amount is an error, never dropped silently.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/app_text_field.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/unit_holding.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/add_investment_keys.dart';

import '../../../../helpers/inter_font.dart';
import 'add_investment_harness.dart';

final _now = DateTime(2026, 10, 11, 14, 30);

Finder _weightField() => find.descendant(
  of: find.byWidgetPredicate((w) => w is AppTextField && w.label == 'Weight'),
  matching: find.byType(EditableText),
);

Future<void> _tapChip(WidgetTester tester, InvestmentType type) async {
  final chip = find.byKey(AddInvestmentKeys.typeChip(type));
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester) async {
  final submit = find.byKey(AddInvestmentKeys.submit);
  await tester.ensureVisible(submit);
  await tester.tap(submit);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadInterFont);

  testWidgets('Precious metals shows an optional Weight row with a unit', (
    tester,
  ) async {
    await pumpAddForm(tester, now: _now);
    expect(_weightField(), findsNothing);

    await _tapChip(tester, InvestmentType.gold);

    expect(_weightField(), findsOneWidget);
    expect(find.text('Unit'), findsOneWidget);
  });

  testWidgets('another type shows no Weight row', (tester) async {
    await pumpAddForm(tester, now: _now);
    await _tapChip(tester, InvestmentType.fixedDeposit);

    expect(_weightField(), findsNothing);
  });

  testWidgets('the weight is sent with the amount, in grams by default', (
    tester,
  ) async {
    final harness = await pumpAddForm(tester, now: _now);
    await _tapChip(tester, InvestmentType.gold);
    await tester.enterText(nameField(), 'Coins');
    await tester.enterText(fieldIn(AddInvestmentKeys.amount), '300000');
    await tester.enterText(_weightField(), '50');
    await tester.pump();

    expect(find.text('About ₹6,000.00 per gram'), findsOneWidget);

    await _submit(tester);

    final call = harness.adds.single;
    expect(call.initialAmount, 300000);
    expect(call.initialQuantity, 50);
    expect(call.initialQuantityUnit, QuantityUnit.gram);
  });

  testWidgets('no weight typed sends none', (tester) async {
    final harness = await pumpAddForm(tester, now: _now);
    await _tapChip(tester, InvestmentType.gold);
    await tester.enterText(nameField(), 'Coins');
    await tester.enterText(fieldIn(AddInvestmentKeys.amount), '300000');
    await tester.pump();

    await _submit(tester);

    final call = harness.adds.single;
    expect(call.initialAmount, 300000);
    expect(call.initialQuantity, isNull);
    expect(call.initialQuantityUnit, isNull);
  });

  testWidgets('a weight with no amount is an error and nothing is sent', (
    tester,
  ) async {
    final harness = await pumpAddForm(tester, now: _now);
    await _tapChip(tester, InvestmentType.gold);
    await tester.enterText(nameField(), 'Coins');
    await tester.enterText(_weightField(), '50');
    await tester.pump();

    await _submit(tester);

    expect(
      find.text('Add the amount you paid to save the weight'),
      findsOneWidget,
    );
    expect(harness.adds, isEmpty);
  });

  testWidgets('a weight typed on Gold is not sent after switching type', (
    tester,
  ) async {
    final harness = await pumpAddForm(tester, now: _now);
    await _tapChip(tester, InvestmentType.gold);
    await tester.enterText(_weightField(), '50');
    await _tapChip(tester, InvestmentType.fixedDeposit);
    await tester.enterText(nameField(), 'FD');
    await tester.enterText(fieldIn(AddInvestmentKeys.amount), '300000');
    await tester.pump();

    await _submit(tester);

    final call = harness.adds.single;
    expect(call.initialQuantity, isNull);
    expect(call.initialQuantityUnit, isNull);
  });
}
