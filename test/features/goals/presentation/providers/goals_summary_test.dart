import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';

// Helper to build a minimal GoalEntity with a specific updatedAt timestamp
GoalEntity _makeGoal({
  required String id,
  required DateTime updatedAt,
  bool isArchived = false,
}) {
  return GoalEntity(
    id: id,
    name: 'Goal $id',
    type: GoalType.targetAmount,
    targetAmount: 10000,
    trackingMode: GoalTrackingMode.all,
    icon: '🎯',
    colorValue: const Color(0xFF3B82F6).toARGB32(),
    createdAt: DateTime(2024, 1, 1),
    updatedAt: updatedAt,
    isArchived: isArchived,
  );
}

// Helper to build a GoalProgress with a specific status and progressPercent
GoalProgress _makeProgress({
  required GoalEntity goal,
  required GoalStatus status,
  double progressPercent = 50.0,
}) {
  return GoalProgress(
    goal: goal,
    currentAmount: goal.targetAmount * (progressPercent / 100),
    progressPercent: progressPercent,
    monthlyVelocity: 100,
    monthlyIncome: 0,
    status: status,
    currentMilestone: GoalMilestone.forPercentage(progressPercent),
    achievedMilestones: GoalMilestone.achievedMilestones(progressPercent),
    linkedInvestmentCount: 1,
    calculatedAt: DateTime.now(),
  );
}

