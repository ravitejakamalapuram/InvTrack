/// Notification settings screen with all notification options.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/notifications/notification_settings_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_section.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_tile.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Screen for managing all notification preferences.
class NotificationsSettingsScreen extends ConsumerWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notificationsSectionTitle, style: AppTypography.h3),
      ),
      body: ListView(
        children: [
          SizedBox(height: AppSpacing.sm),

          // Summary notifications
          SettingsSection(
            title: l10n.summaries,
            footer: l10n.periodicUpdatesAboutPortfolio,
            children: [
              SettingsToggleTile(
                icon: Icons.calendar_today,
                iconColor: Colors.blue,
                title: l10n.weeklySummary,
                subtitle: l10n.getSummaryEverySunday,
                value: settings.weeklySummaryEnabled,
                onChanged: (value) => notifier.setSetting(
                  NotificationSettingType.weeklySummary,
                  value,
                ),
              ),
              SettingsToggleTile(
                icon: Icons.summarize,
                iconColor: Colors.teal,
                title: l10n.monthlySummary,
                subtitle: l10n.endOfMonthIncomeRecap,
                value: settings.monthlySummaryEnabled,
                onChanged: (value) => notifier.setSetting(
                  NotificationSettingType.monthlySummary,
                  value,
                ),
              ),
            ],
          ),

          // Reminder notifications
          SettingsSection(
            title: l10n.reminders,
            footer: l10n.stayOnTopOfUpcomingEvents,
            children: [
              SettingsToggleTile(
                icon: Icons.notification_important,
                iconColor: Colors.orange,
                title: l10n.incomeReminders,
                subtitle: l10n.whenIncomeIsExpected,
                value: settings.incomeRemindersEnabled,
                onChanged: (value) => notifier.setSetting(
                  NotificationSettingType.incomeReminders,
                  value,
                ),
              ),
              SettingsToggleTile(
                icon: Icons.event_available,
                iconColor: Colors.purple,
                title: l10n.maturityReminders,
                subtitle: l10n.beforeInvestmentsMature,
                value: settings.maturityRemindersEnabled,
                onChanged: (value) => notifier.setSetting(
                  NotificationSettingType.maturityReminders,
                  value,
                ),
              ),
            ],
          ),

          // Goal notifications
          SettingsSection(
            title: l10n.goals,
            children: [
              SettingsToggleTile(
                icon: Icons.flag,
                iconColor: AppColors.successLight,
                title: l10n.goalMilestones,
                subtitle: l10n.celebrateAtMilestones,
                value: settings.goalMilestonesEnabled,
                onChanged: (value) => notifier.setSetting(
                  NotificationSettingType.goalMilestones,
                  value,
                ),
              ),
            ],
          ),

          // Debug options
          if (kDebugMode) ...[
            SettingsSection(
              title: l10n.debug,
              children: [
                SettingsNavTile(
                  icon: Icons.notifications_active,
                  iconColor: Colors.blue,
                  title: l10n.testNotification,
                  subtitle: l10n.sendImmediateTest,
                  showChevron: false,
                  onTap: () async {
                    final service = ref.read(notificationServiceProvider);
                    final success = await service.showTestNotification();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? l10n.testNotificationSent
                                : l10n.permissionDenied,
                          ),
                          backgroundColor: success
                              ? Colors.blue
                              : Colors.orange,
                        ),
                      );
                    }
                  },
                ),
                SettingsNavTile(
                  icon: Icons.schedule,
                  iconColor: Colors.purple,
                  title: l10n.scheduledTest,
                  subtitle: l10n.notifyInFiveSeconds,
                  showChevron: false,
                  onTap: () async {
                    final service = ref.read(notificationServiceProvider);
                    final success = await service.scheduleTestNotification(
                      delaySeconds: 5,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? l10n.scheduledForFiveSeconds
                                : l10n.permissionDenied,
                          ),
                          backgroundColor: success
                              ? Colors.purple
                              : Colors.orange,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ],

          SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
