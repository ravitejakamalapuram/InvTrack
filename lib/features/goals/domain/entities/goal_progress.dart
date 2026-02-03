import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';

/// Milestone levels for goal progress
enum GoalMilestone {
  start(0),
  quarter(25),
  half(50),
  threeQuarters(75),
  ninety(90),
  complete(100);

  final int percentage;
  const GoalMilestone(this.percentage);

  String get displayName {
    switch (this) {
      case GoalMilestone.start:
        return 'Started';
      case GoalMilestone.quarter:
        return '25% Complete';
      case GoalMilestone.half:
        return 'Halfway There!';
      case GoalMilestone.threeQuarters:
        return '75% Complete';
      case GoalMilestone.ninety:
        return 'Almost There!';
      case GoalMilestone.complete:
        return 'Goal Achieved! 🎉';
    }
  }

  String get emoji {
    switch (this) {
      case GoalMilestone.start:
        return '🚀';
      case GoalMilestone.quarter:
        return '🌱';
      case GoalMilestone.half:
        return '⭐';
      case GoalMilestone.threeQuarters:
        return '🔥';
      case GoalMilestone.ninety:
        return '🏃';
      case GoalMilestone.complete:
        return '🏆';
    }
  }

  /// Get the milestone for a given percentage
  static GoalMilestone forPercentage(double percent) {
    if (percent >= 100) return GoalMilestone.complete;
    if (percent >= 90) return GoalMilestone.ninety;
    if (percent >= 75) return GoalMilestone.threeQuarters;
    if (percent >= 50) return GoalMilestone.half;
    if (percent >= 25) return GoalMilestone.quarter;
    return GoalMilestone.start;
  }

  /// Get milestones that have been achieved for a given percentage
  static List<GoalMilestone> achievedMilestones(double percent) {
    return GoalMilestone.values
        .where((m) => m.percentage <= percent && m.percentage > 0)
        .toList();
  }
}

/// Calculated progress for a goal
class GoalProgress {
  final GoalEntity goal;
  final double currentAmount;
  final double progressPercent;
  final double monthlyVelocity; // Average monthly contribution
  final double monthlyIncome; // For income goals
  final DateTime? projectedCompletionDate;
  final GoalStatus status;
  final GoalMilestone currentMilestone;
  final List<GoalMilestone> achievedMilestones;
  final int linkedInvestmentCount;
  final DateTime calculatedAt;

  const GoalProgress({
    required this.goal,
    required this.currentAmount,
    required this.progressPercent,
    required this.monthlyVelocity,
    required this.monthlyIncome,
    this.projectedCompletionDate,
    required this.status,
    required this.currentMilestone,
    required this.achievedMilestones,
    required this.linkedInvestmentCount,
    required this.calculatedAt,
  });

  /// Target amount from the goal
  double get targetAmount => goal.targetAmount;

  /// Amount remaining to reach the goal
  double get remainingAmount =>
      (targetAmount - currentAmount).clamp(0, double.infinity);

  /// Days until projected completion (null if can't calculate)
  int? get daysToProjectedCompletion {
    if (projectedCompletionDate == null) return null;
    return projectedCompletionDate!.difference(DateTime.now()).inDays;
  }

  /// Months until projected completion
  double? get monthsToProjectedCompletion {
    final days = daysToProjectedCompletion;
    if (days == null) return null;
    return days / 30.0;
  }

  /// Whether the goal is ahead of schedule (if has deadline)
  bool get isAheadOfSchedule {
    if (goal.targetDate == null || projectedCompletionDate == null) {
      return false;
    }
    return projectedCompletionDate!.isBefore(goal.targetDate!);
  }

  /// Whether the goal is behind schedule
  bool get isBehindSchedule {
    if (goal.targetDate == null || projectedCompletionDate == null) {
      return false;
    }
    return projectedCompletionDate!.isAfter(goal.targetDate!);
  }

  /// Progress message for display (with optional currency symbol and locale override)
  String getProgressMessage([String symbol = '₹', String locale = 'en_IN']) {
    if (status == GoalStatus.achieved) {
      return 'Congratulations! You\'ve reached your goal!';
    }
    if (goal.isIncomeGoal) {
      final target = goal.targetMonthlyIncome ?? goal.targetAmount;
      return '$symbol${_formatAmount(monthlyIncome, locale)}/mo of $symbol${_formatAmount(target, locale)}/mo';
    }
    return '$symbol${_formatAmount(currentAmount, locale)} of $symbol${_formatAmount(targetAmount, locale)}';
  }

  /// Progress message for display (default ₹, en_IN)
  String get progressMessage => getProgressMessage();

  /// Status message
  String get statusMessage {
    switch (status) {
      case GoalStatus.notStarted:
        return 'Start investing to make progress';
      case GoalStatus.onTrack:
        if (projectedCompletionDate != null) {
          return 'On track for ${_formatDate(projectedCompletionDate!)}';
        }
        return 'Making steady progress';
      case GoalStatus.ahead:
        return 'Ahead of schedule! Keep it up!';
      case GoalStatus.behind:
        if (goal.targetDate != null) {
          return 'Behind schedule - needs attention';
        }
        return 'Consider increasing contributions';
      case GoalStatus.achieved:
        return 'Goal achieved!';
      case GoalStatus.archived:
        return 'Goal archived';
    }
  }

  /// Formats amount using locale-aware compact notation (100K/1M for Western, 1L/1Cr for Indian)
  /// without the currency symbol prefix (symbol is added separately in getProgressMessage)
  String _formatAmount(double amount, String locale) {
    // Use locale-aware formatter but strip the symbol since we add it separately
    final formatted = formatCompactCurrency(
      amount,
      symbol: '',
      locale: locale,
    );
    return formatted;
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}
