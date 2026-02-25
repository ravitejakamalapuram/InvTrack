/// Widget that initializes notification sync on app startup.
///
/// This widget listens to investment changes and re-schedules notifications
/// asynchronously with debouncing to avoid performance issues.
///
/// It ensures all devices get notifications scheduled, not just the device
/// that originally created the investment.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';

/// A widget that initializes notification sync in the background.
///
/// Wraps the app and listens to investment changes, re-scheduling
/// notifications with debouncing to prevent performance issues.
class NotificationSyncInitializer extends ConsumerStatefulWidget {
  final Widget child;

  const NotificationSyncInitializer({super.key, required this.child});

  @override
  ConsumerState<NotificationSyncInitializer> createState() =>
      _NotificationSyncInitializerState();
}

class _NotificationSyncInitializerState
    extends ConsumerState<NotificationSyncInitializer> {
  Timer? _debounceTimer;
  bool _hasScheduledInitially = false;

  /// Debounce duration to prevent rapid re-scheduling
  static const _debounceDuration = Duration(seconds: 2);

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Delay before initial notification scheduling to let UI settle
  static const _initialDelay = Duration(milliseconds: 500);

  /// Schedule notifications asynchronously with debouncing
  void _scheduleNotificationsDebounced(List<InvestmentEntity> investments) {
    // Cancel any pending debounce
    _debounceTimer?.cancel();

    // If this is the first load, delay to let UI animations complete
    if (!_hasScheduledInitially) {
      _hasScheduledInitially = true;
      _debounceTimer = Timer(_initialDelay, () {
        _scheduleNotificationsAsync(investments);
      });
      return;
    }

    // For subsequent updates, debounce to avoid rapid re-scheduling
    _debounceTimer = Timer(_debounceDuration, () {
      _scheduleNotificationsAsync(investments);
    });
  }

  /// Fire-and-forget async notification scheduling
  void _scheduleNotificationsAsync(List<InvestmentEntity> investments) {
    // Get notification service (might throw if not initialized yet)
    try {
      final notificationService = ref.read(notificationServiceProvider);

      // Schedule in background - don't await, fire and forget
      Future(() async {
        try {
          await notificationService.rescheduleAllNotifications(investments);
        } catch (e) {
          LoggerService.warn('Error rescheduling notifications', error: e);
        }
      });
    } catch (e) {
      LoggerService.debug('NotificationService not available yet');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to investments and trigger async re-scheduling
    // Using ref.listen instead of ref.watch to avoid blocking builds
    ref.listen<AsyncValue<List<InvestmentEntity>>>(allInvestmentsProvider, (
      previous,
      next,
    ) {
      // Only process when data is available
      final investments = next.value;
      if (investments != null) {
        if (investments.isNotEmpty) {
          _scheduleNotificationsDebounced(investments);
          // User has investments, cancel activation nudges
          _cancelActivationSequenceIfNeeded();
        } else {
          // User has no investments, schedule activation nudges for new users
          _scheduleActivationSequenceIfNeeded();
        }
      }
    });

    // Render child immediately without waiting for notifications
    return widget.child;
  }

  /// Schedule activation sequence for new users with no investments
  void _scheduleActivationSequenceIfNeeded() {
    try {
      final notificationService = ref.read(notificationServiceProvider);

      // Only schedule if this is a new user (no signup date set yet)
      if (notificationService.userSignupDate == null) {
        Future(() async {
          try {
            // Set signup date to now
            await notificationService.setUserSignupDate(DateTime.now());
            // Schedule the activation notification sequence
            await notificationService.scheduleActivationSequence();
            LoggerService.info('New user detected - activation sequence scheduled');
          } catch (e) {
            LoggerService.warn('Error scheduling activation sequence', error: e);
          }
        });
      }
    } catch (e) {
      LoggerService.debug('NotificationService not available for activation');
    }
  }

  /// Cancel activation sequence when user adds investments
  void _cancelActivationSequenceIfNeeded() {
    try {
      final notificationService = ref.read(notificationServiceProvider);

      // Cancel any pending activation notifications
      Future(() async {
        try {
          await notificationService.cancelActivationSequence();
        } catch (e) {
          LoggerService.warn('Error cancelling activation sequence', error: e);
        }
      });
    } catch (e) {
      LoggerService.debug('NotificationService not available for cancellation');
    }
  }
}
