import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';
import 'package:inv_tracker/features/settings/data/services/usd_tag_repair_service.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Analytics event for the US dollar repair. Parameters are an action and
/// counts only, never names, ids or amounts (CLAUDE.md rule 7).
const usdTagRepairEvent = 'usd_tag_repair';

/// Analytics must never block or break the repair.
AnalyticsService? readUsdTagRepairAnalytics(WidgetRef ref) {
  try {
    return ref.read(analyticsServiceProvider);
  } catch (_) {
    return null;
  }
}

void logUsdTagRepair(
  AnalyticsService? analytics,
  Map<String, Object> parameters,
) {
  if (analytics == null) return;
  unawaited(
    analytics
        .logEvent(name: usdTagRepairEvent, parameters: parameters)
        .catchError((Object _) {}),
  );
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
  logUsdTagRepair(analytics, {'action': 'undone', 'investments': investments});
  if (context.mounted) {
    AppFeedback.showSuccess(context, l10n.usdTagRepairUndone);
  }
  return true;
}
