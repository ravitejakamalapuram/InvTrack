/// Empty state widget for the overview screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/features/investment/domain/models/investment_template.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Enhanced empty state shown when there are no investments.
/// Designed to drive user activation with:
/// - XIRR demo showing the "Aha moment"
/// - Quick-start action buttons
/// - Template chips for quick access
/// - Sample data mode option
class OverviewEmptyState extends StatefulWidget {
  /// Callback when user taps "Add Investment" manually
  final VoidCallback? onAddManual;

  /// Callback when user taps "Import CSV"
  final VoidCallback? onImportCsv;

  /// Callback when user selects a template for quick-add
  final void Function(InvestmentTemplate)? onTemplateSelected;

  /// Callback when user taps "Try Sample Data"
  final VoidCallback? onTrySampleData;

  const OverviewEmptyState({
    super.key,
    this.onAddManual,
    this.onImportCsv,
    this.onTemplateSelected,
    this.onTrySampleData,
  });

  @override
  State<OverviewEmptyState> createState() => _OverviewEmptyStateState();
}

class _OverviewEmptyStateState extends State<OverviewEmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _xirrAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    // XIRR animates from advertised rate (7%) to real rate (6.2%)
    _xirrAnimation = Tween<double>(begin: 7.0, end: 6.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.8, curve: Curves.easeInOut),
      ),
    );

    // Start animation after widget builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value.clamp(0.0, 1.0),
          child: child,
        );
      },
      child: Column(
        children: [
          // XIRR Demo Section - The "Aha Moment"
          _XIRRDemoCard(
            controller: _controller,
            xirrAnimation: _xirrAnimation,
            isDark: isDark,
            primaryColor: primaryColor,
          ),

          SizedBox(height: AppSpacing.md),

          // Quick Start Actions
          _QuickStartSection(
            isDark: isDark,
            primaryColor: primaryColor,
            onAddManual: widget.onAddManual,
            onImportCsv: widget.onImportCsv,
          ),

          SizedBox(height: AppSpacing.md),

          // Template Chips for Quick Access
          _TemplateChipsSection(
            isDark: isDark,
            onTemplateSelected: widget.onTemplateSelected,
          ),

          SizedBox(height: AppSpacing.md),

          // Sample Data Mode
          if (widget.onTrySampleData != null)
            _SampleDataSection(
              isDark: isDark,
              onTrySampleData: widget.onTrySampleData!,
            ),
        ],
      ),
    );
  }
}

/// XIRR Demo Card - Shows the "Aha Moment"
/// Animates from advertised rate to real XIRR rate
class _XIRRDemoCard extends StatelessWidget {
  final AnimationController controller;
  final Animation<double> xirrAnimation;
  final bool isDark;
  final Color primaryColor;

  const _XIRRDemoCard({
    required this.controller,
    required this.xirrAnimation,
    required this.isDark,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          // Header with icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor.withValues(alpha: 0.2),
                  primaryColor.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.insights_rounded,
              size: 40,
              color: primaryColor,
            ),
          ),
          SizedBox(height: AppSpacing.md),

          // Title
          Text(
            'See Your Real Returns',
            style: AppTypography.h2.copyWith(
              color: isDark ? Colors.white : AppColors.neutral900Light,
            ),
          ),
          SizedBox(height: AppSpacing.xs),

          // Subtitle
          Text(
            'Banks say 7%. What did you really earn?',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(
              color: isDark
                  ? AppColors.neutral400Dark
                  : AppColors.neutral500Light,
            ),
          ),
          SizedBox(height: AppSpacing.lg),

          // Animated XIRR comparison
          AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final animatedXirr = xirrAnimation.value;
              final isComplete = controller.value > 0.8;

              return Container(
                padding: EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Advertised Rate
                    _RateColumn(
                      label: 'Advertised',
                      rate: '7.0%',
                      icon: Icons.campaign_rounded,
                      color: isDark
                          ? AppColors.neutral400Dark
                          : AppColors.neutral500Light,
                      isDark: isDark,
                    ),

                    // Arrow
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: isDark
                          ? AppColors.neutral500Dark
                          : AppColors.neutral400Light,
                    ),

                    // Real XIRR Rate (animated)
                    _RateColumn(
                      label: 'Your XIRR',
                      rate: '${animatedXirr.toStringAsFixed(1)}%',
                      icon: Icons.trending_down_rounded,
                      color:
                          isComplete ? AppColors.warningLight : primaryColor,
                      isDark: isDark,
                      highlight: isComplete,
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: AppSpacing.sm),

