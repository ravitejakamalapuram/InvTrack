import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_calculation_result.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// How the FIRE corpus is built: current values, principal of holdings
/// without one, and other assets. Closed and archived investments are
/// left out, and the card says so (money rule 9).
class FireCorpusCard extends StatelessWidget {
  const FireCorpusCard({
    super.key,
    required this.calculation,
    required this.currencySymbol,
    required this.locale,
  });

  final FireCalculationResult calculation;
  final String currencySymbol;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputs = calculation.inputs;
    final labelStyle = AppTypography.body.copyWith(
      color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
    );
    final valueStyle = AppTypography.bodyMedium.copyWith(
      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      fontWeight: FontWeight.w600,
    );
    Widget row(String label, double amount) => Padding(
      padding: EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: labelStyle)),
          SizedBox(width: AppSpacing.sm),
          MaskedAmountText(
            text: formatCompactCurrency(
              amount,
              symbol: currencySymbol,
              locale: locale,
            ),
            style: valueStyle,
          ),
        ],
      ),
    );

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.fireCorpusTitle,
            style: AppTypography.h4.copyWith(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          if (inputs != null) ...[
            row(l10n.fireCorpusCurrentValues, inputs.investmentsValue),
            if (inputs.principalWithoutValue > 0)
              row(l10n.fireCorpusPrincipalOnly, inputs.principalWithoutValue),
            if (inputs.otherAssets > 0)
              row(l10n.fireOtherAssets, inputs.otherAssets),
          ],
          SizedBox(height: AppSpacing.sm),
          Text(
            l10n.fireCorpusExcluded,
            style: AppTypography.small.copyWith(
              color: isDark
                  ? AppColors.neutral500Dark
                  : AppColors.neutral400Light,
            ),
          ),
        ],
      ),
    );
  }
}
