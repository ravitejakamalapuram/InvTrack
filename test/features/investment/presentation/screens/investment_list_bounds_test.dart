import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/investment_list_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_list_enums.dart';

void main() {
  testWidgets('InvestmentListScreen defensive programming check for out of bounds index', (tester) async {
    final investment = InvestmentEntity(
      id: 'inv-1',
      name: 'Test Investment',
      type: InvestmentType.stocks,
      currency: 'USD',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: InvestmentStatus.open,
    );
    final stats = InvestmentStats.empty();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allInvestmentsProvider.overrideWith((ref) => Stream.value([investment])),
          archivedInvestmentsProvider.overrideWith((ref) => Stream.value([])),
          investmentBasicStatsProvider('inv-1').overrideWith((ref) => AsyncValue.data(stats)),
          investmentXirrProvider('inv-1').overrideWith((ref) => Future.value(0.0)),
          activeInvestmentBasicStatsMapProvider.overrideWith((ref) => const AsyncValue.data({})),
          investmentCountsProvider.overrideWith((ref) => (all: 1, open: 1, closed: 0, archived: 0)),
          // Intentionally providing an empty list here to simulate the state that throws the error
          // while the underlying widget might still have childCount = 1 during a transition.
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

    // Verify no crash occurred and empty state is rendered or just empty screen
    expect(find.byType(InvestmentListScreen), findsOneWidget);
  });
}
