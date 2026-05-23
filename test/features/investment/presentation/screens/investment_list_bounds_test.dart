import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inv_tracker/features/investment/presentation/screens/investment_list_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

void main() {
  testWidgets(
      'InvestmentListScreen should safely handle out of bounds indices without throwing exceptions',
      (tester) async {
    final investment = InvestmentEntity(
      id: 'inv-1',
      name: 'Test Investment',
      type: InvestmentType.stocks,
      status: InvestmentStatus.open,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isArchived: false,
    );

    SharedPreferences.setMockInitialValues({});
    final sharedPrefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPrefs),
          allInvestmentsProvider.overrideWith((ref) => Stream.value([investment])),
          archivedInvestmentsProvider.overrideWith((ref) => Stream.value([])),
          filteredInvestmentsProvider.overrideWith((ref) => AsyncValue.data([investment])),
          investmentCountsProvider.overrideWithValue((
            all: 1,
            open: 1,
            closed: 0,
            archived: 0,
          )),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: InvestmentListScreen(),
        ),
      ),
    );

    // Initial pump
    await tester.pumpAndSettle();

    // Verify it renders correctly initially
    expect(find.text('Test Investment'), findsOneWidget);

    // We update the data provider to yield an empty list, but the SliverList
    // childCount might still try to build child at index 0 before it fully rebuilds.
    // Rebuilding with an empty list should not crash with IndexOutOfBoundsException.

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPrefs),
          allInvestmentsProvider.overrideWith((ref) => Stream.value([])),
          archivedInvestmentsProvider.overrideWith((ref) => Stream.value([])),
          filteredInvestmentsProvider.overrideWith((ref) => const AsyncValue.data([])),
          investmentCountsProvider.overrideWithValue((
            all: 1, // keeping this > 0 so it doesn't show empty state immediately
            open: 1,
            closed: 0,
            archived: 0,
          )),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: InvestmentListScreen(),
        ),
      ),
    );

    // If there is no crash during the pump sequence, the defensive check works.
    await tester.pumpAndSettle();

    // Reached this point means no IndexOutOfBoundsException was thrown.
    expect(tester.takeException(), isNull);
  });
}
