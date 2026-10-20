import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/core/security/wait_until_unlocked.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/settings/data/services/usd_tag_repair_service.dart';
import 'package:inv_tracker/features/settings/presentation/providers/currency_switch_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/usd_tag_repair_check_provider.dart';
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
    extends ConsumerState<UsdTagRepairInitializer>
    with WaitsForUnlock {
  String? _handledUserId;
  bool _checkingImport = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual<Set<String>>(usdTagRepairPendingCheckProvider, (_, ids) {
      if (ids.isNotEmpty) unawaited(_checkAfterImport());
    }, fireImmediately: true);
    ref.listenManual<UsdTagRepairService?>(usdTagRepairServiceProvider, (
      _,
      service,
    ) {
      final pending = ref.read(usdTagRepairPendingCheckProvider.notifier);
      if (service == null) {
        // Ids queued for a user who signed out belong to nobody now.
        if (_handledUserId != null) pending.take();
        _handledUserId = null;
        return;
      }
      if (service.userId == _handledUserId) return;
      if (_handledUserId != null) pending.take();
      _handledUserId = service.userId;
      unawaited(_run(service));
      // Ids left over from an import that could not be checked yet.
      unawaited(_checkAfterImport());
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
    } else {
      await _ask(service, currency, candidates, answersWholeQuestion: true);
    }
    // Ids reported while this question was open wait in the queue.
    if (mounted) await _checkAfterImport();
  }

  /// A restore, ZIP import or guest merge wrote [usdTagRepairPendingCheckProvider]
  /// ids: asks again about the ones tagged US dollars, even when the question
  /// was answered before. Does nothing before the first answer, since the
  /// start-up check then looks at everything.
  Future<void> _checkAfterImport() async {
    if (_checkingImport) return;
    _checkingImport = true;
    try {
      while (mounted) {
        final service = ref.read(usdTagRepairServiceProvider);
        final currency = ref.read(currencyCodeProvider);
        if (service == null ||
            currency == UsdTagRepairService.taggedCurrency ||
            ref.read(usdTagRepairPendingCheckProvider).isEmpty) {
          return;
        }
        final ids = ref.read(usdTagRepairPendingCheckProvider.notifier).take();
        final List<UsdTagCandidate> candidates;
        try {
          if (!await service.checkResolved()) {
            // The start-up check may already have read its documents.
            if (_stillCurrent(service, currency)) _requeue(ids);
            return;
          }
          candidates = await service.findCandidates(currency, onlyOwners: ids);
        } catch (e) {
          LoggerService.warn(
            'USD tag check after import did not finish',
            metadata: {'errorType': e.runtimeType.toString()},
          );
          if (_stillCurrent(service, currency)) _requeue(ids);
          return;
        }
        if (candidates.isEmpty) continue;
        if (!_stillCurrent(service, currency) ||
            !await _ask(
              service,
              currency,
              candidates,
              answersWholeQuestion: false,
            )) {
          // Not asked (locked, a currency change running, another user): the
          // same user's ids wait for the next report or start of this widget.
          if (_stillCurrent(service, currency)) _requeue(ids);
          return;
        }
      }
    } finally {
      _checkingImport = false;
    }
  }

  void _requeue(Set<String> ids) => ref
      .read(usdTagRepairPendingCheckProvider.notifier)
      .report(investmentIds: ids);

  /// Shows the question for [candidates] and applies the answer. False when
  /// it was not asked or not answered, so nothing was recorded.
  /// [answersWholeQuestion] is false after an import, which looked at some
  /// documents only, so the account's answer is not recorded.
  Future<bool> _ask(
    UsdTagRepairService service,
    String currency,
    List<UsdTagCandidate> candidates, {
    required bool answersWholeQuestion,
  }) async {
    // The question lists investment names, so it never opens over the lock
    // screen; it waits until the app is unlocked.
    if (!await waitUntilUnlocked() || !_stillCurrent(service, currency)) {
      return false;
    }
    if (ref.read(currencySwitchProvider).isBusy) return false;

    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return false;
    if (answersWholeQuestion &&
        !ref.read(usdTagRepairPromptedUsersProvider).add(service.userId)) {
      return false;
    }
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
    if (selected == null || !_stillCurrent(service, currency)) return false;
    // What the user did not tick stays as US dollars, and is not asked about
    // again if a restore brings it back.
    await service.markKept([
      for (final c in candidates)
        if (!selected.contains(c.id)) c.id,
    ]);
    if (selected.isEmpty) {
      if (answersWholeQuestion) await service.markResolved();
      logUsdTagRepair(analytics, {
        'action': 'kept',
        'flagged': candidates.length,
        'fixed': 0,
      });
      return true;
    }

    final int changed;
    final int goals;
    try {
      // What this run really changed: the re-scan and the transactions skip
      // investments and goals changed elsewhere since the question opened.
      final result = await service.repair(selected, currency);
      goals = result.goals;
      changed = result.investments + goals;
    } catch (e) {
      LoggerService.warn(
        'USD tag repair did not finish; will ask again',
        metadata: {'errorType': e.runtimeType.toString()},
      );
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        AppFeedback.showError(ctx, AppLocalizations.of(ctx).usdTagRepairFailed);
      }
      return false;
    }
    logUsdTagRepair(analytics, {
      'action': 'fixed',
      'flagged': candidates.length,
      'fixed': changed,
    });
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return true;
    final l10n = AppLocalizations.of(ctx);
    if (changed == 0) {
      final listedGoals = candidates.any((c) => c.kind == UsdTagKind.goal);
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(
            listedGoals
                ? l10n.usdTagRepairNothingChangedWithGoals
                : l10n.usdTagRepairNothingChanged,
          ),
        ),
      );
      return true;
    }
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(switch ((changed - goals, goals)) {
          (_, 0) => l10n.usdTagRepairDone(changed, currency),
          (0, _) => l10n.usdTagRepairDoneGoals(changed, currency),
          _ => l10n.usdTagRepairDoneWithGoals(changed, currency),
        }),
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
    return true;
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

  bool _stillCurrent(UsdTagRepairService service, String currency) =>
      mounted &&
      ref.read(usdTagRepairServiceProvider)?.userId == service.userId &&
      ref.read(currencyCodeProvider) == currency;

  @override
  Widget build(BuildContext context) => widget.child;
}
