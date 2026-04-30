/// Action Required Service
///
/// Generates action items requiring user attention
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/reports/domain/entities/action_required_report.dart';

/// Provider for action required service
final actionRequiredServiceProvider = Provider<ActionRequiredService>((ref) {
  return ActionRequiredService();
});

/// Service for generating action required reports
class ActionRequiredService {
  /// Generate action required report
  ActionRequiredReport generateReport({
    required List<InvestmentEntity> investments,
    required List<CashFlowEntity> cashFlows,
    required List<GoalEntity> goals,
  }) {
    final now = DateTime.now();
    final actions = <ActionItem>[];

    // 1. Check for upcoming maturities (within 30 days)
    for (final investment in investments) {
      if (investment.maturityDate == null) continue;
      if (investment.status == InvestmentStatus.closed) continue;

      final daysUntilMaturity =
          investment.maturityDate!.difference(now).inDays;

      if (daysUntilMaturity < 0) {
        // Overdue maturity
        actions.add(ActionItem(
          type: ActionType.maturity,
          priority: ActionPriority.critical,
          title: '${investment.name} - Maturity Overdue',
          description:
              'Investment matured ${-daysUntilMaturity} days ago. Take action to close or renew.',
          dueDate: investment.maturityDate,
          investment: investment,
        ));
      } else if (daysUntilMaturity <= 7) {
        // Critical: Maturing within 7 days
        actions.add(ActionItem(
          type: ActionType.maturity,
          priority: ActionPriority.critical,
          title: '${investment.name} - Maturing in $daysUntilMaturity days',
          description: 'Plan for reinvestment or withdrawal.',
          dueDate: investment.maturityDate,
          investment: investment,
        ));
      } else if (daysUntilMaturity <= 30) {
        // High: Maturing within 30 days
        actions.add(ActionItem(
          type: ActionType.maturity,
          priority: ActionPriority.high,
          title: '${investment.name} - Maturing soon',
          description: 'Review renewal options or explore alternatives.',
          dueDate: investment.maturityDate,
          investment: investment,
        ));
      }
    }

    // 2. Check for idle investments (no activity for 90+ days)
    final cashFlowsByInvestment = <String, List<CashFlowEntity>>{};
    for (final cf in cashFlows) {
      cashFlowsByInvestment.putIfAbsent(cf.investmentId, () => []).add(cf);
    }

    for (final investment in investments) {
      if (investment.status == InvestmentStatus.closed) continue;

      final flows = cashFlowsByInvestment[investment.id] ?? [];
      if (flows.isEmpty) continue;

      // Get most recent cash flow
      flows.sort((a, b) => b.date.compareTo(a.date));
      final daysSinceLastActivity = now.difference(flows.first.date).inDays;

      if (daysSinceLastActivity >= 180) {
        // Critical: No activity for 6+ months
        actions.add(ActionItem(
          type: ActionType.idle,
          priority: ActionPriority.high,
          title: '${investment.name} - Idle for ${(daysSinceLastActivity / 30).floor()} months',
          description: 'Consider reviewing or updating this investment.',
          investment: investment,
        ));
      } else if (daysSinceLastActivity >= 90) {
        // Medium: No activity for 3+ months
        actions.add(ActionItem(
          type: ActionType.idle,
          priority: ActionPriority.medium,
          title: '${investment.name} - No activity for 90+ days',
          description: 'Check if this investment needs attention.',
          investment: investment,
        ));
      }
    }

    // 3. Check for at-risk goals
    for (final goal in goals) {
      if (goal.isArchived) continue;

      final targetDate = goal.targetDate;
      if (targetDate == null) continue; // No deadline to track

      final daysRemaining = targetDate.difference(now).inDays;

      // Skip if deadline already passed or goal is completed
      if (daysRemaining < 0) continue;

      // Note: We can't calculate actual progress without linked investments
      // For now, show goals approaching deadline as action items
      if (daysRemaining <= 30) {
        actions.add(ActionItem(
          type: ActionType.goalAtRisk,
          priority: ActionPriority.critical,
          title: '${goal.name} - Deadline approaching',
          description: 'Goal deadline in $daysRemaining days. Review progress.',
          dueDate: targetDate,
          goal: goal,
        ));
      } else if (daysRemaining <= 90) {
        actions.add(ActionItem(
          type: ActionType.goalAtRisk,
          priority: ActionPriority.high,
          title: '${goal.name} - Deadline in 90 days',
          description: 'Review goal progress and adjust if needed.',
          dueDate: targetDate,
          goal: goal,
        ));
      }
    }

    // 4. Add tax reminders (India FY: April-March)
    final currentFY = now.month >= 4 ? now.year : now.year - 1;
    final taxDeadline = DateTime(currentFY + 1, 7, 31); // July 31
    final daysUntilTax = taxDeadline.difference(now).inDays;

    if (daysUntilTax > 0 && daysUntilTax <= 90) {
      actions.add(ActionItem(
        type: ActionType.taxDeadline,
        priority: daysUntilTax <= 30
            ? ActionPriority.critical
            : ActionPriority.high,
        title: 'ITR Filing Deadline - FY $currentFY-${currentFY + 1}',
        description:
            'File income tax return by July 31. $daysUntilTax days remaining.',
        dueDate: taxDeadline,
      ));
    }

    // Optimization: Single pass loop for categorizing actions and counting overdue items
    // replacing multiple sequential .where().toList() and .where().length calls
    final critical = <ActionItem>[];
    final high = <ActionItem>[];
    final medium = <ActionItem>[];
    final low = <ActionItem>[];
    int overdue = 0;

    for (final a in actions) {
      if (a.isOverdue) overdue++;
      switch (a.priority) {
        case ActionPriority.critical:
          critical.add(a);
          break;
        case ActionPriority.high:
          high.add(a);
          break;
        case ActionPriority.medium:
          medium.add(a);
          break;
        case ActionPriority.low:
          low.add(a);
          break;
      }
    }

    return ActionRequiredReport(
      criticalActions: critical,
      highPriorityActions: high,
      mediumPriorityActions: medium,
      lowPriorityActions: low,
      totalActions: actions.length,
      overdueActions: overdue,
    );
  }
}
