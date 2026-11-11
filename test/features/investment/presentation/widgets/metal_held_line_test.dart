// "Gold held" (#946): purchases minus sales, in grams; hidden in privacy mode.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/unit_holding.dart';
import 'package:inv_tracker/features/investment/domain/services/metal_holding.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/metal_held_line.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

CashFlowEntity _f(CashFlowType t, double? q, [QuantityUnit? u]) =>
    CashFlowEntity(
      id: '${t.name}$q$u',
      investmentId: 'g',
      date: DateTime(2026, 11, 1),
      type: t,
      amount: 1000,
      createdAt: DateTime(2026, 11, 1),
      currency: 'INR',
      quantity: q,
      quantityUnit: q == null ? null : (u ?? QuantityUnit.gram),
    );

class _Privacy extends PrivacyModeNotifier {
  _Privacy(this.on);
  final bool on;
  @override
  bool build() => on;
}

void main() {
  group('heldGrams', () {
    test('purchases minus sales, units converted', () {
      final grams = heldGrams([
        _f(CashFlowType.invest, 10),
        _f(CashFlowType.invest, 1, QuantityUnit.sovereign),
        _f(CashFlowType.returnFlow, 3),
      ]);
      expect(grams, closeTo(15, 1e-9));
    });

    test('null when no flow has a weight', () {
      expect(heldGrams([_f(CashFlowType.invest, null)]), isNull);
      expect(heldGrams([]), isNull);
    });

    test('flows without a weight are ignored, income and fees too', () {
      final grams = heldGrams([
        _f(CashFlowType.invest, 5),
        _f(CashFlowType.invest, null),
        _f(CashFlowType.income, 2),
        _f(CashFlowType.fee, 2),
      ]);
      expect(grams, closeTo(5, 1e-9));
    });

    test('never below zero', () {
      expect(
        heldGrams([_f(CashFlowType.invest, 1), _f(CashFlowType.returnFlow, 3)]),
        0,
      );
    });
  });

  group('MetalHeldLine', () {
    Future<void> pump(WidgetTester t, double grams, {bool privacy = false}) =>
        t.pumpWidget(
          ProviderScope(
            overrides: [privacyModeProvider.overrideWith(() => _Privacy(privacy))],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: MetalHeldLine(grams: grams)),
            ),
          ),
        );

    testWidgets('says how much is held', (t) async {
      await pump(t, 12.5);
      expect(find.text('Gold held: 12.5 g'), findsOneWidget);
    });

    testWidgets('whole grams have no decimals', (t) async {
      await pump(t, 10);
      expect(find.text('Gold held: 10 g'), findsOneWidget);
    });

    testWidgets('privacy mode hides the weight, also from semantics', (
      t,
    ) async {
      await pump(t, 12.5, privacy: true);
      expect(find.textContaining('12.5'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('12.5')), findsNothing);
    });
  });
}
