/// Empty, error, and no-results state widgets for investment list.
library;

import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_sizes.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Displayed when no investments exist.
class InvestmentEmptyState extends StatelessWidget {
  final bool isDark;
  final VoidCallback onAddInvestment;

  const InvestmentEmptyState({
    super.key,
    required this.isDark,
    required this.onAddInvestment,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryLight.withValues(alpha: 0.1),
                    AppColors.accentLight.withValues(alpha: 0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.show_chart_rounded,
                size: AppSizes.iconDisplay,
                color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
              ),
            ),
            SizedBox(height: AppSpacing.xl),
            Text(
              'No Investments Yet',
              style: AppTypography.h3.copyWith(
                color: isDark ? Colors.white : AppColors.neutral900Light,
              ),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              'Add your first investment to start tracking',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: isDark
                    ? AppColors.neutral400Dark
                    : AppColors.neutral500Light,
              ),
            ),
            SizedBox(height: AppSpacing.xxl),
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: AppSizes.borderRadiusLg,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryLight.withValues(alpha: 0.3),
                    blurRadius: AppSpacing.md,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: onAddInvestment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxl,
                    vertical: AppSpacing.md,
                  ),
                ),
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: Text(
                  'Add First Investment',
                  style: AppTypography.button.copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Displayed when search/filter returns no results.
class InvestmentNoResultsState extends StatelessWidget {
  final bool isDark;
  final bool isSearching;
  final bool isArchivedFilter;

  const InvestmentNoResultsState({
    super.key,
    required this.isDark,
    this.isSearching = false,
    this.isArchivedFilter = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Determine appropriate icon, title, and message based on context
    final IconData icon;
    final String title;
    final String message;

    if (isSearching) {
      icon = Icons.search_off_rounded;
      title = l10n.noResultsFound;
      message = l10n.tryDifferentSearchTerm;
    } else if (isArchivedFilter) {
      icon = Icons.archive_outlined;
      title = l10n.noArchivedInvestments;
      message = l10n.archivedInvestmentsAppearHere;
    } else {
      icon = Icons.filter_list_off_rounded;
      title = l10n.noMatchingInvestments;
      message = l10n.tryDifferentFilter;
    }

    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : AppColors.primaryLight)
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: AppSizes.iconDisplay,
                color: isDark
                    ? AppColors.neutral400Dark
                    : AppColors.neutral500Light,
              ),
            ),
            SizedBox(height: AppSpacing.xl),
            Text(
              title,
              style: AppTypography.h3.copyWith(
                color: isDark ? Colors.white : AppColors.neutral900Light,
              ),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: isDark
                    ? AppColors.neutral400Dark
                    : AppColors.neutral500Light,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Displayed when there's an error loading investments.
class InvestmentErrorState extends StatelessWidget {
  final bool isDark;
  final VoidCallback onRetry;

  const InvestmentErrorState({
    super.key,
    required this.isDark,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
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
            SizedBox(height: AppSpacing.xs),
            Text(
              'Unable to load investments.\nPlease check your connection and try again.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: isDark
                    ? AppColors.neutral400Dark
                    : AppColors.neutral500Light,
              ),
            ),
            SizedBox(height: AppSpacing.xl),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
