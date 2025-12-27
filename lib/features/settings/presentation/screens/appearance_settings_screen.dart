/// Appearance settings screen for theme customization.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_section.dart';

/// Screen for managing appearance settings.
class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final themeMode = settings.themeMode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Appearance', style: AppTypography.h3),
      ),
      body: ListView(
        children: [
          SizedBox(height: AppSpacing.sm),

          SettingsSection(
            title: 'Theme',
            footer: 'Choose how InvTrack looks',
            children: [
              _ThemeOption(
                icon: Icons.brightness_auto,
                title: 'System',
                subtitle: 'Match device settings',
                isSelected: themeMode == ThemeMode.system,
                onTap: () => ref.read(settingsProvider.notifier).setThemeMode(ThemeMode.system),
              ),
              _ThemeOption(
                icon: Icons.light_mode,
                title: 'Light',
                subtitle: 'Always use light theme',
                isSelected: themeMode == ThemeMode.light,
                onTap: () => ref.read(settingsProvider.notifier).setThemeMode(ThemeMode.light),
              ),
              _ThemeOption(
                icon: Icons.dark_mode,
                title: 'Dark',
                subtitle: 'Always use dark theme',
                isSelected: themeMode == ThemeMode.dark,
                onTap: () => ref.read(settingsProvider.notifier).setThemeMode(ThemeMode.dark),
              ),
            ],
          ),

          // Preview
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Container(
              padding: EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark 
                      ? Colors.white.withValues(alpha: 0.08) 
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preview',
                    style: AppTypography.small.copyWith(
                      color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              'Primary',
                              style: AppTypography.small.copyWith(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              'Success',
                              style: AppTypography.small.copyWith(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.errorLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              'Error',
                              style: AppTypography.small.copyWith(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: (isSelected ? AppColors.primaryLight : Colors.grey).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? AppColors.primaryLight : Colors.grey,
        ),
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
      trailing: isSelected
          ? Icon(Icons.check_circle, color: AppColors.primaryLight)
          : null,
      onTap: onTap,
    );
  }
}

