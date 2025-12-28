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

/// Screen for managing all notification preferences.
class NotificationsSettingsScreen extends ConsumerWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text('Notifications', style: AppTypography.h3)),
      body: ListView(
        children: [
          SizedBox(height: AppSpacing.sm),

          // Summary notifications
          SettingsSection(
            title: 'Summaries',
            footer: 'Periodic updates about your portfolio performance',
            children: [
              SettingsToggleTile(
                icon: Icons.calendar_today,
                iconColor: Colors.blue,
                title: 'Weekly Summary',
                subtitle: 'Get a summary every Sunday',
                value: settings.weeklySummaryEnabled,
                onChanged: (value) => notifier.setSetting(
                  NotificationSettingType.weeklySummary,
                  value,
                ),
              ),
              SettingsToggleTile(
                icon: Icons.summarize,
                iconColor: Colors.teal,
                title: 'Monthly Summary',
                subtitle: 'End of month income recap',
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
            title: 'Reminders',
            footer: 'Stay on top of upcoming events',
            children: [
              SettingsToggleTile(
                icon: Icons.notification_important,
                iconColor: Colors.orange,
                title: 'Income Reminders',
                subtitle: 'When income is expected',
                value: settings.incomeRemindersEnabled,
                onChanged: (value) => notifier.setSetting(
                  NotificationSettingType.incomeReminders,
                  value,
                ),
              ),
              SettingsToggleTile(
                icon: Icons.event_available,
                iconColor: Colors.purple,
                title: 'Maturity Reminders',
                subtitle: 'Before investments mature',
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
            title: 'Goals',
            children: [
              SettingsToggleTile(
                icon: Icons.flag,
                iconColor: AppColors.successLight,
                title: 'Goal Milestones',
                subtitle: 'Celebrate at 25%, 50%, 75%, 100%',
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
              title: 'Debug',
              children: [
                SettingsNavTile(
                  icon: Icons.notifications_active,
                  iconColor: Colors.blue,
                  title: 'Test Notification',
                  subtitle: 'Send an immediate test',
                  showChevron: false,
                  onTap: () async {
                    final service = ref.read(notificationServiceProvider);
                    final success = await service.showTestNotification();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? 'Test notification sent!'
                                : 'Permission denied',
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
                  title: 'Scheduled Test',
                  subtitle: 'Notify in 5 seconds',
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
                                ? 'Scheduled for 5 seconds'
                                : 'Permission denied',
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
