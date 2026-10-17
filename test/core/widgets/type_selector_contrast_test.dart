// The selected chip of a TypeSelector paints its label and icon on the fill of
// the item's own colour. Whatever colour a screen hands in, the label must
// reach 4.5:1 and the icon 3:1 on it: white on a bright fill was 1.4 to 3.7.
//
// Every list that reaches a TypeSelector is pumped here with the screen's own
// colours: the investment, goal and document types, and the cash-flow types of
// the add-transaction screen in both themes. Each chip is selected in turn and
// the colours are read from the widgets, not from a table.
//
// The pair id below is a row of test/core/theme/contrast_pairs.dart; the guard
// finds it here.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/widgets/type_selector.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/ui_extensions/goal_type_ui.dart';
import 'package:inv_tracker/features/investment/domain/entities/document_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/presentation/ui_extensions/investment_ui.dart';

import '../../helpers/contrast.dart';

const _pair = 'type-selector-label@fill';

/// What the selected chip painted: its fill, its label, its icon and the
/// icon's own ground (the translucent veil composed over the fill).
typedef _Chip = ({Color fill, Color label, Color icon, Color iconGround});

Future<_Chip> _selected<T>(
  WidgetTester tester, {
  required Brightness brightness,
  required List<T> values,
  required T selected,
  required Color Function(T) color,
  required String Function(T) name,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: SingleChildScrollView(
          child: TypeSelector<T>(
            values: values,
            selectedValue: selected,
            onSelected: (_) {},
            colorBuilder: color,
            iconBuilder: (_) => Icons.circle,
            labelBuilder: name,
            itemKeyBuilder: (item) => ValueKey('chip-$item'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final chip = find.byKey(ValueKey('chip-$selected'));
  expect(chip, findsOneWidget);
  final fill =
      ((tester
                  .widgetList<Container>(
                    find.descendant(of: chip, matching: find.byType(Container)),
                  )
                  .first
                  .decoration)
              as BoxDecoration)
          .color!;
  final label = tester
      .widget<Text>(find.descendant(of: chip, matching: find.byType(Text)))
      .style!
      .color!;
  final iconFinder = find.descendant(of: chip, matching: find.byType(Icon));
  final icon = tester.widget<Icon>(iconFinder).color!;
  final veil =
      ((tester
                  .widget<Container>(
                    find
                        .ancestor(
                          of: iconFinder,
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration)
              as BoxDecoration)
          .color!;
  return (
    fill: fill,
    label: label,
    icon: icon,
    iconGround: composeOver(veil, fill),
  );
}

void main() {
  void checkAll<T>(
    String group, {
    required List<T> values,
    required Color Function(T, Brightness) color,
    required String Function(T) name,
  }) {
    for (final brightness in Brightness.values) {
      testWidgets(
        '$group: the selected label and icon are readable in ${brightness.name}',
        (tester) async {
          for (final value in values) {
            final chip = await _selected<T>(
              tester,
              brightness: brightness,
              values: values,
              selected: value,
              color: (v) => color(v, brightness),
              name: name,
            );
            final label = contrastRatio(chip.label, chip.fill);
            final icon = contrastRatio(chip.icon, chip.iconGround);
            expect(
              label,
              greaterThanOrEqualTo(kMinText),
              reason:
                  '$_pair: ${name(value)} label ${label.toStringAsFixed(2)}:1',
            );
            expect(
              icon,
              greaterThanOrEqualTo(kMinGraphic),
              reason:
                  '$_pair: ${name(value)} icon ${icon.toStringAsFixed(2)}:1',
            );
          }
        },
      );
    }
  }

  checkAll<InvestmentType>(
    'investment types',
    values: InvestmentType.values,
    color: (t, _) => t.color,
    name: (t) => t.displayName,
  );
  checkAll<GoalType>(
    'goal types',
    values: GoalType.values,
    color: (t, _) => t.color,
    name: (t) => t.name,
  );
  checkAll<DocumentType>(
    'document types',
    values: DocumentType.values,
    color: (t, _) => t.color,
    name: (t) => t.name,
  );
  // The add-transaction screen colours an outflow with the error colour and
  // an inflow with the success colour of the theme it is in.
  checkAll<CashFlowType>(
    'cash-flow types',
    values: CashFlowType.values,
    color: (t, brightness) {
      final dark = brightness == Brightness.dark;
      return t.isOutflow
          ? (dark ? AppColors.errorDark : AppColors.errorLight)
          : (dark ? AppColors.successDark : AppColors.successLight);
    },
    name: (t) => t.name,
  );

  testWidgets('the chip still carries its name and which one is selected', (
    tester,
  ) async {
    // Colour is never the only carrier: the name is text and the selection is
    // a semantic state.
    final handle = tester.ensureSemantics();
    await _selected<InvestmentType>(
      tester,
      brightness: Brightness.light,
      values: InvestmentType.values,
      selected: InvestmentType.gold,
      color: (t) => t.color,
      name: (t) => t.displayName,
    );
    expect(find.text(InvestmentType.gold.displayName), findsOneWidget);
    expect(
      tester.getSemantics(
        find.bySemanticsLabel(InvestmentType.gold.displayName),
      ),
      matchesSemantics(
        label: InvestmentType.gold.displayName,
        isButton: true,
        isSelected: true,
        hasTapAction: true,
        hasSelectedState: true,
      ),
    );
    handle.dispose();
  });

  testWidgets(
    'an unselected chip draws its edge in fieldBorder, 3:1 on the page',
    (tester) async {
      for (final dark in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            home: Scaffold(
              body: TypeSelector<String>(
                values: const ['a', 'b'],
                selectedValue: 'a',
                onSelected: (_) {},
                colorBuilder: (_) => Colors.indigo,
                iconBuilder: (_) => Icons.circle,
                labelBuilder: (v) => v,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final token = dark
            ? AppColors.fieldBorderDark
            : AppColors.fieldBorderLight;
        final edges = tester
            .widgetList<Container>(find.byType(Container))
            .map((c) => c.decoration)
            .whereType<BoxDecoration>()
            .map((d) => d.border)
            .whereType<Border>()
            .map((b) => b.top.color);
        expect(edges, contains(token));
        expect(
          contrastRatio(
            token,
            dark ? AppColors.backgroundDark : AppColors.backgroundLight,
          ),
          greaterThanOrEqualTo(kMinGraphic),
        );
      }
    },
  );
}
