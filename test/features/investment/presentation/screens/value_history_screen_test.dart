// The value history lists an investment's dated values newest first, shows the
// weight x price behind a gold value, hides amounts in privacy mode (also from
// screen readers), and lets the user change or remove a value (Undo included).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';
import 'package:inv_tracker/features/investment/domain/entities/unit_holding.dart';
import 'package:inv_tracker/features/investment/presentation/providers/valuation_notifier.dart';
import 'package:inv_tracker/features/investment/presentation/providers/valuation_providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/value_history_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../valuation/valuation_fixtures.dart';

class _Privacy extends PrivacyModeNotifier {
  _Privacy(this.value);
  final bool value;
  @override
  bool build() => value;
}

/// Records what the screen asks for instead of writing.
class _Recorder extends ValuationNotifier {
  final calls = <String>[];
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  @override
  Future<InvestmentValuationSnapshot> editValuation({
    required String snapshotId,
    double? amount,
    DateTime? date,
    ValuationKind? kind,
    UnitHolding? holding,
  }) async {
    calls.add('edit $snapshotId $amount ${holding?.quantity}');
    return testSnapshot(snapshotId, amount: amount ?? 0, date: DateTime(2026));
  }

  @override
  Future<void> clearValuation(String snapshotId) async =>
      calls.add('clear $snapshotId');

  @override
  Future<bool> undoClear() async {
    calls.add('undo');
    return true;
  }
}

const _holding = UnitHolding(
  quantity: 10,
  unit: QuantityUnit.gram,
  unitPrice: 6450,
);

final _newest = InvestmentValuationSnapshot(
  id: 's2',
  investmentId: 'gold',
  amount: 64500,
  holding: _holding,
  currency: 'INR',
  effectiveDate: DateTime(2026, 11, 12),
  kind: ValuationKind.marketValue,
  provenance: ValuationProvenance.manual,
  createdAt: DateTime.utc(2026, 11, 12),
);
final _oldest = testSnapshot(
  's1',
  investmentId: 'gold',
  amount: 60000,
  date: DateTime(2026, 11, 3),
  kind: ValuationKind.marketValue,
);

Future<_Recorder> _pump(
  WidgetTester tester, {
  List<InvestmentValuationSnapshot>? snapshots,
  bool privacy = false,
}) async {
  final recorder = _Recorder();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        investmentValuationSnapshotsProvider.overrideWith(
          (ref, id) => snapshots ?? [_newest, _oldest],
        ),
        valuationNotifierProvider.overrideWith(() => recorder),
        privacyModeProvider.overrideWith(() => _Privacy(privacy)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ValueHistoryScreen(investment: testInvestment('gold')),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return recorder;
}

void main() {
  testWidgets('lists the values newest first with the weight behind a value', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Value history'), findsOneWidget);
    expect(find.text('Nov 12, 2026'), findsOneWidget);
    expect(find.text('₹64,500.00'), findsOneWidget);
    expect(find.text('10 gram × ₹6,450.00'), findsOneWidget);
    expect(find.text('₹60,000.00'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Nov 12, 2026')).dy,
      lessThan(tester.getTopLeft(find.text('Nov 3, 2026')).dy),
    );
  });

  testWidgets('says so when there are no values', (tester) async {
    await _pump(tester, snapshots: const []);
    expect(find.textContaining('No values yet'), findsOneWidget);
    expect(find.text('Add a value'), findsOneWidget);
  });

  testWidgets('privacy mode hides amounts from the screen and screen readers', (
    tester,
  ) async {
    await _pump(tester, privacy: true);
    expect(find.text('₹64,500.00'), findsNothing);
    expect(find.text('10 gram × ₹6,450.00'), findsNothing);
    expect(find.bySemanticsLabel('Nov 12, 2026, value hidden'), findsOneWidget);
  });

  testWidgets('changing a value by weight saves the new weight and price', (
    tester,
  ) async {
    final recorder = await _pump(tester);
    await tester.tap(find.text('Nov 12, 2026'));
    await tester.pumpAndSettle();
    // The editor opens on the saved weight and price.
    expect(find.text('10'), findsOneWidget);
    expect(find.text('6450'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, '10'), '12');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    // 12 g x 6,450 = 77,400
    expect(recorder.calls, ['edit s2 77400.0 12.0']);
  });

  testWidgets('privacy mode opens the editor without the saved numbers', (
    tester,
  ) async {
    await _pump(tester, privacy: true);
    await tester.tap(find.text('Nov 12, 2026'));
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsOneWidget);
    for (final saved in ['10', '6450', '64500', '64,500', '6,450']) {
      expect(
        find.text(saved),
        findsNothing,
        reason: '$saved is a saved number',
      );
    }
    expect(find.textContaining('64,500'), findsNothing);
  });

  testWidgets('removing a value can be undone', (tester) async {
    final recorder = await _pump(tester);
    await tester.tap(find.text('Nov 3, 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(recorder.calls, ['clear s1']);
    expect(find.text('Value removed'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(recorder.calls, ['clear s1', 'undo']);
  });
}
