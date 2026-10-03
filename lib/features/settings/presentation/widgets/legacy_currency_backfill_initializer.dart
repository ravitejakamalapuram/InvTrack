import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/settings/data/services/legacy_currency_backfill_service.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Users asked the start-up question in this app session (process lifetime),
/// so signing out and in again does not ask twice.
final legacyCurrencyPromptedUsersProvider = Provider<Set<String>>(
  (ref) => <String>{},
);

/// Stamps records saved without a currency with the base currency, once per
/// signed-in user (guests included), after the user confirmed that currency
/// for their account (A03-F1).
///
/// The device currency alone is not proof: on a fresh install it is the
/// default INR, and on a shared device it is the previous user's. So when this
/// user has records without a currency and has not confirmed one yet, they
/// are asked at most once per app session, and no longer at start-up after
/// [LegacyCurrencyBackfillService.maxPromptDismissals] dismissals (a
/// base-currency change still asks). Until they confirm, nothing is written
/// and the repositories keep their read-time fallback. If the base currency
/// changes during the check or while the question is open, nothing is
/// written. A failure (for example offline) is retried on the next start.
class LegacyCurrencyBackfillInitializer extends ConsumerStatefulWidget {
  const LegacyCurrencyBackfillInitializer({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LegacyCurrencyBackfillInitializer> createState() =>
      _LegacyCurrencyBackfillInitializerState();
}

class _LegacyCurrencyBackfillInitializerState
    extends ConsumerState<LegacyCurrencyBackfillInitializer> {
  String? _handledUserId;

  @override
  void initState() {
    super.initState();
    ref.listenManual<LegacyCurrencyBackfillService?>(
      legacyCurrencyBackfillServiceProvider,
      (_, service) {
        if (service == null) {
          _handledUserId = null;
          return;
        }
        if (service.userId == _handledUserId) return;
        _handledUserId = service.userId;
        unawaited(_run(service));
      },
      fireImmediately: true,
    );
  }

  Future<void> _run(LegacyCurrencyBackfillService service) async {
    if (service.isComplete) return;
    final currency = ref.read(currencyCodeProvider);
    if (service.isConfirmedFor(currency)) {
      await service.runOnce(currency);
      return;
    }
    final askedThisSession = ref.read(legacyCurrencyPromptedUsersProvider);
    if (!service.mayPromptAtStart ||
        askedThisSession.contains(service.userId)) {
      return;
    }

    final bool pending;
    try {
      pending = await service.hasUnstampedRecords();
    } catch (e) {
      LoggerService.warn(
        'Legacy currency check did not finish; will retry',
        metadata: {'errorType': e.runtimeType.toString()},
      );
      return;
    }
    // The base currency may have changed in Settings during the scan; then
    // the question would name a currency that is no longer shown. Ask again
    // on a later start instead.
    if (!pending || !mounted || ref.read(currencyCodeProvider) != currency) {
      return;
    }

    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    // add() is false when another run already asked this user this session.
    if (!askedThisSession.add(service.userId)) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.legacyCurrencyPromptTitle),
        content: Text(l10n.legacyCurrencyPromptMessage(currency)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.notNow),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.legacyCurrencyPromptConfirm(currency)),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      await service.recordPromptDismissed();
      return;
    }

    // Stamp only the currency the user saw and confirmed, and only while it
    // is still the base currency (it may have changed while the dialog was
    // open). Otherwise nothing is written and a later start asks again.
    if (!mounted || ref.read(currencyCodeProvider) != currency) return;
    await service.confirm(currency);
    await service.runOnce(currency);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Asks, before a base-currency change to [newCurrency], whether records saved
/// without a currency were entered in [currency], the current base currency.
/// Used when the user never confirmed it at start-up (Not Now, dismissed, or
/// offline then). Returns true for yes, false for no, and null when the change
/// is cancelled, including by tapping outside the dialog.
Future<bool?> askLegacyCurrencyBeforeSwitch(
  BuildContext context, {
  required String currency,
  required String newCurrency,
}) {
  final l10n = AppLocalizations.of(context);
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.legacyCurrencyPromptTitle),
      content: Text(
        l10n.legacyCurrencySwitchPromptMessage(currency, newCurrency),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.legacyCurrencySwitchPromptNo(newCurrency)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.legacyCurrencySwitchPromptYes(currency)),
        ),
      ],
    ),
  );
}
