/// Action Required Report Entity
///
/// Aggregates actionable items requiring user attention
library;

import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';

/// Priority level for action items
enum ActionPriority {
  critical, // Requires immediate attention
  high, // Should be addressed soon
  medium, // Can be addressed this week
  low; // For awareness

  String get displayName {
    switch (this) {
      case ActionPriority.critical:
        return 'Critical';
      case ActionPriority.high:
        return 'High';
      case ActionPriority.medium:
        return 'Medium';
      case ActionPriority.low:
        return 'Low';
    }
  }
}

/// Type of action required
enum ActionType {
  maturity, // Investment maturing soon
  idle, // No activity for 90+ days
  goalAtRisk, // Goal behind schedule
  taxDeadline, // Upcoming tax deadline
  underperforming; // Investment underperforming

  String get displayName {
    switch (this) {
      case ActionType.maturity:
        return 'Maturity Due';
      case ActionType.idle:
        return 'Idle Investment';
      case ActionType.goalAtRisk:
        return 'Goal At Risk';
      case ActionType.taxDeadline:
        return 'Tax Deadline';
      case ActionType.underperforming:
        return 'Underperforming';
    }
  }
}

/// Single action item
class ActionItem {
  final ActionType type;
  final ActionPriority priority;
  final String title;
  final String description;
  final DateTime? dueDate;
  final InvestmentEntity? investment;
  final GoalEntity? goal;

  const ActionItem({
    required this.type,
    required this.priority,
    required this.title,
    required this.description,
    this.dueDate,
    this.investment,
    this.goal,
  });

  /// Days until action is due (negative if overdue)
  int? get daysUntilDue {
    if (dueDate == null) return null;
    return dueDate!.difference(DateTime.now()).inDays;
  }

  /// Whether this action is overdue
  bool get isOverdue {
    final days = daysUntilDue;
    return days != null && days < 0;
  }
}

/// Action Required Report
class ActionRequiredReport {
  final List<ActionItem> criticalActions;
  final List<ActionItem> highPriorityActions;
  final List<ActionItem> mediumPriorityActions;
  final List<ActionItem> lowPriorityActions;
  final int totalActions;
  final int overdueActions;

  const ActionRequiredReport({
    required this.criticalActions,
    required this.highPriorityActions,
    required this.mediumPriorityActions,
    required this.lowPriorityActions,
    required this.totalActions,
    required this.overdueActions,
  });

  /// Get all actions sorted by priority
  List<ActionItem> get allActions => [
        ...criticalActions,
        ...highPriorityActions,
        ...mediumPriorityActions,
        ...lowPriorityActions,
      ];

  /// Whether there are any critical or high priority actions
  bool get hasUrgentActions =>
      criticalActions.isNotEmpty || highPriorityActions.isNotEmpty;

  /// Whether there are no actions
  bool get isEmpty => totalActions == 0;
}
