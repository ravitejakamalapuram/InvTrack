/// Help & FAQ screen with app usage information
library;

import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Screen displaying help and frequently asked questions about using the app
class HelpFaqScreen extends StatelessWidget {
  const HelpFaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpFaqTitle, style: AppTypography.h3)),
      body: ListView(
        padding: EdgeInsets.all(AppSpacing.md),
        children: [
          _buildSection(l10n.gettingStarted, [
            _buildFaqItem(
              l10n.howToAddFirstInvestment,
              l10n.howToAddFirstInvestmentAnswer,
              isDark,
            ),
            _buildFaqItem(
              l10n.whatInvestmentTypesSupported,
              l10n.whatInvestmentTypesSupportedAnswer,
              isDark,
            ),
          ]),
          _buildSection(l10n.trackingReturns, [
            _buildFaqItem(
              l10n.howAreReturnsCalculated,
              l10n.howAreReturnsCalculatedAnswer,
              isDark,
            ),
            _buildFaqItem(l10n.whatIsXirr, l10n.whatIsXirrAnswer, isDark),
          ]),
          _buildSection(l10n.goalsSection, [
            _buildFaqItem(
              l10n.howToSetFinancialGoal,
              l10n.howToSetFinancialGoalAnswer,
              isDark,
            ),
            _buildFaqItem(
              l10n.canLinkInvestmentsToGoals,
              l10n.canLinkInvestmentsToGoalsAnswer,
              isDark,
            ),
          ]),
          _buildSection(l10n.privacyAndSecurity, [
            _buildFaqItem(
              l10n.isMyDataSecure,
              l10n.isMyDataSecureAnswer,
              isDark,
            ),
            _buildFaqItem(
              l10n.whatIsPrivacyMode,
              l10n.whatIsPrivacyModeAnswer,
              isDark,
            ),
          ]),
          _buildSection(l10n.dataManagementSection, [
            _buildFaqItem(
              l10n.canExportMyData,
              l10n.canExportMyDataAnswer,
              isDark,
            ),
            _buildFaqItem(
              l10n.howToBackupData,
              l10n.howToBackupDataAnswer,
              isDark,
            ),
          ]),
          _buildSection(l10n.multiCurrencySupport, [
            _buildFaqItem(
              l10n.canChangeMyCurrency,
              l10n.canChangeMyCurrencyAnswer,
              isDark,
            ),
            _buildFaqItem(
              l10n.howDoesCurrencyFormattingWork,
              l10n.howDoesCurrencyFormattingWorkAnswer,
              isDark,
            ),
          ]),
          SizedBox(height: AppSpacing.xl),
          Center(
            child: Text(
              l10n.needMoreHelpContact,
              style: AppTypography.small.copyWith(
                color: isDark
                    ? AppColors.neutral400Dark
                    : AppColors.neutral500Light,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
          child: Text(
            title,
            style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ...items,
      ],
    );
  }

  Widget _buildFaqItem(String question, String answer, bool isDark) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.neutral900Light,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            answer,
            style: AppTypography.body.copyWith(
              color: isDark
                  ? AppColors.neutral300Dark
                  : AppColors.neutral600Light,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
