/// Handles navigation from notification taps.
///
/// This class is responsible for:
/// - Parsing notification payloads
/// - Looking up investments by ID
/// - Navigating to the appropriate screen
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/notifications/notification_payload.dart';
import 'package:inv_tracker/features/goals/presentation/screens/goal_details_screen.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_transaction_screen.dart';
import 'package:inv_tracker/features/investment/presentation/screens/investment_detail_screen.dart';

/// Global navigator key for notification navigation
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Provider for the notification navigator
final notificationNavigatorProvider = Provider<NotificationNavigator>((ref) {
  return NotificationNavigator(ref);
});

/// Stream controller for pending navigation (when app is opened from notification)
final _pendingNavigationController = StreamController<String>.broadcast();

/// Stream of pending navigation payloads
Stream<String> get pendingNavigationStream =>
    _pendingNavigationController.stream;

/// Queue a navigation for when the app is ready
void queueNotificationNavigation(String payload) {
  _pendingNavigationController.add(payload);
  LoggerService.debug(
    'Queued notification navigation',
    metadata: {'payload': payload},
  );
}

/// Handles navigation from notification payloads
class NotificationNavigator {
  final Ref _ref;

  NotificationNavigator(this._ref);

  /// Handle a notification tap by navigating to the appropriate screen
  Future<bool> handleNotificationTap(String? payloadString) async {
    if (payloadString == null || payloadString.isEmpty) {
      return false;
    }

    final payload = NotificationPayload.parse(payloadString);
    LoggerService.debug(
      'Handling notification',
      metadata: {'payload': payload.toString()},
    );

    switch (payload.type) {
      case NotificationPayloadType.investmentDetail:
        return _navigateToInvestmentDetail(
          payload.investmentId,
          payload.params,
        );

      case NotificationPayloadType.addCashFlow:
        return _navigateToAddCashFlow(payload.investmentId, payload.params);

      case NotificationPayloadType.overview:
        return _navigateToOverview();

      case NotificationPayloadType.investmentList:
        return _navigateToInvestmentList();

      case NotificationPayloadType.goalDetail:
        return _navigateToGoalDetail(payload.goalId, payload.params);

      case NotificationPayloadType.snooze:
        // Snooze is handled directly in notification service
        return false;

      case NotificationPayloadType.unknown:
        return false;

      // ============ Notification Report Screens ============

      case NotificationPayloadType.weeklySummaryReport:
        return _navigateToWeeklySummaryReport();

      case NotificationPayloadType.monthlySummaryReport:
        return _navigateToMonthlySummaryReport();

      case NotificationPayloadType.maturityReport:
        return _navigateToMaturityReport(payload.investmentId, payload.params);

      case NotificationPayloadType.incomeReport:
        return _navigateToIncomeReport(payload.investmentId);

      case NotificationPayloadType.milestoneReport:
        return _navigateToMilestoneReport(
          payload.investmentId,
          payload.params,
        );

      case NotificationPayloadType.goalMilestoneReport:
        return _navigateToGoalMilestoneReport(payload.goalId, payload.params);

      case NotificationPayloadType.goalAtRiskReport:
        return _navigateToGoalAtRiskReport(payload.goalId);

      case NotificationPayloadType.goalStaleReport:
        return _navigateToGoalStaleReport(payload.goalId, payload.params);

      case NotificationPayloadType.riskAlertReport:
        return _navigateToRiskAlertReport();

      case NotificationPayloadType.idleAlertReport:
        return _navigateToIdleAlertReport(
          payload.investmentId,
          payload.params,
        );

      case NotificationPayloadType.fySummaryReport:
        return _navigateToFYSummaryReport();
    }
  }

  Future<bool> _navigateToInvestmentDetail(
    String? investmentId,
    Map<String, String> params,
  ) async {
    if (investmentId == null) return false;

    // Capture navigator state before async operation
    final navigatorState = rootNavigatorKey.currentState;
    if (navigatorState == null) return false;

    final investment = await _findInvestment(investmentId);
    if (investment == null) {
      LoggerService.warn(
        'Investment not found for notification',
        metadata: {'investmentId': investmentId},
      );
      return false;
    }

    navigatorState.push(
      MaterialPageRoute(
        builder: (context) => InvestmentDetailScreen(investment: investment),
      ),
    );
    return true;
  }

