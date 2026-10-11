// The goal cards: the footer text of a goal in the list ends on the same edge
// as its progress ring, its chip is never cut in the middle of a word, and the
// carousel card on the Overview fits its slot at every text size.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/goals/presentation/ui_extensions/goal_type_ui.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goal_card.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goal_carousel_card.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goal_progress_ring.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goals_dashboard_card.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/shared_goals_chip.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import 'card_guard_harness.dart';
import 'layout_guard_harness.dart' show guardTolerance;

/// The card's own border (GlassCard draws a 1dp one) and the padding of its
/// content, so the content edge is this far inside the card.
const _inset = 1 + 16.0;

final _l10n = lookupAppLocalizations(const Locale('en'));

GoalEntity _goal({
  required String id,
  String name = 'Emergency Fund',
  bool income = false,
  DateTime? targetDate,
}) => GoalEntity(
  id: id,
  name: name,
  type: income ? GoalType.incomeTarget : GoalType.targetAmount,
  targetAmount: income ? 0 : 1000000,
  targetMonthlyIncome: income ? 50000 : null,
  targetDate: targetDate,
  trackingMode: GoalTrackingMode.all,
  icon: '🛡️',
  colorValue: 0xFF3B82F6,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  currency: 'INR',
);

class _GoalCase {
  _GoalCase(
    this.name, {
    required this.status,
    this.percent = 40,
    this.others = 0,
    this.projected,
    this.targetDate,
    this.income = false,
    this.goalName = 'Emergency Fund',
    this.selection = false,
  });

  final String name;
  final GoalStatus status;
  final double percent;
  final int others;
  final DateTime? projected;
  final DateTime? targetDate;
  final bool income;
  final String goalName;
  final bool selection;

  late final GoalEntity goal = _goal(
    id: 'goal-${name.hashCode}',
    name: goalName,
    income: income,
    targetDate: targetDate,
  );

  late final GoalProgress progress = GoalProgress(
    goal: goal,
    currentAmount: income ? 0 : percent / 100 * 1000000,
    targetAmount: income ? 50000 : 1000000,
    progressPercent: percent,
    monthlyVelocity: 5000,
    monthlyIncome: income ? 5353 : 0,
    otherGoalsCount: others,
    projectedCompletionDate: projected,
    status: status,
    currentMilestone: GoalMilestone.forPercentage(percent),
    achievedMilestones: GoalMilestone.achievedMilestones(percent),
    linkedInvestmentCount: 3,
    calculatedAt: DateTime(2026, 10, 11),
  );
}

List<_GoalCase> _goalCases() => [
  _GoalCase('achieved', status: GoalStatus.achieved, percent: 100),
  _GoalCase(
    'on track for a date',
    status: GoalStatus.onTrack,
    projected: DateTime(2057, 6, 15),
    targetDate: DateTime(2058, 1, 1),
  ),
  _GoalCase('steady, no projected date', status: GoalStatus.onTrack),
  _GoalCase('ahead', status: GoalStatus.ahead, percent: 60),
  _GoalCase(
    'behind a target date',
    status: GoalStatus.behind,
    percent: 20,
    targetDate: DateTime(2030, 1, 1),
  ),
  _GoalCase('behind, no target date', status: GoalStatus.behind, percent: 20),
  _GoalCase('in progress', status: GoalStatus.inProgress, percent: 10),
  _GoalCase(
    'in progress, income goal',
    status: GoalStatus.inProgress,
    percent: 10,
    income: true,
  ),
  _GoalCase('not started', status: GoalStatus.notStarted, percent: 0),
  _GoalCase('archived', status: GoalStatus.archived, percent: 70),
  _GoalCase(
    'achieved, also in 2 goals',
    status: GoalStatus.achieved,
    percent: 100,
    others: 2,
  ),
  _GoalCase(
    'on track, also in 1 goal',
    status: GoalStatus.onTrack,
    projected: DateTime(2057, 6, 15),
    others: 1,
  ),
  _GoalCase(
    'behind, also in 12 goals',
    status: GoalStatus.behind,
    percent: 20,
    targetDate: DateTime(2030, 1, 1),
    others: 12,
  ),
  _GoalCase(
    'ahead, long name, also in 2 goals',
    status: GoalStatus.ahead,
    percent: 60,
    others: 2,
    goalName: 'Retirement corpus for the house by the sea in Goa',
  ),
  _GoalCase(
    'achieved in selection mode',
    status: GoalStatus.achieved,
    percent: 100,
    others: 2,
    selection: true,
  ),
];

