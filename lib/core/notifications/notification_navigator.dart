/// Handles navigation from notification taps.
///
/// This class is responsible for:
/// - Parsing notification payloads
/// - Looking up investments by ID
/// - Navigating to the appropriate screen using GoRouter
library;

import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/notifications/notification_payload.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_transaction_screen.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/reports/domain/entities/report_configuration.dart';
import 'package:inv_tracker/features/reports/domain/entities/report_type.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Provider for the notification navigator
final notificationNavigatorProvider = Provider<NotificationNavigator>((ref) {
  final navigator = NotificationNavigator(ref);
  // A tap that arrived while the app was locked opens once it is unlocked.
  ref.listen<bool>(securityProvider.select((s) => s.isLocked), (
    wasLocked,
    isLocked,
  ) {
    if (wasLocked == true && !isLocked) {
      unawaited(navigator.replayAfterUnlock());
    }
  });
  return navigator;
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
    metadata: {'payloadLength': payload.length},
  );
}

/// Handles navigation from notification payloads
class NotificationNavigator {
  final Ref _ref;

  NotificationNavigator(this._ref);

  /// The latest tap that arrived while the app was locked, and who was
  /// signed in then.
  String? _pendingPayload;
  String? _pendingUserId;

  String? get _userId => _ref.read(authStateProvider).value?.id;

  /// Keeps [payload] for after unlock if the app is locked (or its lock
  /// state is not known yet). Returns true when it did.
  bool _deferIfLocked(String payload) {
    if (!_ref.read(securityProvider).isLocked) return false;
    _pendingPayload = payload;
    _pendingUserId = _userId;
    LoggerService.debug('Notification navigation deferred until unlock');
    return true;
  }

  /// Opens the screen a tap asked for while the app was locked. Dropped if
  /// someone else is signed in by now.
  Future<bool> replayAfterUnlock() async {
    final payload = _pendingPayload;
    final pendingUserId = _pendingUserId;
    _pendingPayload = null;
    _pendingUserId = null;
    // A tap made before sign-in resolved has no user; it is for whoever is
    // signed in now.
    final userId = _userId;
    if (payload == null || userId == null) return false;
    if (pendingUserId != null && pendingUserId != userId) return false;
    // Let the router built for the unlocked state take over first.
    await SchedulerBinding.instance.endOfFrame;
    // Someone else may have signed in during that frame.
    if (_userId != userId) return false;
    return handleNotificationTap(payload);
  }

  /// Handle a notification tap by navigating to the appropriate screen
  Future<bool> handleNotificationTap(String? payloadString) async {
    if (payloadString == null || payloadString.isEmpty) {
      return false;
    }
    if (_deferIfLocked(payloadString)) return false;

    final payload = NotificationPayload.parse(payloadString);
    LoggerService.debug(
      'Handling notification',
      metadata: {'type': payload.type.name},
    );

    switch (payload.type) {
      case NotificationPayloadType.investmentDetail:
        return _navigateToInvestmentDetail(payloadString, payload.investmentId);

      case NotificationPayloadType.addCashFlow:
        return _navigateToAddCashFlow(
          payloadString,
          payload.investmentId,
          payload.params,
        );

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

      case NotificationPayloadType.incomeGuardian:
        // Navigate to investment detail with expected cash flow highlighted
        return _navigateToInvestmentDetail(payloadString, payload.investmentId);

      case NotificationPayloadType.unknown:
        return false;
    }
  }

  Future<bool> _navigateToInvestmentDetail(
    String payloadString,
    String? investmentId,
  ) async {
    if (investmentId == null) return false;

    // Get BuildContext from navigator key
    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      LoggerService.warn('No context available for navigation');
      return false;
    }

    final userId = _userId;
    if (userId == null) return false;
    final investment = await _findInvestment(investmentId);
    // An investment loaded for one user is never shown to another.
    if (_userId != userId) return false;
    if (investment == null) {
      LoggerService.warn(
        'Investment not found for notification',
        metadata: {'investmentId': investmentId},
      );
      return false;
    }

