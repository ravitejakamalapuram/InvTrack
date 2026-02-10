import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/router/navigation_extensions.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_sizes.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/presentation/extensions/fire_entity_ui_extensions.dart';
import 'package:inv_tracker/features/fire_number/presentation/providers/fire_notifier.dart';
import 'package:inv_tracker/features/fire_number/presentation/providers/fire_providers.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// FIRE settings editing screen
class FireSettingsScreen extends ConsumerWidget {
  const FireSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settingsAsync = ref.watch(fireSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(l10n.fireSettings, style: AppTypography.h2),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.safePop(),
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
                  Text(l10n.noFireSettingsFound),
                  SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: () => context.push('/fire/setup'),
                    child: Text(l10n.setUpFire),
                  ),
                ],
              ),
            );
          }
          return _buildSettingsList(context, ref, isDark, settings);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildErrorState(context, ref, isDark),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.errorLight.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: AppSizes.iconXl,
                color: AppColors.errorLight,
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              'Connection Error',
              style: AppTypography.h3.copyWith(
                color: isDark ? Colors.white : AppColors.neutral900Light,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Failed to load FIRE settings. Please try again.',
              style: AppTypography.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.neutral400Dark
                    : AppColors.neutral500Light,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.lg),
            TextButton.icon(
              onPressed: () => ref.invalidate(fireSettingsProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsList(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    FireSettingsEntity settings,
  ) {
    final l10n = AppLocalizations.of(context);
    final currencySymbol = ref.watch(currencySymbolProvider);

    return SingleChildScrollView(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Settings
          Text(l10n.basicSettings, style: AppTypography.h3.copyWith(
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
          Text(l10n.advancedSettings, style: AppTypography.h3.copyWith(
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
          Text(l10n.dangerZone, style: AppTypography.h3.copyWith(
            color: isDark ? AppColors.dangerDark : AppColors.dangerLight,
          )),
          SizedBox(height: AppSpacing.sm),
          GlassCard(
            child: ListTile(
              leading: Icon(Icons.delete_forever, color: isDark ? AppColors.dangerDark : AppColors.dangerLight),
              title: Text(l10n.resetFireSettings, style: AppTypography.bodyMedium.copyWith(
                color: isDark ? AppColors.dangerDark : AppColors.dangerLight,
              )),
              subtitle: Text(l10n.startOverWithNewSettings),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = isCurrentAge ? 'Current Age' : 'Target FIRE Age';
    final currentValue = isCurrentAge ? settings.currentAge : settings.targetFireAge;
    final minAge = isCurrentAge ? 18 : settings.currentAge + 5;
    final maxAge = isCurrentAge ? 80 : 80;

    int selectedAge = currentValue;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final l10n = AppLocalizations.of(context);
          return Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg,
                MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.h3.copyWith(
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                )),
                SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$selectedAge years', style: AppTypography.h1.copyWith(
                      color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                    )),
                  ],
                ),
                Slider(
                  value: selectedAge.toDouble(),
                  min: minAge.toDouble(),
                  max: maxAge.toDouble(),
                  divisions: maxAge - minAge,
                  label: '$selectedAge',
                  onChanged: (v) => setState(() => selectedAge = v.toInt()),
                ),
                SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final updated = isCurrentAge
                          ? settings.copyWith(currentAge: selectedAge)
                          : settings.copyWith(targetFireAge: selectedAge);
                      await ref.read(fireSettingsNotifierProvider.notifier).saveSettings(updated);
                    },
                    child: Text(l10n.save),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showExpensesEditor(BuildContext context, WidgetRef ref, FireSettingsEntity settings) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencySymbol = ref.read(currencySymbolProvider);
    final controller = TextEditingController(text: settings.monthlyExpenses.toStringAsFixed(0));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg,
            MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.monthlyExpenses, style: AppTypography.h3.copyWith(
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            )),
            SizedBox(height: AppSpacing.lg),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: '$currencySymbol ',
                labelText: l10n.monthlyExpenses,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final value = double.tryParse(controller.text) ?? settings.monthlyExpenses;
                  final updated = settings.copyWith(monthlyExpenses: value);
                  await ref.read(fireSettingsNotifierProvider.notifier).saveSettings(updated);
                },
                child: Text(l10n.save),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() => controller.dispose());
  }

  void _showFireTypeSelector(BuildContext context, WidgetRef ref, FireSettingsEntity settings) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.selectFireType, style: AppTypography.h3.copyWith(
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            )),
            SizedBox(height: AppSpacing.md),
            ...FireType.values.map((type) => ListTile(
              leading: Icon(type.icon, color: isDark ? AppColors.primaryDark : AppColors.primaryLight),
              title: Text(type.displayName),
              subtitle: Text(type.description, style: AppTypography.small),
              selected: settings.fireType == type,
              selectedTileColor: (isDark ? AppColors.primaryDark : AppColors.primaryLight).withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () async {
                Navigator.pop(ctx);
                final updated = settings.copyWith(fireType: type);
                await ref.read(fireSettingsNotifierProvider.notifier).saveSettings(updated);
              },
            )),
          ],
        ),
      ),
    );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double selectedValue = currentValue;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final l10n = AppLocalizations.of(context);
          return Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg,
                MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.h3.copyWith(
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                )),
                SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${selectedValue.toStringAsFixed(1)}%', style: AppTypography.h1.copyWith(
                      color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                    )),
                  ],
                ),
                Slider(
                  value: selectedValue,
                  min: min,
                  max: max,
                  divisions: ((max - min) * 10).toInt(),
                  label: '${selectedValue.toStringAsFixed(1)}%',
                  onChanged: (v) => setState(() => selectedValue = v),
                ),
                SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final updated = onSave(selectedValue);
                      await ref.read(fireSettingsNotifierProvider.notifier).saveSettings(updated);
                    },
                    child: Text(l10n.save),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.resetFireSettingsConfirm),
          content: Text(l10n.resetFireSettingsMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await ref.read(fireSettingsNotifierProvider.notifier).resetSettings();
                if (context.mounted) {
                  context.go('/fire');
                }
              },
              child: Text(l10n.reset, style: TextStyle(color: AppColors.dangerLight)),
            ),
          ],
        );
      },
    );
  }
}
