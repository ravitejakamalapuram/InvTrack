/// Income Guardian monitoring service for payment notifications.
///
/// This service:
/// - Monitors expected cash flows in real-time
/// - Triggers notifications for overdue and upcoming payments
/// - Runs once per app session when user is authenticated
/// - Respects user-configured notification timing preferences
library;

import 'dart:async';

import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/notifications/handlers/income_guardian_notification_handler.dart';
import 'package:inv_tracker/features/income_projection/domain/entities/expected_cash_flow_entity.dart';
import 'package:inv_tracker/features/income_projection/domain/repositories/expected_cash_flow_repository.dart';
import 'package:inv_tracker/features/income_projection/presentation/providers/income_guardian_settings_provider.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';

/// Income Guardian monitoring service
class IncomeGuardianMonitorService {
  final ExpectedCashFlowRepository _expectedCashFlowRepository;
  final InvestmentRepository _investmentRepository;
  final IncomeGuardianNotificationHandler _notificationHandler;
  final IncomeGuardianSettings _settings;
  final String _locale;

  StreamSubscription<List<ExpectedCashFlowEntity>>? _overdueSubscription;
  StreamSubscription<List<ExpectedCashFlowEntity>>? _upcomingSubscription;

  bool _isMonitoring = false;

  // Track which notifications were already shown to avoid duplicates
  final Set<String> _shownOverdueNotifications = {};
  final Set<String> _shownUpcomingNotifications = {};

  IncomeGuardianMonitorService({
    required ExpectedCashFlowRepository expectedCashFlowRepository,
    required InvestmentRepository investmentRepository,
    required IncomeGuardianNotificationHandler notificationHandler,
    required IncomeGuardianSettings settings,
    required String locale,
  })  : _expectedCashFlowRepository = expectedCashFlowRepository,
        _investmentRepository = investmentRepository,
        _notificationHandler = notificationHandler,
        _settings = settings,
        _locale = locale;

  /// Start monitoring expected cash flows
  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    // Check if monitoring is enabled in settings
    if (!_settings.enabled) {
      LoggerService.info('Income Guardian monitoring disabled in settings');
      return;
    }

    LoggerService.info(
      'Income Guardian monitoring started',
      metadata: {
        'upcomingDaysBefore': _settings.upcomingDaysBefore,
        'overdueDaysAfter': _settings.overdueDaysAfter,
      },
    );
    _isMonitoring = true;

    // Monitor overdue payments (using configured days after)
    _overdueSubscription = _expectedCashFlowRepository
        .watchOverdueExpectedCashFlows()
        .listen(_handleOverduePayments);

    // Monitor upcoming payments (using configured days before)
    _upcomingSubscription = _expectedCashFlowRepository
        .watchUpcomingExpectedCashFlows(days: _settings.upcomingDaysBefore)
        .listen(_handleUpcomingPayments);
  }

  /// Stop monitoring
  void stopMonitoring() {
    if (!_isMonitoring) return;

    LoggerService.info('Income Guardian monitoring stopped');
    _isMonitoring = false;

    _overdueSubscription?.cancel();
    _upcomingSubscription?.cancel();

    _shownOverdueNotifications.clear();
    _shownUpcomingNotifications.clear();
  }

  /// Handle overdue payments
  Future<void> _handleOverduePayments(
    List<ExpectedCashFlowEntity> overduePayments,
  ) async {
    for (final expectedCashFlow in overduePayments) {
      // Skip if notification already shown for this cash flow
      if (_shownOverdueNotifications.contains(expectedCashFlow.id)) continue;

      // Get investment details
      final investment = await _investmentRepository.getInvestmentById(
        expectedCashFlow.investmentId,
      );

      if (investment == null) continue;

      // Show notification
      await _notificationHandler.showOverduePaymentNotification(
        expectedCashFlow: expectedCashFlow,
        investmentName: investment.name,
        currency: expectedCashFlow.currency,
        locale: _locale,
      );

      // Mark as shown
      _shownOverdueNotifications.add(expectedCashFlow.id);

      LoggerService.info(
        'Overdue payment notification triggered',
        metadata: {
          'investmentId': expectedCashFlow.investmentId,
          'expectedCashFlowId': expectedCashFlow.id,
          'daysOverdue': expectedCashFlow.daysOverdue,
        },
      );
    }
  }

  /// Handle upcoming payments (1 day before)
  Future<void> _handleUpcomingPayments(
    List<ExpectedCashFlowEntity> upcomingPayments,
  ) async {
    for (final expectedCashFlow in upcomingPayments) {
      // Skip if notification already shown for this cash flow
      if (_shownUpcomingNotifications.contains(expectedCashFlow.id)) continue;

      // Get investment details
      final investment = await _investmentRepository.getInvestmentById(
        expectedCashFlow.investmentId,
      );

      if (investment == null) continue;

      // Show notification
      await _notificationHandler.showUpcomingPaymentReminder(
        expectedCashFlow: expectedCashFlow,
        investmentName: investment.name,
        currency: expectedCashFlow.currency,
        locale: _locale,
      );

      // Mark as shown
      _shownUpcomingNotifications.add(expectedCashFlow.id);

      LoggerService.info(
        'Upcoming payment reminder triggered',
        metadata: {
          'investmentId': expectedCashFlow.investmentId,
          'expectedCashFlowId': expectedCashFlow.id,
        },
      );
    }
  }
}
