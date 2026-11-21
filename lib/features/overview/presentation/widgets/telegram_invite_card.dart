/// Quiet one-time Overview card inviting people to the Telegram tips channel.
/// See design/system/components/TelegramInviteCard.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/features/overview/presentation/providers/telegram_invite_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class TelegramInviteCard extends ConsumerWidget {
  const TelegramInviteCard({super.key});

  void _logShownOnce(WidgetRef ref) {
    if (!ref
        .read(analyticsOnceProvider)
        .add(AnalyticsEvents.telegramInviteShown)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(analyticsServiceProvider).logTelegramInviteShown(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(telegramInviteVisibleProvider)) {
      return const SizedBox.shrink();
    }
    _logShownOnce(ref);
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
          Icon(Icons.send_outlined, color: accent, size: 22),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.telegramInviteTitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.telegramInviteMessage,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () async {
                    final opened = await openTelegramChannel(
                      context,
                      ref,
                      source: 'card',
                    );
                    if (opened) {
                      await ref
                          .read(telegramInviteDoneProvider.notifier)
                          .markDone();
                    }
                  },
                  child: Text(l10n.telegramInviteAction),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.telegramInviteDismiss,
            icon: const Icon(Icons.close, size: 20),
            onPressed: () {
              ref.read(analyticsServiceProvider).logTelegramInviteDismissed();
              ref.read(telegramInviteDoneProvider.notifier).markDone();
            },
          ),
        ],
      ),
    );
  }
}
