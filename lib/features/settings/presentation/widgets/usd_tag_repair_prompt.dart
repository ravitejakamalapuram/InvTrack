import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/data/services/usd_tag_repair_service.dart';
import 'package:inv_tracker/features/settings/presentation/providers/currency_switch_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Analytics event for the US dollar repair. Parameters are an action and
/// counts only, never names, ids or amounts (CLAUDE.md rule 7).
const usdTagRepairEvent = 'usd_tag_repair';

/// Analytics must never block or break the repair.
AnalyticsService? _readAnalytics(WidgetRef ref) {
  try {
    return ref.read(analyticsServiceProvider);
  } catch (_) {
    return null;
  }
}

void _logRepair(AnalyticsService? analytics, Map<String, Object> parameters) {
  if (analytics == null) return;
  unawaited(
    analytics
        .logEvent(name: usdTagRepairEvent, parameters: parameters)
        .catchError((Object _) {}),
  );
}

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
    final analytics = _readAnalytics(ref);
    _logRepair(analytics, {
      'action': 'prompted',
      'flagged': candidates.length,
      'fixed': 0,
    });
    final selected = await showDialog<Set<String>>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) =>
          _UsdTagRepairDialog(candidates: candidates, currency: currency),
    );
    // Whoever answered must still be the user asked, and the currency they
    // saw must still be the base currency. Otherwise nothing is recorded and
    // a later start asks again.
    if (selected == null || !_stillCurrent(service, currency)) return;
    if (selected.isEmpty) {
      await service.markResolved();
      _logRepair(analytics, {
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
    _logRepair(analytics, {
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

/// Puts US dollars back on the investments the last fix changed and tells
/// the user how it went. Returns whether it succeeded.
Future<bool> undoUsdTagRepair(
  BuildContext context,
  UsdTagRepairService service,
  AnalyticsService? analytics,
) async {
  final l10n = AppLocalizations.of(context);
  final investments = service.backedUpInvestmentCount;
  try {
    await service.undo();
  } catch (e) {
    LoggerService.warn(
      'USD tag repair undo failed',
      metadata: {'errorType': e.runtimeType.toString()},
    );
    if (context.mounted) {
      AppFeedback.showError(context, l10n.usdTagRepairUndoFailed);
    }
    return false;
  }
  _logRepair(analytics, {'action': 'undone', 'investments': investments});
  if (context.mounted) {
    AppFeedback.showSuccess(context, l10n.usdTagRepairUndone);
  }
  return true;
}

/// The question: lists the flagged investments (names and cash-flow counts,
/// no amounts) with a tick each. Pops the ticked ids for Change, an empty
/// set for Keep, and null when closed with Back.
class _UsdTagRepairDialog extends StatefulWidget {
  const _UsdTagRepairDialog({required this.candidates, required this.currency});

  final List<UsdTagCandidate> candidates;
  final String currency;

  @override
  State<_UsdTagRepairDialog> createState() => _UsdTagRepairDialogState();
}

class _UsdTagRepairDialogState extends State<_UsdTagRepairDialog> {
  late final Set<String> _selected = {
    for (final c in widget.candidates) c.investmentId,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.usdTagRepairTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              l10n.usdTagRepairMessage(
                widget.candidates.length,
                getCurrencySymbol(widget.currency),
                widget.currency,
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.usdTagRepairDetail, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            for (final c in widget.candidates)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _selected.contains(c.investmentId),
                onChanged: (ticked) => setState(() {
                  if (ticked == true) {
                    _selected.add(c.investmentId);
                  } else {
                    _selected.remove(c.investmentId);
                  }
                }),
                title: Text(c.name),
                subtitle: Text(
                  [
                    l10n.usdTagRepairCashFlows(c.cashFlowCount),
                    if (c.isMerged) l10n.usdTagRepairMerged,
                    if (c.isArchived) l10n.usdTagRepairArchived,
                  ].join(' · '),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(<String>{}),
          child: Text(l10n.usdTagRepairKeep),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop(Set.of(_selected)),
          child: Text(l10n.usdTagRepairFix(widget.currency)),
        ),
      ],
    );
  }
}

/// Settings > Data & Account item that undoes the US dollar fix while its
/// backup is on this device. Shows nothing otherwise.
class UsdTagRepairUndoTile extends ConsumerStatefulWidget {
  const UsdTagRepairUndoTile({super.key});

  @override
  ConsumerState<UsdTagRepairUndoTile> createState() =>
      _UsdTagRepairUndoTileState();
}

class _UsdTagRepairUndoTileState extends ConsumerState<UsdTagRepairUndoTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(usdTagRepairServiceProvider);
    if (service == null || !service.hasBackup) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final count = service.backedUpInvestmentCount;
    return ListTile(
      leading: const Icon(Icons.undo),
      title: Text(l10n.usdTagRepairUndoTitle),
      subtitle: Text(l10n.usdTagRepairUndoSubtitle(count)),
      enabled: !_busy,
      onTap: () => _confirmUndo(service, count),
    );
  }

  Future<void> _confirmUndo(UsdTagRepairService service, int count) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.usdTagRepairUndoTitle),
        content: Text(l10n.usdTagRepairUndoMessage(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.usdTagRepairUndo),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (ref.read(usdTagRepairServiceProvider)?.userId != service.userId) {
      return;
    }
    setState(() => _busy = true);
    await undoUsdTagRepair(context, service, _readAnalytics(ref));
    if (mounted) setState(() => _busy = false);
  }
}
