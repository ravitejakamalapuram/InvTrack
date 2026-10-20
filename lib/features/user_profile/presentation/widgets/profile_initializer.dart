import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/core/security/wait_until_unlocked.dart';
import 'package:inv_tracker/core/widgets/currency_picker_sheet.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/user_profile/domain/services/base_currency_planner.dart';
import 'package:inv_tracker/features/user_profile/presentation/providers/base_currency_reconciler.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Keeps the base currency on the signed-in user's profile (A31).
///
/// Once per signed-in user per start it compares the profile with this device
/// (see [planBaseCurrency]): a new device shows the profile's currency, a user
/// who already has data keeps theirs and it is stored on the profile, and a
/// brand-new user is asked to confirm the currency proposed from the phone's
/// country. Nothing is stored for that user until they confirm, and an unknown
/// country proposes nothing. A failure (for example offline) is retried on the
/// next start.
class ProfileInitializer extends ConsumerStatefulWidget {
  const ProfileInitializer({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ProfileInitializer> createState() => _ProfileInitializerState();
}

class _ProfileInitializerState extends ConsumerState<ProfileInitializer>
    with WaitsForUnlock {
  String? _handledUserId;

  @override
  void initState() {
    super.initState();
    ref.listenManual(authStateProvider, (_, next) {
      final userId = next.value?.id;
      if (userId == null) {
        _handledUserId = null;
        return;
      }
      if (userId == _handledUserId) return;
      _handledUserId = userId;
      unawaited(_run(userId));
    }, fireImmediately: true);
  }

  bool _stillCurrent(String userId) =>
      mounted && ref.read(authStateProvider).value?.id == userId;

  Future<void> _run(String userId) async {
    if (!ref.read(isBaseCurrencyPromptEnabledProvider)) return;
    try {
      final reconciler = ref.read(baseCurrencyReconcilerProvider);
      final plan = await reconciler.reconcile(
        userId,
        isCurrent: () => _stillCurrent(userId),
      );
      final proposed = plan.currency;
      if (plan.action != BaseCurrencyAction.propose || proposed == null) return;
      final chosen = await _ask(userId, proposed);
      if (chosen == null || !_stillCurrent(userId)) return;
      await reconciler.confirm(userId, chosen);
    } catch (e) {
      LoggerService.warn(
        'Base currency profile check did not finish; will retry',
        metadata: {'errorType': e.runtimeType.toString()},
      );
    }
  }

  /// Returns the confirmed currency, or null when the question is dismissed
  /// (it is asked again on the next start).
  Future<String?> _ask(String userId, String proposed) async {
    // Confirming writes to Firestore, so a locked phone must not answer.
    if (!await waitUntilUnlocked() || !_stillCurrent(userId)) return null;
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return null;
    final l10n = AppLocalizations.of(context);
    final answer = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.baseCurrencyPromptTitle),
        content: Text(l10n.baseCurrencyPromptMessage(proposed)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.notNow),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(''),
            child: Text(l10n.baseCurrencyPromptChoose),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(proposed),
            child: Text(l10n.baseCurrencyPromptUse(proposed)),
          ),
        ],
      ),
    );
    if (answer == null) return null;
    if (answer.isNotEmpty) return answer;
    if (!_stillCurrent(userId)) return null;
    final again = rootNavigatorKey.currentContext;
    if (again == null || !again.mounted) return null;
    return showCurrencyPickerSheet(
      again,
      selected: proposed,
      useRootNavigator: true,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
