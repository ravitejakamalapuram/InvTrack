// "Gold today" on a metal investment's page: the rate for the investment's
// currency, labelled by where it comes from, with a confirmed one-tap way to
// use it as the current value.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/metal.dart';
import 'package:inv_tracker/features/investment/domain/entities/unit_holding.dart';
import 'package:inv_tracker/features/investment/domain/services/metal_rate_quoter.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_notifier.dart';
import 'package:inv_tracker/features/investment/presentation/providers/metal_rate_providers.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/metal_rate_card.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class _Saves extends InvestmentNotifier {
  _Saves(this.calls, {this.fail = false});
  final List<({String id, double value, DateTime date, UnitHolding? holding})>
  calls;
  final bool fail;

  @override
  Future<void> setCurrentValue({
    required String id,
    required double value,
    required DateTime date,
    UnitHolding? holding,
  }) async {
    if (fail) throw Exception('boom');
    calls.add((id: id, value: value, date: date, holding: holding));
  }
}

class _Privacy extends PrivacyModeNotifier {
  _Privacy(this.on);
  final bool on;
  @override
  bool build() => on;
}

InvestmentEntity _inv({
  String currency = 'INR',
  InvestmentStatus status = InvestmentStatus.open,
  bool archived = false,
  Metal metal = Metal.gold,
}) => InvestmentEntity(
  id: 'g1',
  name: 'Coins',
  type: InvestmentType.gold,
  status: status,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  currency: currency,
  isArchived: archived,
  metal: metal,
);

MetalRateQuote _india = MetalRateQuote(
  pricePerGram: 12633.66,
  kind: MetalRateKind.indiaSelling,
  asOf: DateTime.utc(2026, 11, 23, 4),
);

