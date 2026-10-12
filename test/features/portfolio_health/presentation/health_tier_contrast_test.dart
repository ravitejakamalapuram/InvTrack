// The portfolio-health tier colours (Excellent, Good, Fair, Poor) used to be
// copied into four files, and three of the four light colours were under 4.5:1
// on white (green 3.77, amber 2.15, orange 2.80). One function now serves the
// card, the details screen, the component bars and the trend chart. The
// number, the tier word and the sign of the change still carry the meaning.
//
// The ids are rows of test/core/theme/contrast_pairs.dart; the guard finds
// them here.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/features/portfolio_health/data/models/health_score_snapshot_model.dart';
import 'package:inv_tracker/features/portfolio_health/domain/entities/portfolio_health_score.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/providers/portfolio_health_provider.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/screens/portfolio_health_details_screen.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/ui_extensions/score_tier_ui.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/widgets/health_score_trend_chart.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/widgets/portfolio_health_dashboard_card.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/widgets/score_improvement_badge.dart';

import '../../../helpers/contrast.dart';
import '../../../helpers/themed_pump.dart';

class _FixedHealth extends PortfolioHealth {
  _FixedHealth(this.score);
  final PortfolioHealthScore score;

  @override
  Future<PortfolioHealthScore?> build() async => score;
}

ComponentScore _component(String name, double score) => ComponentScore(
  name: name,
  score: score,
  weight: 0.2,
  description: name,
  suggestions: const ['Add a second asset class'],
);

PortfolioHealthScore _scoreOf(double value) => PortfolioHealthScore(
  overallScore: value,
  returnsPerformance: _component('Returns Performance', value),
  diversification: _component('Diversification', value),
  liquidity: _component('Liquidity', value),
  goalAlignment: _component('Goal Alignment', value),
  actionReadiness: _component('Action Readiness', value),
  calculatedAt: DateTime(2026, 10, 4),
);

/// A score in each tier, with the ids of its pairs in light and in dark: the
/// tier word and the number on the card, and the component badge on its tint.
const _tiers = <(ScoreTier, double, String, String, String, String)>[
  (
    ScoreTier.excellent,
    90,
    'health-tier-excellent-light@card',
    'health-tier-excellent-dark@card',
    'health-badge-excellent-light@tint10',
    'health-badge-excellent-dark@tint10',
  ),
  (
    ScoreTier.good,
    70,
    'health-tier-good-light@card',
    'health-tier-good-dark@card',
    'health-badge-good-light@tint10',
    'health-badge-good-dark@tint10',
  ),
  (
    ScoreTier.fair,
    50,
    'health-tier-fair-light@card',
    'health-tier-fair-dark@card',
    'health-badge-fair-light@tint10',
    'health-badge-fair-dark@tint10',
  ),
  (
    ScoreTier.poor,
    20,
    'health-tier-poor-light@card',
    'health-tier-poor-dark@card',
    'health-badge-poor-light@tint10',
    'health-badge-poor-dark@tint10',
  ),
];

Color _page(Brightness b) =>
    b == Brightness.dark ? AppColors.backgroundDark : AppColors.backgroundLight;

