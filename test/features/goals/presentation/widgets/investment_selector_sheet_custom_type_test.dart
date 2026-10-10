// #936: in the goal picker an Other investment with a custom label shows it
// under its name instead of "Other", while the feature flag is on. Legacy
// Other investments, other types and the flag-off case all keep the built-in
// type name. The type picker (by type) is untouched.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/investment_selector_sheet.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

InvestmentEntity _inv(
  String id,
  String name, {
  InvestmentType type = InvestmentType.other,
  String? label,
}) => InvestmentEntity(
  id: id,
  name: name,
  type: type,
  status: InvestmentStatus.open,
  createdAt: DateTime(2025, 1, 1),
  updatedAt: DateTime(2025, 1, 1),
  currency: 'INR',
  customTypeLabel: label,
);

Future<void> _pump(
  WidgetTester tester, {
  required bool flag,
  GoalTrackingMode mode = GoalTrackingMode.selected,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        isCustomInvestmentTypesEnabledProvider.overrideWithValue(flag),
        allInvestmentsProvider.overrideWith(
          (ref) => Stream.value([
            _inv('a', 'Stamp album', label: 'Stamps'),
            _inv('b', 'Loose change'),
            _inv('c', 'Bond', type: InvestmentType.bonds),
          ]),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: InvestmentSelectorSheet(
            trackingMode: mode,
            selectedInvestmentIds: const [],
            selectedTypes: const [],
            onInvestmentsSelected: (_) {},
            onTypesSelected: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('flag on: a labelled Other investment shows its label', (
    tester,
  ) async {
    await _pump(tester, flag: true);

    expect(find.text('Stamps'), findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(CheckboxListTile, 'Stamp album'),
        matching: find.text('Other'),
      ),
      findsNothing,
    );
    // No label, or another type: the built-in name.
    expect(
      find.descendant(
        of: find.widgetWithText(CheckboxListTile, 'Loose change'),
        matching: find.text('Other'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(CheckboxListTile, 'Bond'),
        matching: find.text('Bonds/Debentures'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('flag off: nothing changes, it still says Other', (tester) async {
    await _pump(tester, flag: false);

    expect(find.text('Stamps'), findsNothing);
    expect(
      find.descendant(
        of: find.widgetWithText(CheckboxListTile, 'Stamp album'),
        matching: find.text('Other'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('picking by type still lists the built-in types only', (
    tester,
  ) async {
    await _pump(tester, flag: true, mode: GoalTrackingMode.byType);

    expect(find.text('Other'), findsOneWidget);
    expect(find.text('Stamps'), findsNothing);
  });
}
