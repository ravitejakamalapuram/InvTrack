/// Bell in the Overview app bar. Opens a sheet with today's tip and the
/// recent ones, so a tip dismissed from the card is not lost.
/// See design/system/components/DailyTipCard.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/features/tips/domain/tip.dart';
import 'package:inv_tracker/features/tips/presentation/providers/daily_tip_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class TipsBellButton extends ConsumerWidget {
  const TipsBellButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tips = ref.watch(dailyTipHistoryProvider).value;
    if (tips == null || tips.isEmpty) return const SizedBox.shrink();
    final unread = ref.watch(dailyTipUnreadProvider);
    final l10n = AppLocalizations.of(context);

    return IconButton(
      tooltip: unread ? l10n.tipsBellLabelUnread : l10n.tipsBellLabel,
      icon: Badge(
        isLabelVisible: unread,
        smallSize: 8,
        child: const Icon(Icons.notifications_outlined),
      ),
      onPressed: () {
        ref.read(dailyTipUnreadProvider.notifier).markRead();
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => _TipsSheet(tips: tips),
        );
      },
    );
  }
}

class _TipsSheet extends StatelessWidget {
  const _TipsSheet({required this.tips});

  final List<Tip> tips;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        children: [
          Text(
            l10n.tipsBellLabel,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          for (final tip in tips)
            Padding(
              padding: EdgeInsets.only(top: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tip.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(tip.body, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          SizedBox(height: AppSpacing.md),
          Text(
            l10n.dailyTipDisclaimer,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
