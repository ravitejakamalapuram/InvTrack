// A21: the details screen shows the score with the same rounding rule as its
// tier (ANLY-16) and says when there is not enough data for a score
// (ANLY-07).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/features/portfolio_health/domain/entities/portfolio_health_score.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/providers/portfolio_health_provider.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/screens/portfolio_health_details_screen.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/ui_extensions/score_tier_ui.dart';
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

Future<void> _pump(WidgetTester tester, PortfolioHealthScore? score) async {
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
        home: PortfolioHealthDetailsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('PortfolioHealthDetailsScreen', () {
    testWidgets('a score of 79.6 shows as 80 with the Excellent tier', (
      tester,
    ) async {
      await _pump(
        tester,
        PortfolioHealthScore(
          overallScore: 79.6,
          returnsPerformance: _component('Returns Performance', 0.30),
          diversification: _component('Diversification', 0.25),
          liquidity: _component('Liquidity', 0.20),
          goalAlignment: _component('Goal Alignment', 0.15),
          actionReadiness: _component('Action Readiness', 0.10),
          calculatedAt: DateTime(2026, 10, 4),
        ),
      );

      // The overall score and each 79.6 component badge all read 80, and all
      // take the colour of 80 (Excellent green, in the deeper light-mode text
      // green rather than the old #059669 at 3.77:1), not the amber of 79.6.
      expect(find.text('80'), findsNWidgets(6));
      expect(find.text('Excellent'), findsOneWidget);
      expect(find.text('Good'), findsNothing);
      expect(
        tester.widgetList<Text>(find.text('80')).map((t) => t.style?.color),
        everyElement(ScoreTier.excellent.textColor(false)),
      );
    });

    testWidgets('returns that are too early to judge are worded from the ARB '
        'file', (tester) async {
      await _pump(
        tester,
        PortfolioHealthScore(
          overallScore: 50,
          returnsPerformance: ComponentScore(
            name: 'Returns Performance',
            score: 50,
            weight: 0.30,
            description: '',
            suggestions: const [],
            note: ComponentNote.tooEarlyToJudge,
          ),
          diversification: _component('Diversification', 0.25),
          liquidity: _component('Liquidity', 0.20),
          goalAlignment: _component('Goal Alignment', 0.15),
          actionReadiness: _component('Action Readiness', 0.10),
          calculatedAt: DateTime(2026, 10, 4),
        ),
      );

      expect(
        find.text('Too early to judge', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text(
          'Returns are judged once your investments are 90 days old',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
    });

    testWidgets('no score says there is not enough data', (tester) async {
      await _pump(tester, null);

      expect(find.text('Not enough data yet'), findsOneWidget);
      expect(
        find.text(
          'Add your investments, with a current value for open ones, to see '
          'your health score.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the score card starts on the shared screen edge (#998)', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(360 * 3, 780 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await _pump(
        tester,
        PortfolioHealthScore(
          overallScore: 50,
          returnsPerformance: _component('Returns Performance', 0.30),
          diversification: _component('Diversification', 0.25),
          liquidity: _component('Liquidity', 0.20),
          goalAlignment: _component('Goal Alignment', 0.15),
          actionReadiness: _component('Action Readiness', 0.10),
          calculatedAt: DateTime(2026, 10, 4),
        ),
      );

      final card = tester.getRect(find.byType(GlassCard).first);
      expect(card.left, AppSpacing.screenEdge);
      expect(360 - card.right, AppSpacing.screenEdge);
    });
  });
}
