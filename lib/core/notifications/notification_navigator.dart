/// Handles navigation from notification taps.
///
/// This class is responsible for:
/// - Parsing notification payloads
/// - Looking up investments by ID
/// - Navigating to the appropriate screen using GoRouter
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/notifications/notification_payload.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_transaction_screen.dart';
import 'package:inv_tracker/features/investment/presentation/screens/investment_detail_screen.dart';
import 'package:inv_tracker/features/reports/domain/entities/report_configuration.dart';
import 'package:inv_tracker/features/reports/domain/entities/report_type.dart';

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

      case NotificationPayloadType.dynamicReport:
        return _navigateToDynamicReport(payload.reportParams);

      case NotificationPayloadType.snooze:
        // Snooze is handled directly in notification service
        return false;

      case NotificationPayloadType.unknown:
        return false;
    }
  }

  Future<bool> _navigateToInvestmentDetail(
    String? investmentId,
    Map<String, String> params,
  ) async {
    if (investmentId == null) return false;

    // Get BuildContext from navigator key
    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      LoggerService.warn('No context available for navigation');
      return false;
    }

    final investment = await _findInvestment(investmentId);
    if (investment == null) {
      LoggerService.warn(
        'Investment not found for notification',
        metadata: {'investmentId': investmentId},
      );
      return false;
    }

    // Use GoRouter's navigation with investment entity passed via extra
    if (!context.mounted) return false;

    // Navigate to investments tab first, then push detail screen
    context.go('/investments');

    // Wait for frame to complete using deterministic frame-sync
    await SchedulerBinding.instance.endOfFrame;

    if (!context.mounted) return false;

    // Push investment detail using GoRouter's imperative navigation
    // Since we don't have a route defined for investment detail in GoRouter,
    // we need to use the root navigator to push it imperatively
    final navigatorState = rootNavigatorKey.currentState;
    if (navigatorState == null) {
      LoggerService.warn('Navigator state unavailable after tab navigation');
      return false;
    }

    try {
      navigatorState.push(
        MaterialPageRoute(
          builder: (ctx) => InvestmentDetailScreen(investment: investment),
        ),
      );
    } catch (e, stack) {
      LoggerService.error(
        'Failed to push investment detail screen',
        metadata: {'investmentId': investmentId},
        error: e,
        stackTrace: stack,
      );
      return false;
    }

    LoggerService.debug(
      'Navigated to investment detail',
      metadata: {'investmentId': investmentId},
    );
    return true;
  }

  Future<bool> _navigateToAddCashFlow(
    String? investmentId,
    Map<String, String> params,
  ) async {
    if (investmentId == null) return false;

    // Get BuildContext from navigator key
    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      LoggerService.warn('No context available for navigation');
      return false;
    }

    // Verify investment exists
    final investment = await _findInvestment(investmentId);
    if (investment == null) return false;

    // Navigate to investments tab first
    if (!context.mounted) return false;
    context.go('/investments');

    // Wait for frame to complete using deterministic frame-sync
    await SchedulerBinding.instance.endOfFrame;

    if (!context.mounted) return false;

    // Push add transaction screen
    final navigatorState = rootNavigatorKey.currentState;
    if (navigatorState == null) {
      LoggerService.warn('Navigator state unavailable after tab navigation');
      return false;
    }

    try {
      navigatorState.push(
        MaterialPageRoute(
          builder: (ctx) => AddTransactionScreen(investmentId: investmentId),
        ),
      );
    } catch (e, stack) {
      LoggerService.error(
        'Failed to push add transaction screen',
        metadata: {'investmentId': investmentId},
        error: e,
        stackTrace: stack,
      );
      return false;
    }

    LoggerService.debug(
      'Navigated to add cash flow',
      metadata: {'investmentId': investmentId},
    );
    return true;
  }

  Future<bool> _navigateToOverview() async {
    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      LoggerService.warn('No context available for navigation');
      return false;
    }

    // Navigate to overview tab (home screen)
    if (!context.mounted) return false;
    context.go('/');

    LoggerService.debug('Navigated to overview');
    return true;
  }

  Future<bool> _navigateToInvestmentList() async {
    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      LoggerService.warn('No context available for navigation');
      return false;
    }

    // Navigate to investments tab
    if (!context.mounted) return false;
    context.go('/investments');

    LoggerService.debug('Navigated to investment list');
    return true;
  }

  Future<bool> _navigateToGoalDetail(
    String? goalId,
    Map<String, String> params,
  ) async {
    if (goalId == null) return false;

    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      LoggerService.warn('No context available for navigation');
      return false;
    }

    // Navigate to goal detail using GoRouter path
    if (!context.mounted) return false;
    context.go('/goals/$goalId');

    LoggerService.debug(
      'Navigated to goal detail',
      metadata: {'goalId': goalId},
    );
    return true;
  }

  /// Navigate to a dynamic report based on notification parameters.
  ///
  /// Parses the report type from [reportParams] and creates the appropriate
  /// [ReportConfiguration] to display in [DynamicReportScreen].
  ///
  /// Returns `true` if navigation was successful, `false` otherwise.
  ///
  /// Throws [ValidationException] if the report type is unknown or invalid.
  Future<bool> _navigateToDynamicReport(Map<String, String> reportParams) async {
    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      LoggerService.warn('No context available for navigation');
      return false;
    }

    // Parse report type from params
    final reportTypeId = reportParams['reportType'];
    if (reportTypeId == null) {
      LoggerService.warn('Report type not specified in notification');
      return false;
    }

    try {
      // Map string report type to ReportType enum
      final reportType = _mapReportType(reportTypeId);

      // Create configuration from report params
      final config = _buildReportConfiguration(reportType, reportParams);

      // Convert configuration to query parameters
      final queryParams = config.toQueryParams();

      // Build the URI for the report
      final uri = Uri(path: '/reports/builder', queryParameters: queryParams);

      // Navigate using GoRouter
      if (!context.mounted) return false;
      context.push(uri.toString());

      LoggerService.debug(
        'Navigated to dynamic report',
        metadata: {'reportType': reportTypeId, 'navigation': 'success'},
      );
      return true;
    } catch (e, stack) {
      LoggerService.warn(
        'Failed to navigate to dynamic report',
        metadata: {'error': e.toString(), 'reportType': reportTypeId},
      );

      // Report non-validation errors to Crashlytics
      if (e is! ValidationException) {
        await CrashlyticsService(
          debugModeEnabled: CrashlyticsService.enableInDebugMode,
        ).recordError(
          e,
          stack,
          reason: 'notification_navigator._navigateToDynamicReport',
        );
      }
      return false;
    }
  }

  ReportType _mapReportType(String reportTypeId) {
    switch (reportTypeId) {
      case 'weekly_summary':
        return ReportType.weeklySummary;
      case 'monthly_summary':
        // Map to monthlyIncome (not weeklySummary) for monthly activity summary
        return ReportType.monthlyIncome;
      case 'monthly_income':
        return ReportType.monthlyIncome;
      case 'fy_summary':
        return ReportType.fyReport;
      case 'fy_report':
        return ReportType.fyReport;
      case 'performance':
        return ReportType.performance;
      case 'goal_progress':
        return ReportType.goalProgress;
      case 'maturity_calendar':
        return ReportType.maturityCalendar;
      case 'action_required':
        return ReportType.actionRequired;
      case 'portfolio_health':
        return ReportType.portfolioHealth;
      default:
        throw ValidationException(
          userMessage: 'Unknown report type in notification',
          technicalMessage: 'Unknown report type: $reportTypeId',
        );
    }
  }

  ReportConfiguration _buildReportConfiguration(
    ReportType reportType,
    Map<String, String> params,
  ) {
    // Create notification context if this is from a notification
    final notificationContext = params['notificationContext'] == 'true'
        ? NotificationContext(
            notificationType: reportType.id,
            timestamp: DateTime.now(),
            additionalData: params,
          )
        : null;

    switch (reportType) {
      case ReportType.weeklySummary:
        return ReportConfiguration.weeklySummary(
          notificationContext: notificationContext,
        );

      case ReportType.monthlyIncome:
        return ReportConfiguration.monthlyIncome(
          notificationContext: notificationContext,
        );

      case ReportType.fyReport:
        return ReportConfiguration.fyReport(
          notificationContext: notificationContext,
        );

      case ReportType.performance:
        return ReportConfiguration.performance(
          notificationContext: notificationContext,
        );

      case ReportType.goalProgress:
        final goalId = params['goalId'];
        final milestonePercent = params['milestonePercent'];
        return ReportConfiguration.goalProgress(
          goalId: goalId,
          milestonePercent: milestonePercent != null
            ? int.tryParse(milestonePercent)
            : null,
          notificationContext: notificationContext,
        );

      case ReportType.maturityCalendar:
        final investmentId = params['investmentId'];
        final daysParam = params['daysToMaturity'] ?? params['daysAhead'];
        return ReportConfiguration.maturityCalendar(
          investmentId: investmentId,
          daysToMaturity: daysParam != null ? int.tryParse(daysParam) : null,
          notificationContext: notificationContext,
        );

      case ReportType.actionRequired:
        return ReportConfiguration.actionRequired(
          notificationContext: notificationContext,
        );

      case ReportType.portfolioHealth:
        return ReportConfiguration.portfolioHealth(
          notificationContext: notificationContext,
        );
    }
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
}