void main() {
  group('GoalsSummary - empty()', () {
    test('empty() factory creates summary with all zeros and empty lists', () {
      final summary = GoalsSummary.empty();

      expect(summary.totalGoals, 0);
      expect(summary.achievedGoals, 0);
      expect(summary.onTrackGoals, 0);
      expect(summary.behindGoals, 0);
      expect(summary.averageProgress, 0.0);
      expect(summary.closestToCompletion, isNull);
      expect(summary.activeGoals, isEmpty);
      expect(summary.completedGoals, isEmpty);
    });

    test('empty() has no goals and no carousel goals', () {
      final summary = GoalsSummary.empty();

      expect(summary.hasGoals, isFalse);
      expect(summary.allCarouselGoals, isEmpty);
    });
  });

  group('GoalsSummary - completedGoals field', () {
    test('completedGoals defaults to empty list', () {
      final summary = GoalsSummary(
        totalGoals: 1,
        achievedGoals: 0,
        onTrackGoals: 1,
        behindGoals: 0,
        averageProgress: 50,
        activeGoals: [],
      );

      expect(summary.completedGoals, isEmpty);
    });

    test('completedGoals holds provided achieved goals', () {
      final goal = _makeGoal(id: 'g1', updatedAt: DateTime(2024, 6, 1));
      final progress = _makeProgress(
        goal: goal,
        status: GoalStatus.achieved,
        progressPercent: 100,
      );

      final summary = GoalsSummary(
        totalGoals: 1,
        achievedGoals: 1,
        onTrackGoals: 0,
        behindGoals: 0,
        averageProgress: 100,
        completedGoals: [progress],
      );

      expect(summary.completedGoals, hasLength(1));
      expect(summary.completedGoals.first.status, GoalStatus.achieved);
    });
  });

  group('GoalsSummary - allCarouselGoals getter', () {
    test('allCarouselGoals returns empty list when both lists are empty', () {
      final summary = GoalsSummary.empty();
      expect(summary.allCarouselGoals, isEmpty);
    });

    test('allCarouselGoals returns only activeGoals when completedGoals is empty', () {
      final goal1 = _makeGoal(id: 'g1', updatedAt: DateTime(2024, 1, 1));
      final goal2 = _makeGoal(id: 'g2', updatedAt: DateTime(2024, 2, 1));
      final p1 = _makeProgress(goal: goal1, status: GoalStatus.onTrack);
      final p2 = _makeProgress(goal: goal2, status: GoalStatus.behind);

      final summary = GoalsSummary(
        totalGoals: 2,
        achievedGoals: 0,
        onTrackGoals: 1,
        behindGoals: 1,
        averageProgress: 50,
        activeGoals: [p1, p2],
      );

      expect(summary.allCarouselGoals, hasLength(2));
      expect(summary.allCarouselGoals, containsAll([p1, p2]));
    });

    test(
      'allCarouselGoals returns only completedGoals when activeGoals is empty',
      () {
        final goal = _makeGoal(id: 'g1', updatedAt: DateTime(2024, 6, 1));
        final progress = _makeProgress(
          goal: goal,
          status: GoalStatus.achieved,
          progressPercent: 100,
        );

        final summary = GoalsSummary(
          totalGoals: 1,
          achievedGoals: 1,
          onTrackGoals: 0,
          behindGoals: 0,
          averageProgress: 100,
          completedGoals: [progress],
        );

        expect(summary.allCarouselGoals, hasLength(1));
        expect(summary.allCarouselGoals.first.status, GoalStatus.achieved);
      },
    );

    test(
      'allCarouselGoals puts active goals first, then completed goals',
      () {
        final activeGoal = _makeGoal(id: 'active', updatedAt: DateTime(2024, 1, 1));
        final completedGoal =
            _makeGoal(id: 'completed', updatedAt: DateTime(2024, 6, 1));

        final activeProgress =
            _makeProgress(goal: activeGoal, status: GoalStatus.onTrack);
        final completedProgress = _makeProgress(
          goal: completedGoal,
          status: GoalStatus.achieved,
          progressPercent: 100,
        );

        final summary = GoalsSummary(
          totalGoals: 2,
          achievedGoals: 1,
          onTrackGoals: 1,
          behindGoals: 0,
          averageProgress: 75,
          activeGoals: [activeProgress],
          completedGoals: [completedProgress],
        );

        final carousel = summary.allCarouselGoals;
        expect(carousel, hasLength(2));
        expect(carousel[0].goal.id, 'active'); // active first
        expect(carousel[1].goal.id, 'completed'); // completed second
      },
    );

    test(
      'allCarouselGoals preserves order within active and completed lists',
      () {
        final g1 = _makeGoal(id: 'g1', updatedAt: DateTime(2024, 1, 1));
        final g2 = _makeGoal(id: 'g2', updatedAt: DateTime(2024, 2, 1));
        final g3 = _makeGoal(id: 'g3', updatedAt: DateTime(2024, 3, 1));
        final g4 = _makeGoal(id: 'g4', updatedAt: DateTime(2024, 4, 1));

        final p1 = _makeProgress(goal: g1, status: GoalStatus.onTrack, progressPercent: 80);
        final p2 = _makeProgress(goal: g2, status: GoalStatus.behind, progressPercent: 40);
        final p3 = _makeProgress(goal: g3, status: GoalStatus.achieved, progressPercent: 100);
        final p4 = _makeProgress(goal: g4, status: GoalStatus.achieved, progressPercent: 100);

        final summary = GoalsSummary(
          totalGoals: 4,
          achievedGoals: 2,
          onTrackGoals: 1,
          behindGoals: 1,
          averageProgress: 65,
          activeGoals: [p1, p2],
          completedGoals: [p3, p4],
        );

        final carousel = summary.allCarouselGoals;
        expect(carousel, hasLength(4));
        expect(carousel[0].goal.id, 'g1');
        expect(carousel[1].goal.id, 'g2');
        expect(carousel[2].goal.id, 'g3');
        expect(carousel[3].goal.id, 'g4');
      },
    );
  });

  group('GoalsSummary - hasGoals and hasActiveGoals', () {
    test('hasGoals is false when totalGoals is 0', () {
      expect(GoalsSummary.empty().hasGoals, isFalse);
    });

    test('hasGoals is true when totalGoals > 0', () {
      final summary = GoalsSummary(
        totalGoals: 1,
        achievedGoals: 0,
        onTrackGoals: 1,
        behindGoals: 0,
        averageProgress: 50,
      );
      expect(summary.hasGoals, isTrue);
    });

    test('hasActiveGoals is false when all goals are achieved', () {
      final summary = GoalsSummary(
        totalGoals: 2,
        achievedGoals: 2,
        onTrackGoals: 0,
        behindGoals: 0,
        averageProgress: 100,
      );
      expect(summary.hasActiveGoals, isFalse);
    });

    test('hasActiveGoals is true when some goals are not achieved', () {
      final summary = GoalsSummary(
        totalGoals: 3,
        achievedGoals: 1,
        onTrackGoals: 2,
        behindGoals: 0,
        averageProgress: 70,
      );
      expect(summary.hasActiveGoals, isTrue);
    });
  });

  group('GoalsSummary - completedGoals sorting and limit', () {
    // These tests verify the logic described in the PR: sort by updatedAt desc,
    // limit to 5. We test the GoalsSummary data class behavior directly.

    test('completedGoals can hold up to 5 items (boundary)', () {
      final goals = List.generate(
        5,
        (i) => _makeGoal(
          id: 'g$i',
          updatedAt: DateTime(2024, i + 1, 1),
        ),
      );
      final progressList = goals
          .map(
            (g) => _makeProgress(
              goal: g,
              status: GoalStatus.achieved,
              progressPercent: 100,
            ),
          )
          .toList();

      final summary = GoalsSummary(
        totalGoals: 5,
        achievedGoals: 5,
        onTrackGoals: 0,
        behindGoals: 0,
        averageProgress: 100,
        completedGoals: progressList,
      );

      expect(summary.completedGoals, hasLength(5));
    });

    test(
      'most recently updated completed goals appear first when sorted',
      () {
        // Simulate what goalsSummaryProvider does: sort by updatedAt desc, take 5
        final goals = [
          _makeGoal(id: 'old', updatedAt: DateTime(2023, 1, 1)),
          _makeGoal(id: 'newest', updatedAt: DateTime(2024, 12, 1)),
          _makeGoal(id: 'middle', updatedAt: DateTime(2024, 6, 1)),
        ];

        final progressList = goals
            .map(
              (g) => _makeProgress(
                goal: g,
                status: GoalStatus.achieved,
                progressPercent: 100,
              ),
            )
            .toList();

        // Sort as the provider does
        progressList.sort(
          (a, b) => b.goal.updatedAt.compareTo(a.goal.updatedAt),
        );
        final recentCompleted = progressList.take(5).toList();

        final summary = GoalsSummary(
          totalGoals: 3,
          achievedGoals: 3,
          onTrackGoals: 0,
          behindGoals: 0,
          averageProgress: 100,
          completedGoals: recentCompleted,
        );

        expect(summary.completedGoals[0].goal.id, 'newest');
        expect(summary.completedGoals[1].goal.id, 'middle');
        expect(summary.completedGoals[2].goal.id, 'old');
      },
    );

    test(
      'completedGoals is limited to max 5 when more than 5 achieved goals exist',
      () {
        // Simulate what goalsSummaryProvider does: sort by updatedAt desc, take 5
        final goals = List.generate(
          7,
          (i) => _makeGoal(
            id: 'g$i',
            updatedAt: DateTime(2024, 1, i + 1),
          ),
        );
        final progressList = goals
            .map(
              (g) => _makeProgress(
                goal: g,
                status: GoalStatus.achieved,
                progressPercent: 100,
              ),
            )
            .toList();

        // Sort as the provider does: most recent first
        progressList.sort(
          (a, b) => b.goal.updatedAt.compareTo(a.goal.updatedAt),
        );
        final recentCompleted = progressList.take(5).toList();

        final summary = GoalsSummary(
          totalGoals: 7,
          achievedGoals: 7,
          onTrackGoals: 0,
          behindGoals: 0,
          averageProgress: 100,
          completedGoals: recentCompleted,
        );

        expect(summary.completedGoals, hasLength(5));
        // Most recent (g6, updatedAt Jan 7) should be first
        expect(summary.completedGoals.first.goal.id, 'g6');
      },
    );

    test(
      'allCarouselGoals includes all active goals plus up to 5 completed goals',
      () {
        final activeGoals = List.generate(
          3,
          (i) => _makeProgress(
            goal: _makeGoal(
              id: 'active$i',
              updatedAt: DateTime(2024, 1, i + 1),
            ),
            status: GoalStatus.onTrack,
          ),
        );
        final completedGoals = List.generate(
          5,
          (i) => _makeProgress(
            goal: _makeGoal(
              id: 'completed$i',
              updatedAt: DateTime(2024, 6, i + 1),
            ),
            status: GoalStatus.achieved,
            progressPercent: 100,
          ),
        );

        final summary = GoalsSummary(
          totalGoals: 8,
          achievedGoals: 5,
          onTrackGoals: 3,
          behindGoals: 0,
          averageProgress: 80,
          activeGoals: activeGoals,
          completedGoals: completedGoals,
        );

        expect(summary.allCarouselGoals, hasLength(8));
        // First 3 are active
        for (var i = 0; i < 3; i++) {
          expect(summary.allCarouselGoals[i].status, GoalStatus.onTrack);
        }
        // Last 5 are completed
        for (var i = 3; i < 8; i++) {
          expect(summary.allCarouselGoals[i].status, GoalStatus.achieved);
        }
      },
    );
  });

  group('GoalsSummary - regression tests', () {
    test(
      'allCarouselGoals does not mutate original activeGoals and completedGoals lists',
      () {
        final activeGoal = _makeGoal(id: 'a1', updatedAt: DateTime(2024, 1, 1));
        final completedGoal =
            _makeGoal(id: 'c1', updatedAt: DateTime(2024, 6, 1));
        final ap = _makeProgress(goal: activeGoal, status: GoalStatus.onTrack);
        final cp = _makeProgress(
          goal: completedGoal,
          status: GoalStatus.achieved,
          progressPercent: 100,
        );

        final summary = GoalsSummary(
          totalGoals: 2,
          achievedGoals: 1,
          onTrackGoals: 1,
          behindGoals: 0,
          averageProgress: 75,
          activeGoals: [ap],
          completedGoals: [cp],
        );

        final carousel = summary.allCarouselGoals;
        expect(summary.activeGoals, hasLength(1));
        expect(summary.completedGoals, hasLength(1));
        expect(carousel, hasLength(2));
      },
    );

    test(
      'calling allCarouselGoals multiple times returns consistent results',
      () {
        final g1 = _makeGoal(id: 'g1', updatedAt: DateTime(2024, 1, 1));
        final g2 = _makeGoal(id: 'g2', updatedAt: DateTime(2024, 6, 1));
        final p1 = _makeProgress(goal: g1, status: GoalStatus.onTrack);
        final p2 = _makeProgress(
          goal: g2,
          status: GoalStatus.achieved,
          progressPercent: 100,
        );

        final summary = GoalsSummary(
          totalGoals: 2,
          achievedGoals: 1,
          onTrackGoals: 1,
          behindGoals: 0,
          averageProgress: 75,
          activeGoals: [p1],
          completedGoals: [p2],
        );

        final first = summary.allCarouselGoals;
        final second = summary.allCarouselGoals;

        expect(first.length, second.length);
        expect(first[0].goal.id, second[0].goal.id);
        expect(first[1].goal.id, second[1].goal.id);
      },
    );
  });
}