Future<List<({String id, double value, DateTime date, UnitHolding? holding})>>
_pump(
  WidgetTester tester, {
  required InvestmentEntity investment,
  MetalRateQuote? quote,
  double grams = 12.5,
  bool privacy = false,
  bool failSave = false,
}) async {
  final calls =
      <({String id, double value, DateTime date, UnitHolding? holding})>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        metalRateQuoteProvider.overrideWith((ref, key) async => quote),
        investmentNotifierProvider.overrideWith(
          () => _Saves(calls, fail: failSave),
        ),
        privacyModeProvider.overrideWith(() => _Privacy(privacy)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MetalRateCard(investment: investment, grams: grams),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return calls;
}

void main() {
  testWidgets('shows the India selling rate with its label', (tester) async {
    await _pump(tester, investment: _inv(), quote: _india);
    expect(find.text('Gold today: ₹12,633.66 per gram'), findsOneWidget);
    expect(find.text('Selling rate in India · 23 Nov 2026'), findsOneWidget);
  });

  testWidgets('labels an international rate as such', (tester) async {
    await _pump(
      tester,
      investment: _inv(currency: 'USD', metal: Metal.silver),
      quote: MetalRateQuote(
        pricePerGram: 1.35,
        kind: MetalRateKind.international,
        asOf: DateTime.utc(2026, 11, 23, 4),
      ),
    );
    expect(find.text('Silver today: \$1.35 per gram'), findsOneWidget);
    expect(find.text('International rate · 23 Nov 2026'), findsOneWidget);
  });

  testWidgets('says so when the rate is not from today', (tester) async {
    final old = DateTime.now().subtract(const Duration(days: 2));
    await _pump(
      tester,
      investment: _inv(),
      quote: MetalRateQuote(
        pricePerGram: 12633.66,
        kind: MetalRateKind.indiaSelling,
        asOf: old,
      ),
    );
    expect(find.text('Not updated today'), findsOneWidget);
  });

  testWidgets('says nothing extra when the rate is from today', (tester) async {
    await _pump(
      tester,
      investment: _inv(),
      quote: MetalRateQuote(
        pricePerGram: 12633.66,
        kind: MetalRateKind.indiaSelling,
        asOf: DateTime.now(),
      ),
    );
    expect(find.text('Not updated today'), findsNothing);
  });

  testWidgets(
    'a rupee investment on the international rate is told shop prices are higher',
    (tester) async {
      await _pump(
        tester,
        investment: _inv(),
        quote: MetalRateQuote(
          pricePerGram: 10768.28,
          kind: MetalRateKind.international,
          asOf: DateTime.utc(2026, 11, 23, 4),
        ),
      );
      expect(find.text('International rate · 23 Nov 2026'), findsOneWidget);
      expect(
        find.text('Shop prices in India are usually higher.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('other currencies get no India note', (tester) async {
    await _pump(
      tester,
      investment: _inv(currency: 'USD'),
      quote: MetalRateQuote(
        pricePerGram: 116.1,
        kind: MetalRateKind.international,
        asOf: DateTime.utc(2026, 11, 23, 4),
      ),
    );
    expect(find.text('Shop prices in India are usually higher.'), findsNothing);
  });

  testWidgets('shows nothing when there is no rate', (tester) async {
    await _pump(tester, investment: _inv(), quote: null);
    expect(find.textContaining('today'), findsNothing);
    expect(find.text('Use as current value'), findsNothing);
  });

  testWidgets('offers no button on a closed or archived investment', (
    tester,
  ) async {
    await _pump(
      tester,
      investment: _inv(status: InvestmentStatus.closed),
      quote: _india,
    );
    expect(find.text('Gold today: ₹12,633.66 per gram'), findsOneWidget);
    expect(find.text('Use as current value'), findsNothing);

    await _pump(tester, investment: _inv(archived: true), quote: _india);
    expect(find.text('Use as current value'), findsNothing);
  });

  testWidgets(
    'saves weight x rate as the current value only after confirming',
    (tester) async {
      final calls = await _pump(tester, investment: _inv(), quote: _india);
      await tester.tap(find.text('Use as current value'));
      await tester.pumpAndSettle();
      expect(
        calls,
        isEmpty,
        reason: 'nothing is saved before the user confirms',
      );
      expect(find.text('Set current value?'), findsOneWidget);
      expect(
        find.text('12.5 g × ₹12,633.66 per gram = ₹1,57,920.75'),
        findsOneWidget,
      );

      await tester.tap(find.text('Set value'));
      await tester.pumpAndSettle();
      expect(calls, hasLength(1));
      expect(calls.single.id, 'g1');
      expect(calls.single.value, 157920.75);
      final today = DateTime.now();
      expect(calls.single.date.year, today.year);
      expect(calls.single.date.month, today.month);
      expect(calls.single.date.day, today.day);
      expect(
        calls.single.holding,
        const UnitHolding(
          quantity: 12.5,
          unit: QuantityUnit.gram,
          unitPrice: 12633.66,
        ),
      );
      expect(find.text('Current value updated'), findsOneWidget);
    },
  );

  testWidgets('cancel saves nothing', (tester) async {
    final calls = await _pump(tester, investment: _inv(), quote: _india);
    await tester.tap(find.text('Use as current value'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
  });

  testWidgets('a failed save says so', (tester) async {
    await _pump(tester, investment: _inv(), quote: _india, failSave: true);
    await tester.tap(find.text('Use as current value'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set value'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not save the current value. Try again.'),
      findsOneWidget,
    );
  });

  testWidgets('privacy mode hides the weight and the total, not the rate', (
    tester,
  ) async {
    await _pump(tester, investment: _inv(), quote: _india, privacy: true);
    expect(find.text('Gold today: ₹12,633.66 per gram'), findsOneWidget);
    await tester.tap(find.text('Use as current value'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1,57,920'), findsNothing);
    expect(find.textContaining('12.5 g'), findsNothing);
  });

  testWidgets('announces itself to screen readers as one line', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, investment: _inv(), quote: _india);
    expect(
      find.bySemanticsLabel(RegExp('Gold today: ₹12,633.66 per gram')),
      findsWidgets,
    );
    handle.dispose();
  });
}