Future<void> _pumpDetails(
  WidgetTester tester,
  PortfolioHealthScore score,
  Brightness brightness,
) async {
  await pumpThemed(
    tester,
    const PortfolioHealthDetailsScreen(),
    brightness: brightness,
    overrides: [
      isPortfolioHealthEnabledProvider.overrideWithValue(true),
      portfolioHealthProvider.overrideWith(() => _FixedHealth(score)),
      historicalHealthScoresProvider.overrideWith(
        (ref) => Stream.value(const []),
      ),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  for (final (tier, value, lightId, darkId, badgeLightId, badgeDarkId)
      in _tiers) {
    for (final brightness in Brightness.values) {
      final dark = brightness == Brightness.dark;
      final id = dark ? darkId : lightId;
      final badgeId = dark ? badgeDarkId : badgeLightId;

      testWidgets('$id: the tier word and the number read on the card', (
        tester,
      ) async {
        await _pumpDetails(tester, _scoreOf(value), brightness);
        final word = find.text(tier.label);
        expect(word, findsOneWidget);
        final color = paintedTextColor(tester, word);
        expect(color, tier.textColor(dark));
        final ground = groundBehind(tester, word, _page(brightness));
        expect(
          contrastRatio(color, ground),
          greaterThanOrEqualTo(kMinText),
          reason: id,
        );
        // The number and the "/ 100" under it are the same colour.
        final number = find.text(value.round().toString()).first;
        expect(paintedTextColor(tester, number), color);
        expect(paintedTextColor(tester, find.text('/ 100')), color);
      });

      testWidgets('$badgeId: a component badge reads on its tint', (
        tester,
      ) async {
        await _pumpDetails(tester, _scoreOf(value), brightness);
        final badge = find.text(value.round().toString()).last;
        final color = paintedTextColor(tester, badge);
        expect(color, tier.textColor(dark));
        final ground = groundBehind(tester, badge, _page(brightness));
        expect(
          contrastRatio(color, ground),
          greaterThanOrEqualTo(kMinText),
          reason: badgeId,
        );
      });
    }
  }

  for (final (brightness, id) in [
    (Brightness.light, 'health-suggestion-digit-light@fill'),
    (Brightness.dark, 'health-suggestion-digit-dark@fill'),
  ]) {
    testWidgets('$id: the suggestion number reads on its circle', (
      tester,
    ) async {
      await _pumpDetails(tester, _scoreOf(50), brightness);
      final digit = find.text('1');
      expect(digit, findsWidgets);
      final color = paintedTextColor(tester, digit.first);
      final ground = groundBehind(tester, digit.first, _page(brightness));
      expect(color, AppColors.onFill(ground));
      expect(
        contrastRatio(color, ground),
        greaterThanOrEqualTo(kMinText),
        reason: id,
      );
    });
  }

  testWidgets('the dashboard card paints the same tier colour as the screen', (
    tester,
  ) async {
    await pumpThemed(
      tester,
      const PortfolioHealthDashboardCard(),
      brightness: Brightness.light,
      overrides: [
        isPortfolioHealthEnabledProvider.overrideWithValue(true),
        portfolioHealthProvider.overrideWith(() => _FixedHealth(_scoreOf(50))),
        historicalHealthScoresProvider.overrideWith(
          (ref) => Stream.value(const []),
        ),
      ],
    );
    await tester.pumpAndSettle();
    expect(
      paintedTextColor(tester, find.text('Fair')),
      ScoreTier.fair.textColor(false),
    );
  });

  test('the tier colours keep the dark values and deepen the light ones', () {
    expect(ScoreTier.excellent.textColor(true), AppColors.graphEmerald);
    expect(ScoreTier.good.textColor(true), AppColors.warningDark);
    expect(ScoreTier.excellent.textColor(false), AppColors.successLight);
    expect(ScoreTier.good.textColor(false), AppColors.warningTextLight);
    expect(ScoreTier.poor.textColor(false), AppColors.dangerLight);
  });

  group('the trend chart lines', () {
    final data = [
      for (var i = 0; i < 3; i++)
        {
          'date': DateTime(2026, 9, 1 + i * 7).millisecondsSinceEpoch,
          'score': 60 + i,
          'returns': 60 + i,
          'diversification': 60 + i,
          'liquidity': 60 + i,
          'goals': 60 + i,
          'actions': 60 + i,
        },
    ];

    for (final (brightness, id) in [
      (Brightness.light, 'health-chart-lines-light@card'),
      (Brightness.dark, 'health-chart-lines-dark@card'),
    ]) {
      testWidgets('$id: the overall line is 3:1 against the card', (
        tester,
      ) async {
        await pumpThemed(
          tester,
          const HealthScoreTrendChart(),
          brightness: brightness,
          overrides: [
            healthScoreChartDataProvider.overrideWith(
              (ref) => Stream.value(data),
            ),
          ],
        );
        await tester.pump();
        await tester.tap(find.text('Show Details'));
        await tester.pump();
        final chart = tester.widget<LineChart>(find.byType(LineChart));
        final ground = brightness == Brightness.dark
            ? AppColors.cardDark
            : AppColors.cardLight;
        final lines = chart.data.lineBarsData;
        expect(lines, hasLength(6));
        // The overall line is the one that carries the data: it is the
        // Excellent tier colour and reads against the card. The five
        // component lines are drawn at 60% on purpose and are not judged
        // here (see the PR body).
        expect(
          contrastRatio(lines.first.color!, ground),
          greaterThanOrEqualTo(kMinGraphic),
          reason: id,
        );
        // The overall line is the Excellent tier colour.
        expect(
          lines.first.color,
          ScoreTier.excellent.textColor(brightness == Brightness.dark),
        );
      });
    }
  });

  group('the score-change badge', () {
    HealthScoreSnapshotModel snapshot(double overall, int day) =>
        HealthScoreSnapshotModel(
          id: 'week-$day',
          overallScore: overall,
          returnsScore: overall,
          diversificationScore: overall,
          liquidityScore: overall,
          goalAlignmentScore: overall,
          actionReadinessScore: overall,
          calculatedAt: DateTime(2026, 9, day),
        );

    for (final (brightness, positive, id, text) in [
      (Brightness.light, true, 'score-change-positive-light@tint10', '+5 pts'),
      (Brightness.dark, true, 'score-change-positive-dark@tint10', '+5 pts'),
      (Brightness.light, false, 'score-change-negative-light@tint10', '-5 pts'),
      (Brightness.dark, false, 'score-change-negative-dark@tint10', '-5 pts'),
    ]) {
      testWidgets('$id: the change reads on its tint and keeps its sign', (
        tester,
      ) async {
        final (previous, current) = positive ? (60.0, 65.0) : (65.0, 60.0);
        await pumpThemed(
          tester,
          const ScoreImprovementBadge(),
          brightness: brightness,
          overrides: [
            historicalHealthScoresProvider.overrideWith(
              (ref) =>
                  Stream.value([snapshot(previous, 1), snapshot(current, 8)]),
            ),
          ],
        );
        await tester.pump();
        final label = find.text(text);
        expect(label, findsOneWidget);
        final color = paintedTextColor(tester, label);
        final dark = brightness == Brightness.dark;
        expect(
          color,
          positive
              ? (dark ? AppColors.successDark : AppColors.successLight)
              : (dark ? AppColors.dangerDark : AppColors.dangerLight),
        );
        expect(
          contrastRatio(
            color,
            groundBehind(
              tester,
              label,
              dark ? AppColors.cardDark : AppColors.cardLight,
            ),
          ),
          greaterThanOrEqualTo(kMinText),
          reason: id,
        );
      });
    }
  });
}
