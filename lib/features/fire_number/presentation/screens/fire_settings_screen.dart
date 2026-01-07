import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/presentation/extensions/fire_entity_ui_extensions.dart';
import 'package:inv_tracker/features/fire_number/presentation/providers/fire_notifier.dart';
import 'package:inv_tracker/features/fire_number/presentation/providers/fire_providers.dart';

/// FIRE settings editing screen
class FireSettingsScreen extends ConsumerWidget {
  const FireSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(fireSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('FIRE Settings', style: AppTypography.h2),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
      ),
      body: settingsAsync.when(
        data: (settings) {
          if (settings == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('No FIRE settings found'),
                  SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: () => context.push('/fire/setup'),
                    child: const Text('Set Up FIRE'),
                  ),
                ],
              ),
            );
          }
          return _buildSettingsList(context, ref, isDark, settings);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildSettingsList(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    FireSettingsEntity settings,
  ) {
    final currencySymbol = ref.watch(currencySymbolProvider);

    return SingleChildScrollView(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Settings
          Text('Basic Settings', style: AppTypography.h3.copyWith(
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          )),
          SizedBox(height: AppSpacing.sm),
          GlassCard(
            child: Column(
              children: [
                _buildSettingTile(
                  context, isDark,
                  icon: Icons.calendar_today,
                  title: 'Current Age',
                  value: '${settings.currentAge} years',
                  onTap: () => _showAgeEditor(context, ref, settings, isCurrentAge: true),
                ),
                Divider(color: isDark ? AppColors.neutral700Dark : AppColors.neutral200Light),
                _buildSettingTile(
                  context, isDark,
                  icon: Icons.flag_outlined,
                  title: 'Target FIRE Age',
                  value: '${settings.targetFireAge} years',
                  onTap: () => _showAgeEditor(context, ref, settings, isCurrentAge: false),
                ),
                Divider(color: isDark ? AppColors.neutral700Dark : AppColors.neutral200Light),
                _buildSettingTile(
                  context, isDark,
                  icon: Icons.payments_outlined,
                  title: 'Monthly Expenses',
                  value: '$currencySymbol${settings.monthlyExpenses.toStringAsFixed(0)}',
                  onTap: () => _showExpensesEditor(context, ref, settings),
                ),
                Divider(color: isDark ? AppColors.neutral700Dark : AppColors.neutral200Light),
                _buildSettingTile(
                  context, isDark,
                  icon: settings.fireType.icon,
                  title: 'FIRE Type',
                  value: settings.fireType.displayName,
                  onTap: () => _showFireTypeSelector(context, ref, settings),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.lg),

          // Advanced Settings
          Text('Advanced Settings', style: AppTypography.h3.copyWith(
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          )),
          SizedBox(height: AppSpacing.sm),
          GlassCard(
            child: Column(
              children: [
                _buildSettingTile(
                  context, isDark,
                  icon: Icons.percent,
                  title: 'Safe Withdrawal Rate',
                  value: '${settings.safeWithdrawalRate}%',
                  onTap: () => _showSliderEditor(
                    context, ref, settings,
                    title: 'Safe Withdrawal Rate',
                    currentValue: settings.safeWithdrawalRate,
                    min: 2.5, max: 5.0,
                    onSave: (v) => settings.copyWith(safeWithdrawalRate: v),
                  ),
                ),
                Divider(color: isDark ? AppColors.neutral700Dark : AppColors.neutral200Light),
                _buildSettingTile(
                  context, isDark,
                  icon: Icons.trending_up,
                  title: 'Inflation Rate',
                  value: '${settings.inflationRate}%',
                  onTap: () => _showSliderEditor(
                    context, ref, settings,
                    title: 'Inflation Rate',
                    currentValue: settings.inflationRate,
                    min: 4.0, max: 10.0,
                    onSave: (v) => settings.copyWith(inflationRate: v),
                  ),
                ),
                Divider(color: isDark ? AppColors.neutral700Dark : AppColors.neutral200Light),
                _buildSettingTile(
                  context, isDark,
                  icon: Icons.show_chart,
                  title: 'Pre-retirement Return',
                  value: '${settings.preRetirementReturn}%',
                  onTap: () => _showSliderEditor(
                    context, ref, settings,
                    title: 'Pre-retirement Return',
                    currentValue: settings.preRetirementReturn,
                    min: 8.0, max: 15.0,
                    onSave: (v) => settings.copyWith(preRetirementReturn: v),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.lg),

          // Danger Zone
          Text('Danger Zone', style: AppTypography.h3.copyWith(
            color: isDark ? AppColors.dangerDark : AppColors.dangerLight,
          )),
          SizedBox(height: AppSpacing.sm),
          GlassCard(
            child: ListTile(
              leading: Icon(Icons.delete_forever, color: isDark ? AppColors.dangerDark : AppColors.dangerLight),
              title: Text('Reset FIRE Settings', style: AppTypography.bodyMedium.copyWith(
                color: isDark ? AppColors.dangerDark : AppColors.dangerLight,
              )),
              subtitle: Text('Start over with new settings'),
              onTap: () => _confirmReset(context, ref),
            ),
          ),
          SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: isDark ? AppColors.primaryDark : AppColors.primaryLight),
      title: Text(title, style: AppTypography.bodyMedium.copyWith(
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      )),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: AppTypography.body.copyWith(
            color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
          )),
          SizedBox(width: AppSpacing.xs),
          Icon(Icons.chevron_right, color: isDark ? AppColors.neutral500Dark : AppColors.neutral400Light),
        ],
      ),
      onTap: onTap,
    );
  }

  void _showAgeEditor(BuildContext context, WidgetRef ref, FireSettingsEntity settings, {required bool isCurrentAge}) {
    // Implementation for age editor dialog
  }

  void _showExpensesEditor(BuildContext context, WidgetRef ref, FireSettingsEntity settings) {
    // Implementation for expenses editor dialog
  }

  void _showFireTypeSelector(BuildContext context, WidgetRef ref, FireSettingsEntity settings) {
    // Implementation for fire type selector
  }

  void _showSliderEditor(
    BuildContext context,
    WidgetRef ref,
    FireSettingsEntity settings, {
    required String title,
    required double currentValue,
    required double min,
    required double max,
    required FireSettingsEntity Function(double) onSave,
  }) {
    // Implementation for slider editor dialog
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset FIRE Settings?'),
        content: const Text('This will delete all your FIRE settings. You will need to set them up again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(fireSettingsNotifierProvider.notifier).resetSettings();
              if (context.mounted) {
                context.go('/fire');
              }
            },
            child: Text('Reset', style: TextStyle(color: AppColors.dangerLight)),
          ),
        ],
      ),
    );
  }
}