    // The app may have locked while the investment loaded.
    if (_deferIfLocked(payloadString)) return false;
    if (!context.mounted) return false;

    // A route, so the lock redirect applies; the investment goes via extra.
    try {
      context.go(
        '/investments/${Uri.encodeComponent(investmentId)}',
        extra: investment,
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

  /// Builds the Add Cash Flow screen opened from a notification tap (the
  /// router's add-cash-flow route).
  static AddTransactionScreen addCashFlowScreen(
    String investmentId,
    Map<String, String> params,
  ) {
    // An income reminder sends flowType=income; preselect it so a payout is
    // not recorded as money invested.
    final flowType = params['flowType'];
    final initialType = CashFlowType.values
        .where((type) => type.name == flowType)
        .firstOrNull;
    return AddTransactionScreen(
      investmentId: investmentId,
      initialType: initialType,
    );
  }

  Future<bool> _navigateToAddCashFlow(
    String payloadString,
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
    final userId = _userId;
    if (userId == null) return false;
    final investment = await _findInvestment(investmentId);
    if (_userId != userId) return false;
    if (investment == null) return false;

    // The app may have locked while the investment loaded.
    if (_deferIfLocked(payloadString)) return false;
    if (!context.mounted) return false;

    // A reminder left in the shade outlives closing the investment on
    // another device. Never open add income for it without saying so.
    if (!investment.isOpen) {
      return _openClosedInvestment(context, investment);
    }

    // A route, so the lock redirect applies.
    final flowType = params['flowType'];
    final location = Uri(
      path: '/investments/${Uri.encodeComponent(investmentId)}/add-cash-flow',
      queryParameters: flowType == null ? null : {'flowType': flowType},
    );
    try {
      context.go(location.toString());
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

  /// Opens a closed [investment] with a note that it is closed, and cancels
  /// its income reminder so no more arrive.
  Future<bool> _openClosedInvestment(
    BuildContext context,
    InvestmentEntity investment,
  ) async {
    try {
      context.go(
        '/investments/${Uri.encodeComponent(investment.id)}',
        extra: investment,
      );
    } catch (e, stack) {
      LoggerService.error(
        'Failed to push investment detail screen',
        metadata: {'investmentId': investment.id},
        error: e,
        stackTrace: stack,
      );
      return false;
    }
    AppFeedback.showInfo(
      context,
      AppLocalizations.of(context).notificationInvestmentClosed,
    );

    try {
      await _ref
          .read(notificationServiceProvider)
          .cancelIncomeReminder(investment.id);
    } catch (e) {
      LoggerService.warn(
        'Could not cancel the income reminder of a closed investment',
        error: e,
      );
    }
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
      // One record per failure. An unknown report type is a
      // ValidationException, which LoggerService does not report.
      LoggerService.warn(
        'Failed to navigate to dynamic report',
        error: e,
        stackTrace: stack,
        metadata: {'reportType': reportTypeId},
      );
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
      // Wait for provider to finish loading (up to 10s for cold start)
      final investmentsAsync = _ref.read(allInvestmentsProvider);

      // If still loading, wait for data
      List<InvestmentEntity>? investments;
      if (investmentsAsync.isLoading) {
        // Cold start scenario - wait for data to load
        final completer = Completer<List<InvestmentEntity>?>();
        final subscription = _ref.listen(
          allInvestmentsProvider,
          (_, next) {
            if (!next.isLoading && !completer.isCompleted) {
              completer.complete(next.value);
            }
          },
        );

        try {
          investments = await completer.future.timeout(
            const Duration(seconds: 10),
            onTimeout: () => null,
          );
        } finally {
          subscription.close();
        }
      } else {
        investments = investmentsAsync.value;
      }

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