          // Explanation
          Text(
            'Lock-ins and compounding affect your true return.',
            textAlign: TextAlign.center,
            style: AppTypography.small.copyWith(
              color: isDark
                  ? AppColors.neutral400Dark
                  : AppColors.neutral500Light,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rate column for XIRR demo
class _RateColumn extends StatelessWidget {
  final String label;
  final String rate;
  final IconData icon;
  final Color color;
  final bool isDark;
  final bool highlight;

  const _RateColumn({
    required this.label,
    required this.rate,
    required this.icon,
    required this.color,
    required this.isDark,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        SizedBox(height: AppSpacing.xs),
        Text(
          rate,
          style: AppTypography.numberSmall.copyWith(
            color: highlight
                ? color
                : (isDark ? Colors.white : AppColors.neutral900Light),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.small.copyWith(
            color:
                isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
          ),
        ),
      ],
    );
  }
}

/// Quick Start Section with action buttons
class _QuickStartSection extends StatelessWidget {
  final bool isDark;
  final Color primaryColor;
  final VoidCallback? onAddManual;
  final VoidCallback? onImportCsv;

  const _QuickStartSection({
    required this.isDark,
    required this.primaryColor,
    this.onAddManual,
    this.onImportCsv,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Get Started',
            style: AppTypography.h4.copyWith(
              color: isDark ? Colors.white : AppColors.neutral900Light,
            ),
          ),
          SizedBox(height: AppSpacing.md),

          // Action buttons row
          Row(
            children: [
              // Add Manually
              Expanded(
                child: _QuickStartButton(
                  icon: Icons.add_rounded,
                  label: 'Add Manually',
                  sublabel: 'Step by step',
                  color: primaryColor,
                  isDark: isDark,
                  onTap: onAddManual,
                ),
              ),
              SizedBox(width: AppSpacing.sm),

              // Import CSV
              Expanded(
                child: _QuickStartButton(
                  icon: Icons.upload_file_rounded,
                  label: 'Import CSV',
                  sublabel: 'Bulk upload',
                  color: AppColors.accentLight,
                  isDark: isDark,
                  onTap: onImportCsv,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Quick start action button
class _QuickStartButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final bool isDark;
  final VoidCallback? onTap;

  const _QuickStartButton({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (onTap != null) {
            HapticFeedback.lightImpact();
            onTap!();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                label,
                style: AppTypography.label.copyWith(
                  color: isDark ? Colors.white : AppColors.neutral900Light,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 2),
              Text(
                sublabel,
                style: AppTypography.small.copyWith(
                  color: isDark
                      ? AppColors.neutral400Dark
                      : AppColors.neutral500Light,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// Template Chips Section for quick template access
class _TemplateChipsSection extends StatelessWidget {
  final bool isDark;
  final void Function(InvestmentTemplate)? onTemplateSelected;

  const _TemplateChipsSection({
    required this.isDark,
    this.onTemplateSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Templates',
            style: AppTypography.h4.copyWith(
              color: isDark ? Colors.white : AppColors.neutral900Light,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            'Tap to start with pre-filled defaults',
            style: AppTypography.small.copyWith(
              color: isDark
                  ? AppColors.neutral400Dark
                  : AppColors.neutral500Light,
            ),
          ),
          SizedBox(height: AppSpacing.md),

          // Template chips in a wrap
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: InvestmentTemplates.all.map((template) {
              return _TemplateChip(
                template: template,
                isDark: isDark,
                onTap: onTemplateSelected != null
                    ? () {
                        HapticFeedback.selectionClick();
                        onTemplateSelected!(template);
                      }
                    : null,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Individual template chip
class _TemplateChip extends StatelessWidget {
  final InvestmentTemplate template;
  final bool isDark;
  final VoidCallback? onTap;

  const _TemplateChip({
    required this.template,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: template.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: template.color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(template.emoji, style: const TextStyle(fontSize: 16)),
              SizedBox(width: AppSpacing.xs),
              Text(
                template.name,
                style: AppTypography.label.copyWith(
                  color: isDark ? Colors.white : AppColors.neutral800Light,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sample Data Section for exploring the app
class _SampleDataSection extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTrySampleData;

  const _SampleDataSection({
    required this.isDark,
    required this.onTrySampleData,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accentLight.withValues(alpha: 0.1),
            AppColors.primaryLight.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accentLight.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.accentLight.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.science_rounded,
              color: AppColors.accentLight,
              size: 24,
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.trySampleData,
                  style: AppTypography.label.copyWith(
                    color: isDark ? Colors.white : AppColors.neutral900Light,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  l10n.exploreWithRealisticInvestments,
                  style: AppTypography.small.copyWith(
                    color: isDark
                        ? AppColors.neutral400Dark
                        : AppColors.neutral500Light,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              onTrySampleData();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentLight,
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
            ),
            child: Text(l10n.tryIt),
          ),
        ],
      ),
    );
  }
}

/// Error card for the overview screen.
class OverviewErrorCard extends StatelessWidget {
  final String error;

  const OverviewErrorCard({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GlassCard(
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 8),
          Text(l10n.failedToLoadData),
          const SizedBox(height: 4),
          Text(
            l10n.pleaseTryAgainLater,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
