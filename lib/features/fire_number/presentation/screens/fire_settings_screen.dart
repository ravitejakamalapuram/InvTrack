import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/error/error_handler.dart';
import 'package:inv_tracker/core/router/navigation_extensions.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_sizes.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/amount_input.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/domain/services/fire_settings_validator.dart';
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
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(l10n.fireSettings, style: AppTypography.h2),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.safePop(),
          tooltip: l10n.tooltipBack,
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
              l10n.connectionError,
              style: AppTypography.h3.copyWith(
                color: isDark ? Colors.white : AppColors.neutral900Light,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              l10n.failedToLoadFireSettings,
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

  Widget _divider(bool isDark) => Divider(
    color: isDark ? AppColors.neutral700Dark : AppColors.neutral200Light,
  );

  Widget _buildSettingsList(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    FireSettingsEntity settings,
  ) {
    final l10n = AppLocalizations.of(context);
    // Amounts are shown in the currency they were entered in, which can
    // differ from the base currency after a switch (GAP2-01).
    final String currency =
        settings.currency ?? ref.watch(currencyCodeProvider);
    final currencySymbol = getCurrencySymbol(currency);
    String amount(double value) => '$currencySymbol${value.toStringAsFixed(0)}';
    final sip = settings.monthlySip;

    return SingleChildScrollView(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Settings
          Text(
            l10n.basicSettings,
            style: AppTypography.h3.copyWith(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            l10n.fireAmountsInCurrency(currency),
            style: AppTypography.small.copyWith(
              color: isDark
                  ? AppColors.neutral400Dark
                  : AppColors.neutral500Light,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          GlassCard(
            child: Column(
              children: [
                _buildSettingTile(
                  context,
                  isDark,
                  icon: Icons.calendar_today,
                  title: 'Current Age',
                  value: '${settings.currentAge} years',
                  onTap: () => _showAgeEditor(
                    context,
                    ref,
                    settings,
                    isCurrentAge: true,
                  ),
                ),
                _divider(isDark),
                _buildSettingTile(
                  context,
                  isDark,
                  icon: Icons.flag_outlined,
                  title: 'Target FIRE Age',
                  value: '${settings.targetFireAge} years',
                  onTap: () => _showAgeEditor(
                    context,
                    ref,
                    settings,
                    isCurrentAge: false,
                  ),
                ),
                _divider(isDark),
                _buildSettingTile(
                  context,
                  isDark,
                  icon: Icons.payments_outlined,
                  title: 'Monthly Expenses',
                  value: amount(settings.monthlyExpenses),
                  isAmount: true,
                  onTap: () => _showAmountEditor(
                    context,
                    ref,
                    title: l10n.monthlyExpenses,
                    currencySymbol: currencySymbol,
                    initial: settings.monthlyExpenses,
                    onSave: (v) => settings.copyWith(monthlyExpenses: v),
                  ),
                ),
                _divider(isDark),
                _buildSettingTile(
                  context,
                  isDark,
                  icon: settings.fireType.effective.icon,
                  title: 'FIRE Type',
                  value: settings.fireType.effective.displayName,
                  onTap: () => _showFireTypeSelector(context, ref, settings),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.lg),

          // What the user has and invests
          GlassCard(
            child: Column(
              children: [
                _buildSettingTile(
                  context,
                  isDark,
                  icon: Icons.account_balance_outlined,
                  title: l10n.fireOtherAssets,
                  value: amount(settings.otherAssets),
                  isAmount: true,
                  onTap: () => _showAmountEditor(
                    context,
                    ref,
                    title: l10n.fireOtherAssets,
                    hint: l10n.fireOtherAssetsHint,
                    currencySymbol: currencySymbol,
                    initial: settings.otherAssets,
                    onSave: (v) => settings.copyWith(otherAssets: v),
                  ),
                ),
                _divider(isDark),
                _buildSettingTile(
                  context,
                  isDark,
                  icon: Icons.savings_outlined,
                  title: l10n.fireMonthlySip,
                  value: sip == null
                      ? l10n.fireMonthlySipEstimated
                      : amount(sip),
                  isAmount: sip != null,
                  onTap: () => _showAmountEditor(
                    context,
                    ref,
                    title: l10n.fireMonthlySip,
                    hint: l10n.fireMonthlySipHint,
                    currencySymbol: currencySymbol,
                    initial: sip,
                    allowEmpty: true,
                    onSave: (v) => v == null
                        ? settings.copyWith(clearMonthlySip: true)
                        : settings.copyWith(monthlySip: v),
                  ),
                ),
                _divider(isDark),
                _buildSettingTile(
                  context,
                  isDark,
                  icon: Icons.home_work_outlined,
                  title: l10n.firePassiveIncome,
                  value: amount(settings.monthlyPassiveIncome),
                  isAmount: true,
                  onTap: () => _showAmountEditor(
                    context,
                    ref,
                    title: l10n.firePassiveIncome,
                    currencySymbol: currencySymbol,
                    initial: settings.monthlyPassiveIncome,
                    onSave: (v) => settings.copyWith(monthlyPassiveIncome: v),
                  ),
                ),
                _divider(isDark),
                _buildSettingTile(
                  context,
                  isDark,
                  icon: Icons.elderly_outlined,
                  title: l10n.firePension,
                  value: amount(settings.expectedPension),
                  isAmount: true,
                  onTap: () => _showAmountEditor(
                    context,
                    ref,
                    title: l10n.firePension,
                    currencySymbol: currencySymbol,
                    initial: settings.expectedPension,
                    onSave: (v) => settings.copyWith(expectedPension: v),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.lg),

          // Advanced Settings
          Text(
            l10n.advancedSettings,
            style: AppTypography.h3.copyWith(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          GlassCard(
            child: Column(
              children: [
                _buildSettingTile(
                  context,
                  isDark,
                  icon: Icons.percent,
                  title: 'Safe Withdrawal Rate',
                  value: '${settings.safeWithdrawalRate}%',
                  onTap: () => _showSliderEditor(
                    context,
                    ref,
                    title: 'Safe Withdrawal Rate',
                    currentValue: settings.safeWithdrawalRate,
                    min: 2.5,
                    max: 5.0,
                    onSave: (v) => settings.copyWith(safeWithdrawalRate: v),
                  ),
                ),
                _divider(isDark),
                _buildSettingTile(
                  context,
                  isDark,
                  icon: Icons.trending_up,
                  title: 'Inflation Rate',
                  value: '${settings.inflationRate}%',
                  onTap: () => _showSliderEditor(
                    context,
                    ref,
                    title: 'Inflation Rate',
                    currentValue: settings.inflationRate,
                    min: 4.0,
                    max: 10.0,
                    onSave: (v) => settings.copyWith(inflationRate: v),
                  ),
                ),
                _divider(isDark),
                _buildSettingTile(
                  context,
                  isDark,
                  icon: Icons.show_chart,
                  title: 'Pre-retirement Return',
                  value: '${settings.preRetirementReturn}%',
                  onTap: () => _showSliderEditor(
                    context,
                    ref,
                    title: 'Pre-retirement Return',
                    currentValue: settings.preRetirementReturn,
                    min: 8.0,
                    max: 15.0,
                    onSave: (v) => settings.copyWith(preRetirementReturn: v),
                  ),
                ),
                _divider(isDark),
                _buildSettingTile(
                  context,
                  isDark,
                  icon: Icons.health_and_safety_outlined,
                  title: l10n.fireHealthcareBuffer,
                  value: l10n.percentageFormat(
                    settings.healthcareBuffer.toStringAsFixed(0),
                  ),
                  onTap: () => _showSliderEditor(
                    context,
                    ref,
                    title: l10n.fireHealthcareBuffer,
                    currentValue: settings.healthcareBuffer,
                    min: 0,
                    max: 50,
                    divisions: 50,
                    label: (v) => l10n.percentageFormat(v.toStringAsFixed(0)),
                    onSave: (v) => settings.copyWith(healthcareBuffer: v),
                  ),
                ),
                _divider(isDark),
                _buildSettingTile(
                  context,
                  isDark,
                  icon: Icons.shield_outlined,
                  title: l10n.fireEmergencyFund,
                  value: l10n.fireMonthsCount(
                    settings.emergencyMonths.toStringAsFixed(0),
                  ),
                  onTap: () => _showSliderEditor(
                    context,
                    ref,
                    title: l10n.fireEmergencyFund,
                    currentValue: settings.emergencyMonths,
                    min: 0,
                    max: 24,
                    divisions: 24,
                    label: (v) => l10n.fireMonthsCount(v.toStringAsFixed(0)),
                    onSave: (v) => settings.copyWith(emergencyMonths: v),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.lg),

          // Danger Zone
          Text(
            l10n.dangerZone,
            style: AppTypography.h3.copyWith(
              color: isDark ? AppColors.dangerDark : AppColors.dangerLight,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          GlassCard(
            child: ListTile(
              leading: Icon(
                Icons.delete_forever,
                color: isDark ? AppColors.dangerDark : AppColors.dangerLight,
              ),
              title: Text(
                l10n.resetFireSettings,
                style: AppTypography.bodyMedium.copyWith(
                  color: isDark ? AppColors.dangerDark : AppColors.dangerLight,
                ),
              ),
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
    bool isAmount = false,
  }) {
    final valueStyle = AppTypography.body.copyWith(
      color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
    );
    return ListTile(
      leading: Icon(
        icon,
        color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
      ),
      title: Text(
        title,
        style: AppTypography.bodyMedium.copyWith(
          color: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          isAmount
              ? MaskedAmountText(text: value, style: valueStyle)
              : Text(value, style: valueStyle),
          SizedBox(width: AppSpacing.xs),
          Icon(
            Icons.chevron_right,
            color: isDark
                ? AppColors.neutral500Dark
                : AppColors.neutral400Light,
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  /// Saves [updated] from a bottom sheet: closes it on success, and keeps it
  /// open with the reason when the settings are rejected (PLAN-07).
  Future<void> _saveFromSheet(
    BuildContext sheetContext,
    WidgetRef ref,
    FireSettingsEntity updated,
    void Function(String error) showError,
  ) async {
    try {
      await ref
          .read(fireSettingsNotifierProvider.notifier)
          .saveSettings(updated.copyWith(updatedAt: DateTime.now()));
      if (sheetContext.mounted) Navigator.pop(sheetContext);
    } on FireSettingsValidationException catch (e) {
      showError(e.errors.join('\n'));
    } catch (e, st) {
      if (sheetContext.mounted) {
        ErrorHandler.handle(e, st, context: sheetContext, showFeedback: true);
      }
    }
  }

  Widget _sheetError(String? error) {
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: AppSpacing.sm),
      child: Text(
        error,
        style: AppTypography.small.copyWith(color: AppColors.errorLight),
      ),
    );
  }

  void _showAgeEditor(
    BuildContext context,
    WidgetRef ref,
    FireSettingsEntity settings, {
    required bool isCurrentAge,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = isCurrentAge ? 'Current Age' : 'Target FIRE Age';
    final currentAge = settings.currentAge;
    // The target is always after the current age, and every range has room
    // to move (PLAN-07).
    final targetRange = FireAgeLimits.targetRange(currentAge);
    final minAge = isCurrentAge ? FireAgeLimits.minCurrentAge : targetRange.min;
    final maxAge = isCurrentAge ? FireAgeLimits.maxCurrentAge : targetRange.max;

    int selectedAge = (isCurrentAge ? currentAge : settings.targetFireAge)
        .clamp(minAge, maxAge);
    String? error;

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
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.h3.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.yearsFormat(selectedAge),
                      style: AppTypography.h1.copyWith(
                        color: isDark
                            ? AppColors.primaryDark
                            : AppColors.primaryLight,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: selectedAge.toDouble(),
                  min: minAge.toDouble(),
                  max: maxAge.toDouble(),
                  divisions: maxAge - minAge,
                  label: '$selectedAge',
                  onChanged: (v) => setState(() => selectedAge = v.round()),
                ),
                _sheetError(error),
                SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _saveFromSheet(
                      ctx,
                      ref,
                      isCurrentAge
                          ? settings.copyWith(
                              birthYear: FireSettingsEntity.birthYearForAge(
                                selectedAge,
                                DateTime.now(),
                              ),
                            )
                          : settings.copyWith(targetFireAge: selectedAge),
                      (e) => setState(() => error = e),
                    ),
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

  /// Edits an amount. Grouped input ("1,25,000") is accepted; invalid input
  /// keeps the sheet open instead of falling back to another value (UX-10).
  /// With [allowEmpty], an empty field saves null.
  void _showAmountEditor(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String currencySymbol,
    required double? initial,
    required FireSettingsEntity Function(double? value) onSave,
    String? hint,
    bool allowEmpty = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AmountEditorSheet(
        title: title,
        hint: hint,
        currencySymbol: currencySymbol,
        initial: initial,
        allowEmpty: allowEmpty,
        onSave: (value, showError) =>
            _saveFromSheet(ctx, ref, onSave(value), showError),
      ),
    );
  }

  void _showFireTypeSelector(
    BuildContext context,
    WidgetRef ref,
    FireSettingsEntity settings,
  ) {
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
            Text(
              l10n.selectFireType,
              style: AppTypography.h3.copyWith(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            SizedBox(height: AppSpacing.md),
            ...FireType.selectable.map(
              (type) => ListTile(
                leading: Icon(
                  type.icon,
                  color: isDark
                      ? AppColors.primaryDark
                      : AppColors.primaryLight,
                ),
                title: Text(type.displayName),
                subtitle: Text(type.description, style: AppTypography.small),
                selected: settings.fireType.effective == type,
                selectedTileColor:
                    (isDark ? AppColors.primaryDark : AppColors.primaryLight)
                        .withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () => _saveFromSheet(
                  ctx,
                  ref,
                  settings.copyWith(fireType: type),
                  (e) => ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(e))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSliderEditor(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required double currentValue,
    required double min,
    required double max,
    required FireSettingsEntity Function(double) onSave,
    int? divisions,
    String Function(double value)? label,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double selectedValue = currentValue.clamp(min, max);
    String? error;

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
          final valueLabel =
              label?.call(selectedValue) ??
              l10n.percentageFormat(selectedValue.toStringAsFixed(1));
          return Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.h3.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      valueLabel,
                      style: AppTypography.h1.copyWith(
                        color: isDark
                            ? AppColors.primaryDark
                            : AppColors.primaryLight,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: selectedValue,
                  min: min,
                  max: max,
                  divisions: divisions ?? ((max - min) * 10).round(),
                  label: valueLabel,
                  onChanged: (v) => setState(() => selectedValue = v),
                ),
                _sheetError(error),
                SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _saveFromSheet(
                      ctx,
                      ref,
                      onSave(selectedValue),
                      (e) => setState(() => error = e),
                    ),
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
                await ref
                    .read(fireSettingsNotifierProvider.notifier)
                    .resetSettings();
                if (context.mounted) {
                  context.go('/fire');
                }
              },
              child: Text(
                l10n.reset,
                style: TextStyle(color: AppColors.dangerLight),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Bottom sheet that edits one amount. It owns its text controller, which
/// must outlive the sheet's closing animation.
class _AmountEditorSheet extends StatefulWidget {
  const _AmountEditorSheet({
    required this.title,
    required this.currencySymbol,
    required this.initial,
    required this.allowEmpty,
    required this.onSave,
    this.hint,
  });

  final String title;
  final String? hint;
  final String currencySymbol;
  final double? initial;
  final bool allowEmpty;
  final Future<void> Function(double? value, void Function(String) showError)
  onSave;

  @override
  State<_AmountEditorSheet> createState() => _AmountEditorSheetState();
}

class _AmountEditorSheetState extends State<_AmountEditorSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial?.toStringAsFixed(0) ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save(AppLocalizations l10n) {
    final text = _controller.text.trim();
    final value = parseAmountInput(text);
    if (value == null && !(widget.allowEmpty && text.isEmpty)) {
      setState(() => _error = l10n.fireEnterValidAmount);
      return;
    }
    widget.onSave(value, (e) {
      if (mounted) setState(() => _error = e);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final error = _error;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: AppTypography.h3.copyWith(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: amountInputFormatters,
            decoration: InputDecoration(
              prefixText: '${widget.currencySymbol} ',
              labelText: widget.title,
              helperText: widget.hint,
              helperMaxLines: 2,
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          if (error != null)
            Padding(
              padding: EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                error,
                style: AppTypography.small.copyWith(
                  color: AppColors.errorLight,
                ),
              ),
            ),
          SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _save(l10n),
              child: Text(l10n.save),
            ),
          ),
        ],
      ),
    );
  }
}
