import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/data/services/usd_tag_repair_service.dart';
import 'package:inv_tracker/features/settings/presentation/providers/currency_switch_provider.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/usd_tag_repair_actions.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/usd_tag_repair_dialog.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

export 'usd_tag_repair_actions.dart' show undoUsdTagRepair, usdTagRepairEvent;
export 'usd_tag_repair_undo_tile.dart' show UsdTagRepairUndoTile;

/// Users asked the US dollar question in this app session (process
/// lifetime), so signing out and in again does not ask twice.
final usdTagRepairPromptedUsersProvider = Provider<Set<String>>(
  (ref) => <String>{},
);

/// Asks once per signed-in user whether investments that older versions
/// stored as US dollars by mistake (merge, CSV import, restore) were really
/// in the base currency, and relabels only the ones the user ticks (A04).
///
/// Nothing is written without the user's answer. The question waits until
/// the question about records without a currency (A03-F1) is settled and
/// is never shown over a running base-currency change. If the base currency
/// or the signed-in user changes during the check or while the question is
/// open, nothing is written or recorded. Offline, a failed change or closing
/// the question without an answer asks again on the next start.
class UsdTagRepairInitializer extends ConsumerStatefulWidget {
  const UsdTagRepairInitializer({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UsdTagRepairInitializer> createState() =>
      _UsdTagRepairInitializerState();
}

class _UsdTagRepairInitializerState
    extends ConsumerState<UsdTagRepairInitializer> {
  String? _handledUserId;
  Completer<bool>? _unlocked;

  @override
  void initState() {
    super.initState();
    ref.listenManual<UsdTagRepairService?>(usdTagRepairServiceProvider, (
      _,
      service,
    ) {
      if (service == null) {
        _handledUserId = null;
        return;
      }
      if (service.userId == _handledUserId) return;
      _handledUserId = service.userId;
      unawaited(_run(service));
    }, fireImmediately: true);
  }

  Future<void> _run(UsdTagRepairService service) async {
    if (service.isResolved) return;
    final currency = ref.read(currencyCodeProvider);
    // USD-based users have nothing to repair. Not recorded, so a later
    // change to another base currency still checks.
    if (currency == UsdTagRepairService.taggedCurrency) return;
    if (!await _legacyQuestionSettled(service, currency)) return;
    final askedThisSession = ref.read(usdTagRepairPromptedUsersProvider);
    if (askedThisSession.contains(service.userId)) return;

    final List<UsdTagCandidate> candidates;
    try {
      // Answered on another device or before a reinstall.
      if (await service.checkResolved()) return;
      candidates = await service.findCandidates(currency);
    } catch (e) {
      LoggerService.warn(
        'USD tag check did not finish; will retry',
        metadata: {'errorType': e.runtimeType.toString()},
      );
      return;
    }
    if (!_stillCurrent(service, currency)) return;
    if (candidates.isEmpty) {
      await service.markResolved();
      return;
    }
    // The question lists investment names, so it never opens over the lock
    // screen; it waits until the app is unlocked.
    if (!await _waitUntilUnlocked() || !_stillCurrent(service, currency)) {
      return;
    }
    if (ref.read(currencySwitchProvider).isBusy) return;

    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    if (!askedThisSession.add(service.userId)) return;
    final analytics = readUsdTagRepairAnalytics(ref);
    logUsdTagRepair(analytics, {
      'action': 'prompted',
      'flagged': candidates.length,
      'fixed': 0,
    });
    final selected = await showDialog<Set<String>>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) =>
          UsdTagRepairDialog(candidates: candidates, currency: currency),
    );
    // Whoever answered must still be the user asked, and the currency they
    // saw must still be the base currency. Otherwise nothing is recorded and
    // a later start asks again.
    if (selected == null || !_stillCurrent(service, currency)) return;
    if (selected.isEmpty) {
      await service.markResolved();
      logUsdTagRepair(analytics, {
        'action': 'kept',
        'flagged': candidates.length,
        'fixed': 0,
      });
      return;
    }

    try {
      await service.repair(selected, currency);
    } catch (e) {
      LoggerService.warn(
        'USD tag repair did not finish; will ask again',
        metadata: {'errorType': e.runtimeType.toString()},
      );
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        AppFeedback.showError(ctx, AppLocalizations.of(ctx).usdTagRepairFailed);
      }
      return;
    }
    // What was really changed: the re-scan skips investments changed
    // elsewhere since the question opened. Undo puts back the same set.
    final changed = service.backedUpInvestmentCount;
    logUsdTagRepair(analytics, {
      'action': 'fixed',
      'flagged': candidates.length,
      'fixed': changed,
    });
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    final l10n = AppLocalizations.of(ctx);
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(l10n.usdTagRepairDone(changed, currency)),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: l10n.usdTagRepairUndo,
          onPressed: () {
            // Only for the user who made the change.
            if (!mounted ||
                ref.read(usdTagRepairServiceProvider)?.userId !=
                    service.userId) {
              return;
            }
            unawaited(undoUsdTagRepair(ctx, service, analytics));
          },
        ),
      ),
    );
  }

  /// Whether the question about records without a currency (A03-F1) cannot
  /// be asked now, so this one may go ahead. That question goes first: when
  /// it may still be asked, waits for its check (shared with it, so the
  /// server is read once) and, if records without a currency were found,
  /// leaves this question for a later start. False too when the check fails
  /// (offline), so the next start tries again.
  Future<bool> _legacyQuestionSettled(
    UsdTagRepairService service,
    String currency,
  ) async {
    final legacy = ref.read(legacyCurrencyBackfillServiceProvider);
    if (legacy == null ||
        legacy.userId != service.userId ||
        legacy.isComplete ||
        legacy.isConfirmedFor(currency) ||
        !legacy.mayPromptAtStart) {
      return true;
    }
    try {
      return !await legacy.hasUnstampedRecords();
    } catch (e) {
      LoggerService.warn(
        'Legacy currency check did not finish; USD tag check will retry',
        metadata: {'errorType': e.runtimeType.toString()},
      );
      return false;
    }
  }

  /// Completes with true once the app is not locked, or false if this
  /// widget goes away first.
  Future<bool> _waitUntilUnlocked() async {
    if (!ref.read(securityProvider).isLocked) return true;
    final unlocked = _unlocked = Completer<bool>();
    final sub = ref.listenManual<bool>(
      securityProvider.select((s) => s.isLocked),
      (_, isLocked) {
        if (!isLocked && !unlocked.isCompleted) unlocked.complete(true);
      },
    );
    try {
      return await unlocked.future;
    } finally {
      // After dispose the subscription is already closed with the widget.
      if (mounted) sub.close();
      if (identical(_unlocked, unlocked)) _unlocked = null;
    }
  }

  @override
  void dispose() {
    final unlocked = _unlocked;
    if (unlocked != null && !unlocked.isCompleted) unlocked.complete(false);
    super.dispose();
  }

  bool _stillCurrent(UsdTagRepairService service, String currency) =>
      mounted &&
      ref.read(usdTagRepairServiceProvider)?.userId == service.userId &&
      ref.read(currencyCodeProvider) == currency;

  @override
  Widget build(BuildContext context) => widget.child;
}
