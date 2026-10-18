import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _askedKey = 'notification_permissions_requested';

/// Whether to offer a payout reminder: the investment has a maturity date and
/// the user has not been asked before (A45, #788).
bool shouldAskMaturityReminder(
  SharedPreferences prefs,
  DateTime? maturityDate,
) => maturityDate != null && !(prefs.getBool(_askedKey) ?? false);

/// Asks, once, whether to allow notifications after a save that has a maturity
/// date. The system dialog appears only after the user taps Remind me.
Future<void> askMaturityReminderIfNeeded(
  BuildContext context,
  WidgetRef ref, {
  required DateTime? maturityDate,
}) async {
  final SharedPreferences prefs;
  try {
    if (!ref.read(isMaturityReminderPromptEnabledProvider)) return;
    prefs = ref.read(sharedPreferencesProvider);
  } catch (_) {
    // A saved investment never waits on a missing flag or preference store.
    return;
  }
  if (!shouldAskMaturityReminder(prefs, maturityDate)) return;
  final service = ref.read(notificationServiceProvider);
  final l10n = AppLocalizations.of(context);

  final accepted = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.maturityReminderTitle),
      content: Text(l10n.maturityReminderBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.maturityReminderDecline),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.maturityReminderAccept),
        ),
      ],
    ),
  );

  // Dismissed without a choice: ask again on a later save.
  if (accepted == null) return;
  // Nothing here may fail a saved investment.
  try {
    await prefs.setBool(_askedKey, true);
    if (accepted) await service.requestPermissions();
  } catch (e) {
    LoggerService.warn('Maturity reminder opt-in failed', error: e);
  }
}
