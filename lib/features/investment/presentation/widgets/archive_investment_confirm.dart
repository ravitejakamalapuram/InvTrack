/// The confirmation shown before an investment is archived or unarchived.
///
/// Archived investments are left out of the Overview totals, goals and FIRE
/// (decision 2026-10-02, A17), so the dialog says so, and lists the goals the
/// archive would change before the user confirms.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/archive_goal_impact_details.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// How long the goal preview may take before the dialog opens without it.
const _goalPreviewTimeout = Duration(seconds: 3);

/// Dialog title for archiving, or unarchiving when [isArchived].
String archiveToggleTitle(AppLocalizations l10n, {required bool isArchived}) =>
    isArchived ? l10n.unarchiveInvestmentTitle : l10n.archiveInvestmentTitle;

/// What the action does to lists, totals, goals and FIRE.
String archiveToggleMessage(
  AppLocalizations l10n, {
  required bool isArchived,
}) => isArchived
    ? l10n.unarchiveInvestmentDisclosure
    : l10n.archiveInvestmentDisclosure;

/// The goals archiving [investment] changes, for the dialog; null when it
/// changes none or when they cannot be worked out in time. The message alone
/// still says what archiving does.
Future<Widget?> archiveConfirmDetails(
  WidgetRef ref,
  InvestmentEntity investment,
) async {
  if (investment.isArchived) return null;
  try {
    final impacts = await ref
        .read(archiveGoalImpactProvider(investment.id).future)
        .timeout(_goalPreviewTimeout);
    return impacts.isEmpty ? null : ArchiveGoalImpactDetails(impacts: impacts);
  } on Object {
    return null;
  }
}

/// Asks the user to confirm archiving [investment], or unarchiving it when it
/// is archived. True when they confirm.
Future<bool> confirmArchiveToggle(
  BuildContext context,
  WidgetRef ref,
  InvestmentEntity investment,
) async {
  final l10n = AppLocalizations.of(context);
  final isArchived = investment.isArchived;
  final details = await archiveConfirmDetails(ref, investment);
  if (!context.mounted) return false;
  return AppFeedback.showConfirmDialog(
    context: context,
    title: archiveToggleTitle(l10n, isArchived: isArchived),
    message: archiveToggleMessage(l10n, isArchived: isArchived),
    details: details,
    confirmText: isArchived ? l10n.unarchive : l10n.archive,
    isDestructive: false,
  );
}
