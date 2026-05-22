import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/investment_list_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('InvestmentListScreen defensive programming check for out of bounds index', (tester) async {
    // We intentionally provide an empty list to verify that the UI renders without crashing.
    // The main issue with out-of-bounds happens during transitions or empty data states.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allInvestmentsProvider.overrideWith((ref) => Stream.value([])),
          archivedInvestmentsProvider.overrideWith((ref) => Stream.value([])),
          activeInvestmentBasicStatsMapProvider.overrideWith((ref) => const AsyncValue.data({})),
          investmentCountsProvider.overrideWith((ref) => (all: 1, open: 1, closed: 0, archived: 0)),
          filteredInvestmentsProvider.overrideWith((ref) => const AsyncValue.data([])),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: InvestmentListScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify no crash occurred
    expect(find.byType(InvestmentListScreen), findsOneWidget);
  });
}
