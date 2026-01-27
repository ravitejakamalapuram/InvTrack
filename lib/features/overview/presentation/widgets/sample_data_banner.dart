/// Banner widget shown when sample data mode is active.
/// Provides options to keep or clear the sample data.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/settings/presentation/providers/sample_data_provider.dart';

/// A banner that appears when sample data mode is active.
/// Shows sample data indicator with options to keep or clear.
class SampleDataBanner extends ConsumerWidget {
  const SampleDataBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sampleState = ref.watch(sampleDataModeProvider);

    if (!sampleState.isActive) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bannerColor = isDark
        ? AppColors.accentLight.withValues(alpha: 0.15)
        : AppColors.accentLight.withValues(alpha: 0.1);
    final borderColor = AppColors.accentLight.withValues(alpha: 0.4);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.accentLight.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.science_rounded,
                  color: AppColors.accentLight,
                  size: 18,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sample Data Mode',
                      style: AppTypography.label.copyWith(
                        color: AppColors.accentLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Exploring with sample investments',
                      style: AppTypography.small.copyWith(
                        color: isDark
                            ? AppColors.neutral400Dark
                            : AppColors.neutral500Light,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Clear Sample Data',
                  icon: Icons.delete_outline_rounded,
                  isDestructive: true,
                  isLoading: sampleState.isLoading,
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    final confirmed = await _showClearConfirmation(context);
                    if (confirmed == true) {
                      ref.read(sampleDataModeProvider.notifier).clearSampleData();
                    }
                  },
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _ActionButton(
                  label: 'Keep as My Data',
                  icon: Icons.check_circle_outline_rounded,
                  isDestructive: false,
                  isLoading: sampleState.isLoading,
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    final confirmed = await _showKeepConfirmation(context);
                    if (confirmed == true) {
                      ref.read(sampleDataModeProvider.notifier).keepSampleData();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<bool?> _showClearConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Sample Data?'),
        content: const Text(
          'This will remove all sample investments and goals. '
          'You can always try sample data again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showKeepConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keep Sample Data?'),
        content: const Text(
          'Sample investments will become your real data. '
          'You can edit or delete them anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keep'),
          ),
        ],
      ),
    );
  }
}

/// Action button for the sample data banner
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isDestructive;
  final bool isLoading;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.isDestructive,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDestructive
        ? Colors.red
        : (isDark ? AppColors.successDark : AppColors.successLight);

    return OutlinedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            )
          : Icon(icon, size: 18),
      label: Text(
        label,
        style: AppTypography.small.copyWith(fontWeight: FontWeight.w500),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