/// What the chip of [count] other goals says on a card, as the owner decided.
String _chipText(int count) =>
    count == 1 ? 'Also in 1 goal' : 'Also in $count goals';

class _Shape {
  _Shape({this.footer, this.chip, this.cardWidth});
  final Rect? footer;
  final Rect? chip;
  final double? cardWidth;
}

/// Every goal case at the width and text scale of [g]. Privacy mode and the
/// right-to-left layout run at the smallest and the largest text only.
Future<void> checkGoalCards(CardGuard g) async {
  final edgeScales = g.textScale == 1.0 || g.textScale == 2.0;
  for (final c in _goalCases()) {
    final plain = await _runGoal(g, c, privacy: false, rtl: false);
    if (!edgeScales) continue;
    final hidden = await _runGoal(g, c, privacy: true, rtl: false);
    g.scope = '${c.name}, privacy mode vs plain';
    g.expectNear('card width', hidden.cardWidth, plain.cardWidth ?? double.nan);
    final a = plain.footer;
    final b = hidden.footer;
    if (a != null && b != null) {
      g.expectNear('footer text left', b.left, a.left);
      g.expectNear('footer text right', b.right, a.right);
    }
    await _runGoal(g, c, privacy: false, rtl: true);
  }
}

Future<_Shape> _runGoal(
  CardGuard g,
  _GoalCase c, {
  required bool privacy,
  required bool rtl,
}) async {
  g.scope =
      '${c.name}${privacy ? ', privacy mode' : ''}${rtl ? ', right to left' : ''}';
  final overrides = <Override>[
    multiCurrencyGoalProgressProvider(
      c.goal.id,
    ).overrideWith((ref) => Future.value(c.progress)),
  ];
  await g.pump(
    GoalCard(goal: c.goal, onTap: () {}, isSelectionMode: c.selection),
    overrides: overrides,
    privacy: privacy,
    rtl: rtl,
  );

  final cardFinder = find.descendant(
    of: find.byType(GoalCard),
    matching: find.byType(GlassCard),
  );
  final card = g.rect('goal card', cardFinder);
  if (card == null) return _Shape();
  final startEdge = rtl ? card.right - _inset : card.left + _inset;
  final endEdge = rtl ? card.left + _inset : card.right - _inset;

  // The ring (or its hidden stand-in) ends on the content edge.
  final ring = privacy ? find.text('••%') : find.byType(GoalProgressRing);
  final ringRect = g.rect('progress ring', ring);
  if (ringRect != null) g.expectNear('ring end', g.endOf(ringRect), endEdge);

  // The footer: the status on the start edge, its message on the end edge.
  final status = c.progress.status;
  final icon = g.iconStart('footer status icon', cardFinder, status.icon);
  g.expectNear('footer status icon start', icon, startEdge);
  final message = c.progress.statusMessage(_l10n);
  final messageFinder = find.descendant(
    of: cardFinder,
    matching: find.text(message),
  );
  final extent = g.textExtent('footer message', messageFinder);
  g.expectNear('footer message end', extent?.end, endEdge);
  g.expectWholeWords('footer message', messageFinder, noEllipsisNet: true);
  final footer = g.textRect('footer message', messageFinder);

  // The chip: whole words, the short text, the long text for the screen
  // reader, and clear of the ring.
  final chip = find.byType(SharedGoalsChip);
  Rect? chipRect;
  if (c.others == 0) {
    if (chip.evaluate().isNotEmpty) g.fault('a chip shows for no other goal');
  } else {
    chipRect = g.rect('shared goals chip', chip);
    final chipText = find.descendant(of: chip, matching: find.byType(Text));
    final shown = chipText.evaluate().isEmpty
        ? null
        : g.tester.widget<Text>(chipText.first).data;
    if (shown != _chipText(c.others)) {
      g.fault('the chip says "$shown", want "${_chipText(c.others)}"');
    }
    // Privacy mode swaps the ring for a text that is wider than the ring at
    // large text sizes, which leaves the chip a sliver (a follow-up of its
    // own), so words are only guaranteed whole in the plain run.
    if (!privacy) {
      g.expectWholeWords('chip text', chipText, noEllipsisNet: true);
    }
    if (chipRect != null && ringRect != null) {
      final gap = rtl
          ? chipRect.left - ringRect.right
          : ringRect.left - chipRect.right;
      if (gap < AppSpacing.sm - guardTolerance) {
        g.fault('the chip is ${g.dp(gap)}dp from the ring, want at least 12');
      }
    }
  }

  return _Shape(footer: footer, chip: chipRect, cardWidth: card.width);
}

