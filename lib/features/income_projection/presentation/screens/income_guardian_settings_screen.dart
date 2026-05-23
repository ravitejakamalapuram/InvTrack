/// Income Guardian settings screen for configuration.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/income_projection/presentation/providers/income_guardian_settings_provider.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_section.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_tile.dart';

/// Income Guardian settings screen
class IncomeGuardianSettingsScreen extends ConsumerWidget {
  const IncomeGuardianSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(incomeGuardianSettingsProvider);
    final notifier = ref.read(incomeGuardianSettingsProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Income Guardian', style: AppTypography.h3),
      ),
      body: ListView(
        children: [
          SizedBox(height: AppSpacing.sm),

          // Feature Toggle
          SettingsSection(
            title: 'General',
            footer: 'Enable automated income tracking and payment notifications',
            children: [
              SettingsToggleTile(
                icon: Icons.security,
                iconColor: AppColors.successLight,
                title: 'Income Guardian',
                subtitle: settings.enabled
                    ? 'Monitoring your expected payments'
                    : 'Tap to enable automated tracking',
                value: settings.enabled,
                onChanged: (value) => notifier.setEnabled(value),
              ),
            ],
          ),

          // Notification Timing
          SettingsSection(
            title: 'Notification Timing',
            footer: 'Configure when you want to be notified about expected payments',
            children: [
              _SliderTile(
                icon: Icons.notifications_active,
                iconColor: Colors.orange,
                title: 'Upcoming Payment Alert',
                subtitle: '${settings.upcomingDaysBefore} day${settings.upcomingDaysBefore == 1 ? '' : 's'} before expected date',
                value: settings.upcomingDaysBefore.toDouble(),
                min: 0,
                max: 7,
                divisions: 7,
                isDark: isDark,
                onChanged: (value) => notifier.setUpcomingDaysBefore(value.toInt()),
              ),
              _SliderTile(
                icon: Icons.warning_amber_rounded,
                iconColor: AppColors.errorLight,
                title: 'Overdue Payment Alert',
                subtitle: '${settings.overdueDaysAfter} day${settings.overdueDaysAfter == 1 ? '' : 's'} after expected date',
                value: settings.overdueDaysAfter.toDouble(),
                min: 0,
                max: 7,
                divisions: 7,
                isDark: isDark,
                onChanged: (value) => notifier.setOverdueDaysAfter(value.toInt()),
              ),
            ],
          ),

          // Auto-Matching Configuration
          SettingsSection(
            title: 'Auto-Matching',
            footer: 'Fine-tune how the system matches actual payments to expected payments',
            children: [
              _SliderTile(
                icon: Icons.percent,
                iconColor: Colors.blue,
                title: 'Amount Tolerance',
                subtitle: '±${settings.amountTolerancePercent}% variance allowed',
                value: settings.amountTolerancePercent.toDouble(),
                min: 5,
                max: 30,
                divisions: 5,
                isDark: isDark,
                onChanged: (value) => notifier.setAmountTolerancePercent(value.toInt()),
              ),
              _SliderTile(
                icon: Icons.calendar_month,
                iconColor: Colors.purple,
                title: 'Date Window',
                subtitle: '±${settings.dateWindowDays} day${settings.dateWindowDays == 1 ? '' : 's'} from expected date',
                value: settings.dateWindowDays.toDouble(),
                min: 7,
                max: 60,
                divisions: 10, // 7, 14, 21, 28, 35, 42, 49, 56
                isDark: isDark,
                onChanged: (value) {
                  // Round to nearest 7 days
                  final roundedValue = ((value / 7).round() * 7).clamp(7, 60);
                  notifier.setDateWindowDays(roundedValue);
                },
              ),
              _SliderTile(
                icon: Icons.tune,
                iconColor: AppColors.warningLight,
                title: 'Confidence Threshold',
                subtitle: '${settings.confidenceThresholdPercent}% minimum match score',
                value: settings.confidenceThresholdPercent.toDouble(),
                min: 50,
                max: 95,
                divisions: 9,
                isDark: isDark,
                onChanged: (value) => notifier.setConfidenceThresholdPercent(value.toInt()),
              ),
            ],
          ),

          // Platform Delays (Coming Soon)
          SettingsSection(
            title: 'Platform Delays',
            footer: 'Customize expected delays for specific platforms (e.g., LenDenClub +2 days)',
            children: [
              ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                leading: Icon(
                  Icons.schedule_send,
                  color: AppColors.neutral400Dark,
                ),
                title: Text(
                  'Coming Soon',
                  style: AppTypography.bodyMedium.copyWith(
                    color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                  ),
                ),
                subtitle: Text(
                  'Platform-specific delay adjustments will be available in a future update',
                  style: AppTypography.small.copyWith(
                    color: isDark ? AppColors.neutral500Dark : AppColors.neutral400Light,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

/// Slider tile widget for settings
class _SliderTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final bool isDark;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          title: Text(
            title,
            style: AppTypography.bodyMedium.copyWith(
              color: isDark ? Colors.white : AppColors.neutral900Light,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: AppTypography.small.copyWith(
              color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: iconColor,
              inactiveTrackColor: iconColor.withValues(alpha: 0.2),
              thumbColor: iconColor,
              overlayColor: iconColor.withValues(alpha: 0.2),
              valueIndicatorColor: iconColor,
              trackHeight: 4,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
