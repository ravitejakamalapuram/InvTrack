import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_calculation_result.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Card displaying FIRE number breakdown
class FireStatsCard extends ConsumerWidget {
  final FireCalculationResult calculation;
  final String currencySymbol;

  /// The settings [calculation] used, to explain the FIRE number.
  final FireSettingsEntity? settings;

  const FireStatsCard({
    super.key,
    required this.calculation,
    required this.currencySymbol,
    this.settings,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = ref.watch(currencyLocaleProvider);
    final l10n = AppLocalizations.of(context);
    final settings = this.settings;
    String compact(double amount) =>
        formatCompactCurrency(amount, symbol: currencySymbol, locale: locale);

    // Theme-aware colors for FIRE type icons
    final fireColor = isDark ? AppColors.accentDark : AppColors.accentLight;
    final coastColor = isDark ? AppColors.successDark : AppColors.successLight;
    final baristaColor = isDark
        ? AppColors.warningDark
        : AppColors.warningLight;

    return GlassCard(
      child: Column(
        children: [
          _buildStatRow(
            context,
            isDark,
            icon: Icons.local_fire_department,
            iconColor: fireColor,
            label: 'FIRE Number',
            value: formatCompactCurrency(
              calculation.fireNumber,
              symbol: currencySymbol,
              locale: locale,
            ),
            // The real multiple, buffers included (PLAN-06).
            subtitle: l10n.fireNumberMultiple(
              calculation.expenseMultiple.toStringAsFixed(1),
            ),
            tooltip: settings == null
                ? null
                : l10n.fireNumberExplanation(
                    _trim(settings.safeWithdrawalRate),
                    _trim(settings.healthcareBuffer),
                    _trim(settings.emergencyMonths),
                  ),
          ),
          SizedBox(height: AppSpacing.sm),
          _buildBreakdownRow(
            isDark,
            l10n.fireCoreCorpus,
            compact(calculation.coreRetirementCorpus),
          ),
          _buildBreakdownRow(
            isDark,
            l10n.fireHealthcareBuffer,
            compact(calculation.healthcareCorpusNeeded),
          ),
          _buildBreakdownRow(
            isDark,
            l10n.fireEmergencyFund,
            compact(calculation.emergencyFundNeeded),
          ),
          Divider(
            height: AppSpacing.lg,
            color: isDark
                ? AppColors.neutral700Dark
                : AppColors.neutral200Light,
          ),
          _buildStatRow(
            context,
            isDark,
            icon: Icons.beach_access_outlined,
            iconColor: coastColor,
            label: 'Coast FIRE',
            value: formatCompactCurrency(
              calculation.coastFireNumber,
              symbol: currencySymbol,
              locale: locale,
            ),
            subtitle: 'Save this, then stop saving',
            tooltip:
                'If you have this amount today, you can stop saving entirely. '
                'Your investments will grow to your FIRE Number by retirement age through real (inflation-adjusted) compound growth. '
                'This accounts for inflation, so the growth maintains purchasing power.',
          ),
          Divider(
            height: AppSpacing.lg,
            color: isDark
                ? AppColors.neutral700Dark
                : AppColors.neutral200Light,
          ),
          _buildStatRow(
            context,
            isDark,
            icon: Icons.coffee_outlined,
            iconColor: baristaColor,
            label: 'Barista FIRE',
            value: formatCompactCurrency(
              calculation.baristaFireNumber,
              symbol: currencySymbol,
              locale: locale,
            ),
            subtitle: 'Part-time income covers the rest',
            tooltip:
                '50% of your FIRE Number. With this amount, you could retire from full-time work '
                'and cover the gap with part-time or freelance work.',
          ),
        ],
      ),
    );
  }

  /// [value] without a trailing ".0".
  static String _trim(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();

  Widget _buildBreakdownRow(bool isDark, String label, String value) {
    final style = AppTypography.small.copyWith(
      color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
    );
    return Padding(
      padding: EdgeInsets.only(left: 48, top: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          MaskedAmountText(text: value, style: style),
        ],
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subtitle,
    String? tooltip,
  }) {
    final row = Row(
      children: [
        Container(
          padding: EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: AppTypography.bodyMedium.copyWith(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (tooltip != null) ...[
                    SizedBox(width: AppSpacing.xs),
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: isDark
                          ? AppColors.neutral400Dark
                          : AppColors.neutral500Light,
                    ),
                  ],
                ],
              ),
              Text(
                subtitle,
                style: AppTypography.small.copyWith(
                  color: isDark
                      ? AppColors.neutral400Dark
                      : AppColors.neutral500Light,
                ),
              ),
            ],
          ),
        ),
        MaskedAmountText(
          text: value,
          style: AppTypography.h3.copyWith(
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip,
        preferBelow: true,
        showDuration: const Duration(seconds: 4),
        triggerMode: TooltipTriggerMode.tap,
        child: row,
      );
    }
    return row;
  }
}
