// A cash flow row paints money going out in the red and money coming back in
// the green. Its type label sits on a tint of that colour and its amount on
// the card, so each is pumped in both themes and measured on the ground it
// sits on. Colour is not the only carrier: the amount starts with - or +, the
// label names the type and the icon points up for out and down for in.
//
// The ids in the test names are rows of test/core/theme/contrast_pairs.dart;
// the guard finds them here.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/cash_flow_card_widget.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/contrast.dart';

// Demo figures only.
CashFlowEntity _flow(CashFlowType type) => CashFlowEntity(
  id: 'flow',
  investmentId: 'inv',
  type: type,
  amount: 1000,
  currency: 'INR',
  date: DateTime(2026, 9, 1),
  createdAt: DateTime(2026, 9, 1),
);

Future<void> _pump(
  WidgetTester tester,
  CashFlowEntity flow, {
  required bool isDark,
}) async {
  SharedPreferences.setMockInitialValues({'privacy_mode_enabled': false});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currencyCodeProvider.overrideWith((ref) => 'INR'),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp(
        theme: ThemeData(
          brightness: isDark ? Brightness.dark : Brightness.light,
        ),
        home: Scaffold(
          body: CashFlowCardWidget(
            cashFlow: flow,
            isDark: isDark,
            currencyFormat: NumberFormat.currency(symbol: '₹'),
            onTap: () {},
            onEdit: () {},
            onConfirmDelete: () async => false,
            onDeleted: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The tint behind [text]: the fill of the nearest Container around it that
/// has one, over [ground], the way it is painted.
Color _tintBehind(WidgetTester tester, Finder text, Color ground) {
  for (final element
      in find.ancestor(of: text, matching: find.byType(Container)).evaluate()) {
    final decoration = (element.widget as Container).decoration;
    if (decoration is BoxDecoration && decoration.color != null) {
      return composeOver(decoration.color!, ground);
    }
  }
  throw StateError('No filled Container around the text.');
}

void main() {
  // Type, sign, icon, light colour, dark colour, light tint source.
  final rows = [
    (
      CashFlowType.invest,
      '-',
      Icons.arrow_upward_rounded,
      AppColors.errorLight,
      AppColors.errorDark,
      AppColors.dangerTintLight,
      'cash-flow-row-out-light@tint10',
    ),
    (
      CashFlowType.income,
      '+',
      Icons.arrow_downward_rounded,
      AppColors.successLight,
      AppColors.successDark,
      AppColors.successTintLight,
      'cash-flow-row-in-light@tint10',
    ),
  ];

  for (final (type, sign, icon, inLight, inDark, tintSource, id) in rows) {
    for (final isDark in [false, true]) {
      final theme = isDark ? 'dark' : 'light';
      final card = isDark ? AppColors.cardDark : AppColors.cardLight;
      final text = isDark ? inDark : inLight;

      testWidgets('${type.name} in $theme: label and amount read on their '
          'grounds${isDark ? '' : ' ($id)'}', (tester) async {
        final flow = _flow(type);
        await _pump(tester, flow, isDark: isDark);

        final label = find.text(type.displayName);
        expect(label, findsOneWidget);
        expect(tester.widget<Text>(label).style!.color, text);
        final tint = _tintBehind(tester, label, card);
        // Light: tinted with the old, brighter hue, the text on it deeper.
        expect(
          tint,
          composeOver(
            (isDark ? inDark : tintSource).withValues(alpha: 0.1),
            card,
          ),
        );
        expect(
          contrastRatio(text, tint),
          greaterThanOrEqualTo(kMinText),
          reason: isDark ? '${type.name}-dark@tint10' : id,
        );

        final amount = find.textContaining(sign);
        expect(amount, findsOneWidget, reason: 'the amount starts with $sign');
        expect(tester.widget<Text>(amount).data, startsWith(sign));
        expect(tester.widget<Text>(amount).style!.color, text);
        expect(
          contrastRatio(text, card),
          greaterThanOrEqualTo(kMinText),
          reason: '${type.name} amount on the card',
        );
        expect(find.byIcon(icon), findsOneWidget);
      });
    }
  }
}
