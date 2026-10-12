/// Help & FAQ screen with app usage information
library;

import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/settings/presentation/screens/account_deletion_page.dart';
import 'package:inv_tracker/features/settings/presentation/screens/legal_content.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/delete_account_web_link.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Screen displaying help and frequently asked questions about using the app
class HelpFaqScreen extends StatelessWidget {
  const HelpFaqScreen({
    super.key,
    required this.showDeveloperFaq,
    this.showCustomTypesFaq = false,
    this.showIncomeGuardianFaq = false,
    this.showPortfolioHealthFaq = false,
  });

  /// Whether to explain the developer tools. Callers pass
  /// developerToolsAvailableProvider, which is false in release builds.
  final bool showDeveloperFaq;

  /// Whether to explain custom types for Other investments (#936). Callers
  /// pass isCustomInvestmentTypesEnabledProvider, so the FAQ never describes
  /// a feature the user cannot see.
  final bool showCustomTypesFaq;

  /// Whether to explain Income Guardian (A105). Callers pass
  /// isIncomeGuardianEnabledProvider, so the FAQ never describes a feature
  /// the user cannot see.
  final bool showIncomeGuardianFaq;

  /// Whether to say where the Portfolio Health Score is (#903). Callers pass
  /// isPortfolioHealthEnabledProvider, so the FAQ never points at a card the
  /// user cannot see.
  final bool showPortfolioHealthFaq;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpFaqTitle, style: AppTypography.h3)),
      body: ListView(
        padding: EdgeInsets.all(AppSpacing.md),
        children: [
          _buildSection(l10n.guestModeSection, [
            _buildFaqItem(
              l10n.whatIsGuestMode,
              l10n.whatIsGuestModeAnswer,
              isDark,
            ),
            _buildFaqItem(
              l10n.howToLinkGuestAccount,
              l10n.howToLinkGuestAccountAnswer,
              isDark,
            ),
            _buildFaqItem(
              l10n.whatHappensToGuestData,
              l10n.whatHappensToGuestDataAnswer,
              isDark,
            ),
          ]),
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
            if (showCustomTypesFaq)
              _buildFaqItem(
                l10n.whatAreCustomTypes,
                l10n.whatAreCustomTypesAnswer,
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
          _buildSection(l10n.portfolioHealthSection, [
            _buildFaqItem(
              l10n.whatIsPortfolioHealthScore,
              l10n.whatIsPortfolioHealthScoreAnswer,
              isDark,
            ),
            if (showPortfolioHealthFaq)
              _buildFaqItem(
                l10n.whereToFindPortfolioHealth,
                l10n.whereToFindPortfolioHealthAnswer,
                isDark,
              ),
            _buildFaqItem(
              l10n.whatDoScoreTiersMean,
              l10n.whatDoScoreTiersMeanAnswer,
              isDark,
            ),
            _buildFaqItem(
              l10n.howToImproveMyScore,
              l10n.howToImproveMyScoreAnswer,
              isDark,
            ),
            _buildFaqItem(
              l10n.isHealthScoreDataSaved,
              l10n.isHealthScoreDataSavedAnswer,
              isDark,
            ),
          ]),
          if (showIncomeGuardianFaq)
            _buildSection(l10n.incomeGuardianSection, [
              _buildFaqItem(
                l10n.whatIsIncomeGuardian,
                l10n.whatIsIncomeGuardianAnswer,
                isDark,
              ),
              _buildFaqItem(
                l10n.howDoesIncomeProjectionWork,
                l10n.howDoesIncomeProjectionWorkAnswer,
                isDark,
              ),
              _buildFaqItem(
                l10n.whatIsIncomeTrendAnalysis,
                l10n.whatIsIncomeTrendAnalysisAnswer,
                isDark,
              ),
              _buildFaqItem(
                l10n.whatIsHHIScore,
                l10n.whatIsHHIScoreAnswer,
                isDark,
              ),
              _buildFaqItem(
                l10n.whatIsPlatformReliability,
                l10n.whatIsPlatformReliabilityAnswer,
                isDark,
              ),
              _buildFaqItem(
                l10n.howToAccessIncomeReports,
                l10n.howToAccessIncomeReportsAnswer,
                isDark,
              ),
            ]),
          if (showDeveloperFaq)
            _buildSection(l10n.advancedFeatures, [
              _buildFaqItem(
                l10n.howToEnableDebugMode,
                l10n.howToEnableDebugModeAnswer,
                isDark,
              ),
              _buildFaqItem(
                l10n.whatIsDebugModeFor,
                l10n.whatIsDebugModeForAnswer,
                isDark,
              ),
              _buildFaqItem(
                l10n.howToDisableDebugMode,
                l10n.howToDisableDebugModeAnswer,
                isDark,
              ),
            ]),
          SizedBox(height: AppSpacing.md),
          DeleteAccountWebLink(
            onPressed: () => openAccountDeletionPageOrCopyLink(context),
          ),
          SizedBox(height: AppSpacing.md),
          Center(
            child: Text(
              l10n.needMoreHelpContact(supportEmailAddress),
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
