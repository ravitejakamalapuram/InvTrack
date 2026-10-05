// A21 review follow-up: the Reports "Portfolio Health" tile shows the same
// rounded score as the dashboard, and says there is not enough data instead
// of "Score: 0/100" (the worst possible score) when there is no score.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/portfolio_health/domain/entities/portfolio_health_score.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/providers/portfolio_health_provider.dart';
import 'package:inv_tracker/features/reports/domain/entities/action_required_report.dart';
import 'package:inv_tracker/features/reports/presentation/providers/action_required_provider.dart';
import 'package:inv_tracker/features/reports/presentation/providers/smart_insights_provider.dart';
import 'package:inv_tracker/features/reports/presentation/screens/reports_home_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

ComponentScore _component(String name, double weight) => ComponentScore(
  name: name,
  score: 79.6,
  weight: weight,
  description: name,
  suggestions: const [],
);

class _FixedHealth extends PortfolioHealth {
  _FixedHealth(this.score);

  final PortfolioHealthScore? score;

  @override
  Future<PortfolioHealthScore?> build() async => score;
}

class _LoadingHealth extends PortfolioHealth {
  @override
  Future<PortfolioHealthScore?> build() =>
      Completer<PortfolioHealthScore?>().future;
}

Future<void> _pump(WidgetTester tester, PortfolioHealth Function() health) =>
    tester.pumpWidget(
      ProviderScope(
        overrides: [
          portfolioHealthProvider.overrideWith(health),
          smartInsightsProvider.overrideWith((ref, l10n) async => const []),
          priorityInsightsProvider.overrideWith((ref, l10n) async => const []),
          activeGoalsProvider.overrideWith((ref) => Stream.value(const [])),
          actionRequiredReportProvider.overrideWith(
            (ref) async => const ActionRequiredReport(
              criticalActions: [],
              highPriorityActions: [],
              mediumPriorityActions: [],
              lowPriorityActions: [],
              totalActions: 0,
              overdueActions: 0,
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ReportsHomeScreen(),
        ),
      ),
    );

void main() {
  testWidgets('no score says there is not enough data, not 0/100', (
    tester,
  ) async {
    await _pump(tester, () => _FixedHealth(null));
    await tester.pump();

    expect(find.text('Not enough data yet'), findsOneWidget);
    expect(find.textContaining('Score:'), findsNothing);
  });

  testWidgets('no number is shown while the score is loading', (tester) async {
    await _pump(tester, _LoadingHealth.new);
    await tester.pump();

    expect(find.text('Score: 0/100'), findsNothing);
    expect(find.textContaining('Score:'), findsNothing);
  });

  testWidgets('a score of 79.6 shows as 80, like the dashboard', (
    tester,
  ) async {
    await _pump(
      tester,
      () => _FixedHealth(
        PortfolioHealthScore(
          overallScore: 79.6,
          returnsPerformance: _component('Returns Performance', 0.30),
          diversification: _component('Diversification', 0.25),
          liquidity: _component('Liquidity', 0.20),
          goalAlignment: _component('Goal Alignment', 0.15),
          actionReadiness: _component('Action Readiness', 0.10),
          calculatedAt: DateTime(2026, 10, 4),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Score: 80/100'), findsOneWidget);
  });
}