  Future<bool> _navigateToAddCashFlow(
    String? investmentId,
    Map<String, String> params,
  ) async {
    if (investmentId == null) return false;

    // Capture navigator state before async operation
    final navigatorState = rootNavigatorKey.currentState;
    if (navigatorState == null) return false;

    // Verify investment exists
    final investment = await _findInvestment(investmentId);
    if (investment == null) return false;

    navigatorState.push(
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(investmentId: investmentId),
      ),
    );
    return true;
  }

  Future<bool> _navigateToOverview() async {
    // Overview is the home screen, so we just need to ensure we're there
    // For now, just return true - the app opens to overview by default
    return true;
  }

  Future<bool> _navigateToInvestmentList() async {
    // Navigate to investments tab (tab index 1 in HomeShellScreen)
    // Since we use StatefulShellRoute, we can use GoRouter to navigate
    final navigatorState = rootNavigatorKey.currentState;
    if (navigatorState == null) return false;

    // Pop to root first, then the shell will handle showing the investments tab
    navigatorState.popUntil((route) => route.isFirst);

    // Note: The user will be on the home screen. For deep tab navigation,
    // GoRouter's StatefulShellRoute requires context access. The user can
    // tap the Investments tab manually after landing on the app.
    // Full implementation would require passing a GoRouter context here.
    return true;
  }

  Future<bool> _navigateToGoalDetail(
    String? goalId,
    Map<String, String> params,
  ) async {
    if (goalId == null) return false;

    final navigatorState = rootNavigatorKey.currentState;
    if (navigatorState == null) return false;

    navigatorState.push(
      MaterialPageRoute(
        builder: (context) => GoalDetailsScreen(goalId: goalId),
      ),
    );

    LoggerService.debug(
      'Navigated to goal detail',
      metadata: {'goalId': goalId},
    );
    return true;
  }

  Future<InvestmentEntity?> _findInvestment(String investmentId) async {
    try {
      final investmentsAsync = _ref.read(allInvestmentsProvider);
      final investments = investmentsAsync.value;
      if (investments == null) return null;

      return investments.cast<InvestmentEntity?>().firstWhere(
        (inv) => inv?.id == investmentId,
        orElse: () => null,
      );
    } catch (e) {
      LoggerService.warn(
        'Error finding investment',
        metadata: {'error': e.toString()},
      );
      return null;
    }
  }

  // ============ Notification Report Navigation Methods ============

  Future<bool> _navigateToWeeklySummaryReport() async {
    rootNavigatorKey.currentContext?.push('/reports/weekly');
    return true;
  }

  Future<bool> _navigateToMonthlySummaryReport() async {
    rootNavigatorKey.currentContext?.push('/reports/monthly');
    return true;
  }

  Future<bool> _navigateToMaturityReport(
    String? investmentId,
    Map<String, String> params,
  ) async {
    if (investmentId == null) return false;
    final daysToMaturity = params['daysToMaturity'] ?? '0';
    rootNavigatorKey.currentContext?.push(
      '/reports/maturity/$investmentId?daysToMaturity=$daysToMaturity',
    );
    return true;
  }

  Future<bool> _navigateToIncomeReport(String? investmentId) async {
    if (investmentId == null) return false;
    rootNavigatorKey.currentContext?.push('/reports/income/$investmentId');
    return true;
  }

  Future<bool> _navigateToMilestoneReport(
    String? investmentId,
    Map<String, String> params,
  ) async {
    if (investmentId == null) return false;
    final milestonePercent = params['milestonePercent'] ?? '0';
    rootNavigatorKey.currentContext?.push(
      '/reports/milestone/$investmentId?milestonePercent=$milestonePercent',
    );
    return true;
  }

  Future<bool> _navigateToGoalMilestoneReport(
    String? goalId,
    Map<String, String> params,
  ) async {
    if (goalId == null) return false;
    final milestonePercent = params['milestonePercent'] ?? '0';
    rootNavigatorKey.currentContext?.push(
      '/reports/goal-milestone/$goalId?milestonePercent=$milestonePercent',
    );
    return true;
  }

  Future<bool> _navigateToGoalAtRiskReport(String? goalId) async {
    if (goalId == null) return false;
    rootNavigatorKey.currentContext?.push('/reports/goal-at-risk/$goalId');
    return true;
  }

  Future<bool> _navigateToGoalStaleReport(
    String? goalId,
    Map<String, String> params,
  ) async {
    if (goalId == null) return false;
    final daysSinceActivity = params['daysSinceActivity'] ?? '0';
    rootNavigatorKey.currentContext?.push(
      '/reports/goal-stale/$goalId?daysSinceActivity=$daysSinceActivity',
    );
    return true;
  }

  Future<bool> _navigateToRiskAlertReport() async {
    rootNavigatorKey.currentContext?.push('/reports/risk-alert');
    return true;
  }

  Future<bool> _navigateToIdleAlertReport(
    String? investmentId,
    Map<String, String> params,
  ) async {
    if (investmentId == null) return false;
    final daysSinceActivity = params['daysSinceActivity'] ?? '0';
    rootNavigatorKey.currentContext?.push(
      '/reports/idle/$investmentId?daysSinceActivity=$daysSinceActivity',
    );
    return true;
  }

  Future<bool> _navigateToFYSummaryReport() async {
    rootNavigatorKey.currentContext?.push('/reports/fy-summary');
    return true;
  }
}
