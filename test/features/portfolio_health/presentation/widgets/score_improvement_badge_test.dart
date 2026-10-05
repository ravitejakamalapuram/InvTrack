// A21 review follow-up: the score-change badge uses the same rounding rule
// as the score it sits next to (ANLY-16), so the change it shows is the
// change in the numbers the user sees.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/portfolio_health/data/models/health_score_snapshot_model.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/providers/portfolio_health_provider.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/widgets/score_improvement_badge.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

HealthScoreSnapshotModel _snapshot(double overall, int day) =>
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

Future<void> _pump(WidgetTester tester, double previous, double current) =>
    tester.pumpWidget(
      ProviderScope(
        overrides: [
          historicalHealthScoresProvider.overrideWith(
            (ref) =>
                Stream.value([_snapshot(previous, 1), _snapshot(current, 8)]),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ScoreImprovementBadge()),
        ),
      ),
    );

void main() {
  testWidgets('78.4 to 79.6 reads 78 to 80, so the badge says +2', (
    tester,
  ) async {
    await _pump(tester, 78.4, 79.6);
    await tester.pump();

    expect(find.text('+2 pts'), findsOneWidget);
  });

  testWidgets('78.6 to 79.5 reads 79 to 80, so the badge says +1', (
    tester,
  ) async {
    await _pump(tester, 78.6, 79.5);
    await tester.pump();

    expect(find.text('+1 pts'), findsOneWidget);
  });

  testWidgets('79.4 to 78.6 reads 79 to 79, so there is no badge', (
    tester,
  ) async {
    await _pump(tester, 79.4, 78.6);
    await tester.pump();

    expect(find.textContaining('pts'), findsNothing);
  });
}
