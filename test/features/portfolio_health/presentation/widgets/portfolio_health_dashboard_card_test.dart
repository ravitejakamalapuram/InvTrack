// A21: the score and its tier use one rounding rule, so a score of 79.6
// never reads "80" next to "Good" under an "Excellent from 80" legend
// (ANLY-16), and a portfolio with no score says there is not enough data
// (ANLY-07).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/features/portfolio_health/domain/entities/portfolio_health_score.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/providers/portfolio_health_provider.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/widgets/portfolio_health_dashboard_card.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

ComponentScore _component(String name, double weight) => ComponentScore(
  name: name,
  score: 79.6,
  weight: weight,
  description: name,
  suggestions: const [],
);

PortfolioHealthScore _scoreOf(double overall) => PortfolioHealthScore(
  overallScore: overall,
  returnsPerformance: _component('Returns Performance', 0.30),
  diversification: _component('Diversification', 0.25),
  liquidity: _component('Liquidity', 0.20),
  goalAlignment: _component('Goal Alignment', 0.15),
  actionReadiness: _component('Action Readiness', 0.10),
  calculatedAt: DateTime(2026, 10, 4),
);

class _FixedHealth extends PortfolioHealth {
  _FixedHealth(this.score);

  final PortfolioHealthScore? score;

  @override
  Future<PortfolioHealthScore?> build() async => score;
}

Future<void> _pumpCard(WidgetTester tester, PortfolioHealthScore? score) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        isPortfolioHealthEnabledProvider.overrideWithValue(true),
        portfolioHealthProvider.overrideWith(() => _FixedHealth(score)),
        historicalHealthScoresProvider.overrideWith(
          (ref) => Stream.value(const []),
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: PortfolioHealthDashboardCard()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('79.6 is shown as 80, and its tier is the tier of 80', () {
    final score = _scoreOf(79.6);

    expect(score.tier, ScoreTier.excellent);
  });

  test('79.4 is shown as 79, and its tier is the tier of 79', () {
    final score = _scoreOf(79.4);

    expect(score.tier, ScoreTier.good);
  });

  testWidgets('the dashboard ring and tier agree for a score of 79.6', (
    tester,
  ) async {
    await _pumpCard(tester, _scoreOf(79.6));

    expect(find.text('80'), findsOneWidget);
    expect(find.text('Excellent'), findsOneWidget);
    expect(find.text('Good'), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp(r'Portfolio health score 80 out of 100')),
      findsOneWidget,
    );
  });

  testWidgets('a portfolio with no score says there is not enough data', (
    tester,
  ) async {
    await _pumpCard(tester, null);

    expect(
      find.text(
        'Not enough data yet. Add your investments, with a current value '
        'for open ones, to see your health score.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('/ 100'), findsNothing);
  });
}