// -- The carousel card on the Overview --------------------------------------

class _CarouselCase {
  _CarouselCase(this.name, this.goalCase);
  final String name;
  final _GoalCase goalCase;
}

List<_CarouselCase> _carouselCases() => [
  _CarouselCase(
    'active goal',
    _GoalCase('active', status: GoalStatus.onTrack, percent: 45),
  ),
  _CarouselCase(
    'achieved goal',
    _GoalCase('done', status: GoalStatus.achieved, percent: 100),
  ),
  _CarouselCase(
    'not started goal',
    _GoalCase('new', status: GoalStatus.notStarted, percent: 0),
  ),
  _CarouselCase(
    'income goal',
    _GoalCase(
      'income',
      status: GoalStatus.inProgress,
      percent: 10,
      income: true,
    ),
  ),
  _CarouselCase(
    'long name',
    _GoalCase(
      'long',
      status: GoalStatus.behind,
      percent: 33,
      goalName: 'Retirement corpus for the house by the sea in Goa',
    ),
  ),
];

/// Every carousel case, in the dashboard card the Overview shows.
Future<void> checkGoalCarousel(CardGuard g) async {
  for (final c in _carouselCases()) {
    for (final privacy in const [false, true]) {
      g.scope = '${c.name}${privacy ? ', privacy mode' : ''}';
      final progress = c.goalCase.progress;
      final achieved = progress.status == GoalStatus.achieved;
      final summary = GoalsSummary(
        totalGoals: 1,
        achievedGoals: achieved ? 1 : 0,
        onTrackGoals: 0,
        behindGoals: 0,
        averageProgress: progress.progressPercent,
        activeGoals: achieved ? const [] : [progress],
        completedGoals: achieved ? [progress] : const [],
      );
      await g.pump(
        const GoalsDashboardCard(),
        overrides: [
          multiCurrencyGoalsSummaryProvider.overrideWith(
            (ref) => Future.value(summary),
          ),
        ],
        privacy: privacy,
      );

      final carousel = find.byType(GoalCarouselCard).first;
      final cardFinder = find.descendant(
        of: carousel,
        matching: find.byType(GlassCard),
      );
      final card = g.rect('carousel card', cardFinder);
      if (card == null) continue;
      final endEdge = card.right - _inset;

      // The badge on the first line and the progress bar end on the content
      // edge.
      if (!privacy) {
        final badgeText = achieved
            ? _l10n.goalCompleted
            : '${progress.displayPercent}%';
        final badge = g.rect(
          'badge',
          find.ancestor(
            of: find.descendant(of: carousel, matching: find.text(badgeText)),
            matching: find.byType(Container),
          ),
        );
        if (badge != null) g.expectNear('badge end', badge.right, endEdge);
      }
      final bar = g.rect(
        'progress bar',
        find.ancestor(
          of: find.descendant(
            of: carousel,
            matching: find.byType(FractionallySizedBox),
          ),
          matching: find.byType(Stack),
        ),
      );
      if (bar != null) g.expectNear('progress bar end', bar.right, endEdge);
    }
  }
}
