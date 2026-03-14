import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/investment_list_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

void main() {
  // Override providers to ensure clean state
  getOverrides() {
    return [
      // Provide empty list of investments
      allInvestmentsProvider.overrideWith((ref) => Stream.value([])),
      archivedInvestmentsProvider.overrideWith((ref) => Stream.value([])),
    ];
  }

  testWidgets(
    'InvestmentListScreen AppBar actions should have accessibility tooltips',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: getOverrides(),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: InvestmentListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify Sort Button Tooltip
      // Find the sort button (icon is sort_rounded)
      final sortFinder = find.byIcon(Icons.sort_rounded);
      expect(sortFinder, findsOneWidget);
      // Verify it has the expected tooltip
      expect(
        find.byTooltip('Sort investments'),
        findsOneWidget,
        reason: 'Sort button should have a tooltip',
      );

      // 2. Verify Filter Button Tooltip
      final filterFinder = find.byIcon(Icons.filter_list_rounded);
      expect(filterFinder, findsOneWidget);
      expect(
        find.byTooltip('Filter investments'),
        findsOneWidget,
        reason: 'Filter button should have a tooltip',
      );

      // 3. Verify Search Button Tooltip
      final searchFinder = find.byIcon(Icons.search_rounded);
      expect(searchFinder, findsOneWidget);
      expect(
        find.byTooltip('Search investments'),
        findsOneWidget,
        reason: 'Search button should have a tooltip',
      );

      // 4. Verify Selection Mode Button Tooltip
      final selectionFinder = find.byIcon(Icons.checklist_rounded);
      expect(selectionFinder, findsOneWidget);
      expect(
        find.byTooltip('Toggle selection mode'),
        findsOneWidget,
        reason: 'Selection mode button should have a tooltip',
      );
    },
  );

  testWidgets('Active filter chip close button should be accessible', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: getOverrides(),
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: InvestmentListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open filter sheet
    await tester.tap(find.byIcon(Icons.filter_list_rounded));
    await tester.pumpAndSettle();

    // Select a filter type (e.g., first one found in the sheet)
    final listTileFinder = find.byType(ListTile).first;
    await tester.tap(listTileFinder);
    await tester.pumpAndSettle();

    // Verify filter chip is shown
    expect(find.byType(Icon), findsWidgets);

    // Look for the Close button semantics
    final clearFilterSemantics = find.bySemanticsLabel(
      RegExp(r'Clear .* filter'),
    );

    expect(
      clearFilterSemantics,
      findsOneWidget,
      reason: 'Filter chip close button should have a semantic label',
    );

    // Also verify it's a button
    final semantics = tester.getSemantics(clearFilterSemantics);
    expect(
      semantics.getSemanticsData().flagsCollection.isButton,
      isTrue,
      reason: 'Filter chip close button should be identified as a button',
    );
  });

  testWidgets('Filter list items should have selected state semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: getOverrides(),
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: InvestmentListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open filter sheet
    await tester.tap(find.byIcon(Icons.filter_list_rounded));
    await tester.pumpAndSettle();

    // Find the first list tile
    final firstTileFinder = find.byType(ListTile).first;

    // Verify it is NOT selected initially
    final initialSemantics = tester.getSemantics(firstTileFinder);
    expect(
      initialSemantics.getSemanticsData().flagsCollection.isSelected,
      isNot(equals(Tristate.isTrue)),
      reason: 'Item should not be selected initially',
    );

    // Tap it to select
    await tester.tap(firstTileFinder);
    await tester.pumpAndSettle();

    // Re-open filter sheet
    await tester.tap(find.byIcon(Icons.filter_list_rounded));
    await tester.pumpAndSettle();

    // Find the same tile again
    final selectedTileFinder = find.byType(ListTile).first;

    // Verify it IS selected now
    final selectedSemantics = tester.getSemantics(selectedTileFinder);
    expect(
      selectedSemantics.getSemanticsData().flagsCollection.isSelected,
      equals(Tristate.isTrue),
      reason: 'Item should have isSelected=true in semantics when selected',
    );
  });
}
