/// Widget that initializes notification sync on app startup.
///
/// This widget listens to investment changes and re-schedules notifications
/// asynchronously with debouncing to avoid performance issues.
///
/// It ensures all devices get notifications scheduled, not just the device
/// that originally created the investment. It also clears every scheduled
/// notification when the signed-in account goes away (sign-out, account
/// deletion) or changes, so one user's reminders never reach the next.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/notifications/notification_settings_provider.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/digest/domain/monthly_digest.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_stats_provider.dart';

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

  /// Uid of the last signed-in user seen, to detect sign-out and switches.
  String? _signedInUid;

  ProviderSubscription<AsyncValue<UserEntity?>>? _authSubscription;

  /// Bumped on every account change. A reschedule started for an earlier
  /// account stops as soon as it sees the number move.
  int _accountGeneration = 0;

  /// Reschedules and clears run one after another through this chain, so
  /// clearing on sign-out always runs after an in-flight reschedule ends.
  Future<void> _notificationWork = Future<void>.value();

  /// Debounce duration to prevent rapid re-scheduling
  static const _debounceDuration = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _applyReportsRoute(_reportsRouteOn());
    // fireImmediately records the user who is already signed in when this
    // widget is built, so a later sign-out is detected.
    _authSubscription = ref.listenManual<AsyncValue<UserEntity?>>(
      authStateProvider,
      (previous, next) => _onAuthChanged(next),
      fireImmediately: true,
    );
  }

  bool _reportsRouteOn() {
    try {
      return ref.read(isReportsTabEnabledProvider);
    } catch (e) {
      return false;
    }
  }

  void _applyReportsRoute(bool enabled) {
    try {
      final notificationService = ref.read(notificationServiceProvider);
      notificationService.reportsRouteEnabled = enabled;
      _enqueue(() => notificationService.applyReportsRoute(enabled));
    } catch (e) {
      LoggerService.debug('NotificationService not available for reports');
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _authSubscription?.close();
    super.dispose();
  }

  /// Delay before initial notification scheduling to let UI settle
  static const _initialDelay = Duration(milliseconds: 500);

  void _onAuthChanged(AsyncValue<UserEntity?> next) {
    final data = next.asData;
    if (data == null) return; // Ignore loading and error states.

    final uid = data.value?.id;
    // After a restart, the persisted owner tells whose reminders are still
    // scheduled if the last sign-out was not cleared before the app stopped.
    final previousUid = _signedInUid ?? _persistedOwnerUid();
    _signedInUid = uid;

    if (previousUid != null && previousUid != uid) {
      _clearForAccountChange(signedInUid: uid);
    } else if (uid != null) {
      // Tax, check-in and FY reminders are scheduled here, after sign-in,
      // on every app start (idempotent) and after a sign-out cleared them.
      _restoreAppWideReminders();
      if (previousUid == null) _recordOwner(uid);
    }
  }

  String? _persistedOwnerUid() {
    try {
      return ref.read(notificationServiceProvider).remindersOwnerUid;
    } catch (e) {
      LoggerService.debug('NotificationService not available for owner');
      return null;
    }
  }

  /// Run [task] after every reschedule or clear queued before it.
  void _enqueue(Future<void> Function() task) {
    _notificationWork = _notificationWork.then((_) => task()).catchError((
      Object e,
    ) {
      LoggerService.warn('Error updating notifications', error: e);
    });
  }

  void _recordOwner(String uid) {
    try {
      final notificationService = ref.read(notificationServiceProvider);
      _enqueue(() => notificationService.setRemindersOwnerUid(uid));
    } catch (e) {
      LoggerService.debug('NotificationService not available for owner');
    }
  }

  /// Cancel every scheduled notification when the signed-in account goes
  /// away or changes, because reminders name the previous user's
  /// investments. Guest-to-Google linking keeps the uid and keeps them.
  ///
  /// The clear waits for any reschedule already running (which stops early
  /// because the generation moved), so nothing it schedules survives. The
  /// persisted owner is updated only after the clear, so if the app stops
  /// first the clear runs again on the next start.
  void _clearForAccountChange({required String? signedInUid}) {
    _debounceTimer?.cancel();
    _accountGeneration++;
    try {
      final notificationService = ref.read(notificationServiceProvider);
      _enqueue(() async {
        try {
          await notificationService.cancelAll();
          LoggerService.info('Notifications cleared after account change');
          await notificationService.setRemindersOwnerUid(signedInUid);
          if (signedInUid != null) {
            _applyBaseCurrency(notificationService);
            await notificationService.scheduleAppWideReminders();
          }
        } catch (e) {
          LoggerService.warn('Error clearing notifications', error: e);
        }
      });
    } catch (e) {
      LoggerService.debug('NotificationService not available for clearing');
    }
  }

  /// Tell the service the user's base currency; the India tax reminders are
  /// scheduled only for INR.
  void _applyBaseCurrency(NotificationService notificationService) {
    try {
      notificationService.baseCurrency = ref.read(currencyCodeProvider);
    } catch (e) {
      LoggerService.debug('Base currency not available for reminders');
    }
  }

  /// Schedule tax, check-in and FY reminders (after sign-in or sign-out).
  void _restoreAppWideReminders() {
    try {
      final notificationService = ref.read(notificationServiceProvider);
      _enqueue(() async {
        try {
          _applyBaseCurrency(notificationService);
          await notificationService.scheduleAppWideReminders();
        } catch (e) {
          LoggerService.warn('Error restoring app-wide reminders', error: e);
        }
      });
    } catch (e) {
      LoggerService.debug('NotificationService not available for restore');
    }
  }

  /// Schedule notifications asynchronously with debouncing.
  /// The latest investments and cash flows are read when the timer fires.
  void _scheduleNotificationsDebounced() {
    // Cancel any pending debounce
    _debounceTimer?.cancel();

    // If this is the first load, delay to let UI animations complete
    if (!_hasScheduledInitially) {
      _hasScheduledInitially = true;
      _debounceTimer = Timer(_initialDelay, _scheduleNotificationsAsync);
      return;
    }

    // For subsequent updates, debounce to avoid rapid re-scheduling
    _debounceTimer = Timer(_debounceDuration, _scheduleNotificationsAsync);
  }

  /// Fire-and-forget async notification scheduling
  void _scheduleNotificationsAsync() {
    final investments = ref.read(allInvestmentsProvider).value;
    // Never schedule while signed out; sign-out is handled by
    // _clearForAccountChange.
    if (investments == null || _signedInUid == null) return;
    if (investments.isEmpty) {
      // The last investment was deleted (here, on another device, by bulk
      // delete or by clearing sample data): drop its reminders, and refresh
      // a queued recap so it no longer counts them.
      _cancelInvestmentReminders();
      _scheduleRecap();
      return;
    }

    // Wait for cash flows so income reminders anchor on the last payout. If
    // they failed to load, fall back to each investment's start date.
    final cashFlows = ref.read(allCashFlowsStreamProvider);
    if (cashFlows.isLoading && !cashFlows.hasValue) return;
    final lastIncomeDates = _lastIncomeDates(cashFlows.value ?? const []);

    // Get notification service (might throw if not initialized yet)
    try {
      final notificationService = ref.read(notificationServiceProvider);
      final generation = _accountGeneration;
      bool isStale() => generation != _accountGeneration;
      final now = DateTime.now();
      final recap = _recapFacts(now);

      // Schedule in background - don't await, fire and forget
      _enqueue(() async {
        if (isStale()) return;
        try {
          await notificationService.rescheduleAllNotifications(
            investments,
            lastIncomeDates: lastIncomeDates,
            isCancelled: isStale,
          );
          if (recap != null && !isStale()) {
            await notificationService.scheduleMonthlyRecap(
              now: now,
              maturingNextMonth: recap.maturingNextMonth.length,
              needingValue: recap.needingValue.length,
            );
          }
        } catch (e) {
          LoggerService.warn('Error rescheduling notifications', error: e);
        }
      });
    } catch (e) {
      LoggerService.debug('NotificationService not available yet');
    }
  }

  void _cancelInvestmentReminders() {
    try {
      final notificationService = ref.read(notificationServiceProvider);
      final generation = _accountGeneration;
      _enqueue(() async {
        if (generation != _accountGeneration) return;
        try {
          await notificationService.cancelInvestmentReminders();
        } catch (e) {
          LoggerService.warn('Error cancelling investment reminders', error: e);
        }
      });
    } catch (e) {
      LoggerService.debug('NotificationService not available yet');
    }
  }

  /// Reschedule only the recap, with counts from the current investments.
  void _scheduleRecap() {
    try {
      final notificationService = ref.read(notificationServiceProvider);
      final generation = _accountGeneration;
      final now = DateTime.now();
      final recap = _recapFacts(now);
      if (recap == null) {
        // With the flag off, put the legacy summary back in the shared slot
        // so a queued recap never fires.
        if (!_recapFlagOn()) {
          _enqueue(() async {
            if (generation != _accountGeneration) return;
            try {
              await notificationService.scheduleMonthlySummary();
            } catch (e) {
              LoggerService.warn('Error scheduling monthly summary', error: e);
            }
          });
        }
        return;
      }
      _enqueue(() async {
        if (generation != _accountGeneration) return;
        try {
          await notificationService.scheduleMonthlyRecap(
            now: now,
            maturingNextMonth: recap.maturingNextMonth.length,
            needingValue: recap.needingValue.length,
          );
        } catch (e) {
          LoggerService.warn('Error scheduling monthly recap', error: e);
        }
      });
    } catch (e) {
      LoggerService.debug('NotificationService not available yet');
    }
  }

  /// This month's recap counts while the recap flag is on, or null. Only
  /// the counts reach the notification; the amounts are computed on tap.
  /// A failure here never stops the other reminders from being rescheduled.
  MonthlyDigest? _recapFacts(DateTime now) {
    try {
      if (!_recapFlagOn()) return null;
      final active = ref.read(activeInvestmentsProvider).value;
      if (active == null) return null;
      return _buildRecap(now, active);
    } catch (e) {
      LoggerService.warn('Monthly recap counts unavailable', error: e);
      return null;
    }
  }

  bool _recapFlagOn({bool watch = false}) {
    try {
      return watch
          ? ref.watch(isMonthlyRecapEnabledProvider)
          : ref.read(isMonthlyRecapEnabledProvider);
    } catch (_) {
      return false;
    }
  }

  MonthlyDigest _buildRecap(DateTime now, List<InvestmentEntity> active) =>
      MonthlyDigest.build(
        month: DigestMonth(now.year, now.month),
        baseCurrency: ref.read(currencyCodeProvider),
        convertedFlows: const [],
        activeInvestments: active,
        statsById:
            ref.read(activeInvestmentBasicStatsMapProvider).value ?? const {},
      );

  /// Latest INCOME cash-flow date per investment id.
  static Map<String, DateTime> _lastIncomeDates(List<CashFlowEntity> flows) {
    final result = <String, DateTime>{};
    for (final flow in flows) {
      if (flow.type != CashFlowType.income) continue;
      final current = result[flow.investmentId];
      if (current == null || flow.date.isAfter(current)) {
        result[flow.investmentId] = flow.date;
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    // Listen to investments and trigger async re-scheduling
    // Using ref.listen instead of ref.watch to avoid blocking builds
    ref.listen<AsyncValue<List<InvestmentEntity>>>(allInvestmentsProvider, (
      previous,
      next,
    ) {
      // Only process when data is available (not loading or error)
      next.whenData((investments) {
        if (investments.isNotEmpty) {
          _scheduleNotificationsDebounced();
          // User has investments, cancel activation nudges
          _cancelActivationSequenceIfNeeded();
        } else {
          // Cancels reminders left by a deleted last investment.
          _scheduleNotificationsDebounced();
          // User has no investments, schedule activation nudges for new users
          _scheduleActivationSequenceIfNeeded();
        }
      });
    });

    // Adding, editing or deleting a cash flow re-schedules too (an INCOME
    // flow moves the payout anchor), including changes from other devices.
    ref.listen<AsyncValue<List<CashFlowEntity>>>(allCashFlowsStreamProvider, (
      previous,
      next,
    ) {
      if (next.hasValue) _scheduleNotificationsDebounced();
    });

    // The monthly slot is shared with the recap, so a change also reschedules
    // everything, which puts the right monthly notification back.
    ref.listen<bool>(isReportsTabEnabledProvider, (previous, next) {
      _applyReportsRoute(next);
      _scheduleNotificationsDebounced();
    }, onError: (_, _) {});

    // The India tax reminders depend on the base currency.
    ref.listen<String>(currencyCodeProvider, (previous, next) {
      if (_signedInUid != null) _restoreAppWideReminders();
    }, onError: (_, _) {});

    // Turning income or maturity reminders back on schedules them again.
    // Turning them off cancels them in NotificationService.
    ref.listen<(bool, bool)>(
      notificationSettingsProvider.select(
        (s) => (s.incomeRemindersEnabled, s.maturityRemindersEnabled),
      ),
      (previous, next) => _scheduleNotificationsDebounced(),
    );

    // The monthly recap shares the monthly summary's slot. Turning the
    // summary back on, flipping the recap flag either way, or the stats
    // arriving after the first schedule all reschedule, so the slot holds
    // the right notification with current counts.
    ref.listen<bool>(
      notificationSettingsProvider.select((s) => s.monthlySummaryEnabled),
      (previous, next) {
        if (next) _scheduleNotificationsDebounced();
      },
    );
    ref.listen<bool>(
      isMonthlyRecapEnabledProvider,
      (previous, next) => _scheduleNotificationsDebounced(),
      onError: (_, _) {},
    );
    // Only while the recap is on, so the stats are not computed for nothing.
    if (_recapFlagOn(watch: true)) {
      ref.listen<bool>(
        activeInvestmentBasicStatsMapProvider.select((s) => s.hasValue),
        (previous, next) {
          if (next && previous == false) _scheduleNotificationsDebounced();
        },
        onError: (_, _) {},
      );
    }

    // Render child immediately without waiting for notifications
    return widget.child;
  }

  /// Schedule activation sequence for new users with no investments
  void _scheduleActivationSequenceIfNeeded() {
    if (_signedInUid == null) return;
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
            LoggerService.info(
              'New user detected - activation sequence scheduled',
            );
          } catch (e) {
            LoggerService.warn(
              'Error scheduling activation sequence',
              error: e,
            );
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
