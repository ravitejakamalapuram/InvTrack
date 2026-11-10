/// Quiet Overview card with one money-learning tip a day.
/// See design/system/components/DailyTipCard.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/error/error_handler.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/features/tips/domain/tip.dart';
import 'package:inv_tracker/features/tips/presentation/providers/daily_tip_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class DailyTipCard extends ConsumerWidget {
  const DailyTipCard({super.key});

  void _logShownOnce(WidgetRef ref, Tip tip) {
    if (!ref.read(analyticsOnceProvider).add('daily_tip_shown')) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).logDailyTipShown(tipId: tip.id);
    });
  }

  Future<void> _dismiss(BuildContext context, WidgetRef ref, Tip tip) async {
    ref.read(analyticsServiceProvider).logDailyTipDismissed(tipId: tip.id);
    try {
      await ref.read(dailyTipProvider.notifier).dismiss();
    } catch (e, st) {
      ErrorHandler.handle(e, st, context: context.mounted ? context : null);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tip = ref.watch(dailyTipProvider).value;
    if (tip == null) return const SizedBox.shrink();
    _logShownOnce(ref, tip);

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return Container(
      margin: EdgeInsets.symmetric(vertical: AppSpacing.sm),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: accent, size: 22),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.dailyTipLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tip.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(tip.body, style: theme.textTheme.bodySmall),
                const SizedBox(height: 6),
                Opacity(
                  opacity: 0.7,
                  child: Text(
                    l10n.dailyTipDisclaimer,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.dailyTipDismiss,
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => _dismiss(context, ref, tip),
          ),
        ],
      ),
    );
  }
}
