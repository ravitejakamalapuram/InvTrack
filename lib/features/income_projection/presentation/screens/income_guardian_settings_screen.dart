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
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Income Guardian settings screen
class IncomeGuardianSettingsScreen extends ConsumerWidget {
  const IncomeGuardianSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(incomeGuardianSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.incomeGuardianSettings, style: AppTypography.h3),
      ),
      body: ListView(
        children: [
          SizedBox(height: AppSpacing.sm),

          // Feature Toggle
          SettingsSection(
            title: l10n.incomeGuardianGeneral,
            footer: l10n.enableIncomeGuardian,
            children: [
              SettingsToggleTile(
                icon: Icons.security,
                iconColor: AppColors.successLight,
                title: l10n.incomeGuardianSettings,
                subtitle: settings.enabled
                    ? l10n.incomeGuardianEnabled
                    : l10n.incomeGuardianDisabled,
                value: settings.enabled,
                onChanged: (value) => ref
                    .read(incomeGuardianSettingsProvider.notifier)
                    .setEnabled(value),
              ),
            ],
          ),

          // Notification Timing
          SettingsSection(
            title: l10n.notificationTiming,
            footer: l10n.notificationTimingFooter,
            children: [
              _SliderTile(
                icon: Icons.notifications_active,
                iconColor: Colors.orange,
                title: l10n.upcomingPaymentAlert,
                subtitle: l10n.upcomingPaymentAlertSubtitle(
                  settings.upcomingDaysBefore,
                  settings.upcomingDaysBefore != 1 ? 's' : '',
                ),
                value: settings.upcomingDaysBefore.toDouble(),
                min: 0,
                max: 7,
                divisions: 7,
                isDark: isDark,
                onChanged: (value) => ref
                    .read(incomeGuardianSettingsProvider.notifier)
                    .setUpcomingDaysBefore(value.toInt()),
              ),
              _SliderTile(
                icon: Icons.warning_amber_rounded,
                iconColor: AppColors.errorLight,
                title: l10n.overduePaymentAlert,
                subtitle: l10n.overduePaymentAlertSubtitle(
                  settings.overdueDaysAfter,
                  settings.overdueDaysAfter != 1 ? 's' : '',
                ),
                value: settings.overdueDaysAfter.toDouble(),
                min: 0,
                max: 7,
                divisions: 7,
                isDark: isDark,
                onChanged: (value) => ref
                    .read(incomeGuardianSettingsProvider.notifier)
                    .setOverdueDaysAfter(value.toInt()),
              ),
            ],
          ),

          // Auto-Matching Configuration
          SettingsSection(
            title: l10n.autoMatching,
            footer: l10n.autoMatchingFooter,
            children: [
              _SliderTile(
                icon: Icons.percent,
                iconColor: Colors.blue,
                title: l10n.amountTolerance,
                subtitle: l10n.amountToleranceSubtitle(settings.amountTolerancePercent),
                value: settings.amountTolerancePercent.toDouble(),
                min: 5,
                max: 30,
                divisions: 5,
                isDark: isDark,
                onChanged: (value) => ref
                    .read(incomeGuardianSettingsProvider.notifier)
                    .setAmountTolerancePercent(value.toInt()),
              ),
              _SliderTile(
                icon: Icons.calendar_month,
                iconColor: Colors.purple,
                title: l10n.dateWindow,
                subtitle: l10n.dateWindowSubtitle(
                  settings.dateWindowDays,
                  settings.dateWindowDays != 1 ? 's' : '',
                ),
                value: settings.dateWindowDays.toDouble(),
                min: 7,
                max: 60,
                divisions: 10, // 7, 14, 21, 28, 35, 42, 49, 56
                isDark: isDark,
                onChanged: (value) {
                  // Round to nearest 7 days
                  final roundedValue = ((value / 7).round() * 7).clamp(7, 60);
                  ref
                      .read(incomeGuardianSettingsProvider.notifier)
                      .setDateWindowDays(roundedValue);
                },
              ),
              _SliderTile(
                icon: Icons.tune,
                iconColor: AppColors.warningLight,
                title: l10n.confidenceThreshold,
                subtitle: l10n.confidenceThresholdSubtitle(settings.confidenceThresholdPercent),
                value: settings.confidenceThresholdPercent.toDouble(),
                min: 50,
                max: 95,
                divisions: 9,
                isDark: isDark,
                onChanged: (value) => ref
                    .read(incomeGuardianSettingsProvider.notifier)
                    .setConfidenceThresholdPercent(value.toInt()),
              ),
            ],
          ),

          // Platform Delays (Coming Soon)
          SettingsSection(
            title: l10n.platformDelays,
            footer: l10n.platformDelaysFooter,
            children: [
              ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                leading: Icon(
                  Icons.schedule_send,
                  color: AppColors.neutral400Dark,
                ),
                title: Text(
                  l10n.comingSoon,
                  style: AppTypography.bodyMedium.copyWith(
                    color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                  ),
                ),
                subtitle: Text(
                  l10n.platformDelaysComingSoon,
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
