import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';

/// Segmented control for switching between Transactions and Documents tabs.
class InvestmentDetailSegmentControl extends StatelessWidget {
  final bool isDark;
  final int selectedSegment;
  final int transactionCount;
  final int documentCount;
  final ValueChanged<int> onSegmentChanged;

  const InvestmentDetailSegmentControl({
    super.key,
    required this.isDark,
    required this.selectedSegment,
    required this.transactionCount,
    required this.documentCount,
    required this.onSegmentChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.neutral800Dark : AppColors.neutral100Light,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          // Transactions Tab
          Expanded(
            child: _SegmentTab(
              isDark: isDark,
              isSelected: selectedSegment == 0,
              icon: Icons.swap_vert_rounded,
              label: 'Transactions',
              count: transactionCount,
              onTap: () => onSegmentChanged(0),
            ),
          ),
          // Documents Tab
          Expanded(
            child: _SegmentTab(
              isDark: isDark,
              isSelected: selectedSegment == 1,
              icon: Icons.folder_outlined,
              label: 'Documents',
              count: documentCount,
              onTap: () => onSegmentChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual segment tab with animated selection state.
class _SegmentTab extends StatelessWidget {
  final bool isDark;
  final bool isSelected;
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  const _SegmentTab({
    required this.isDark,
    required this.isSelected,
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: isSelected ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          final bgColor = Color.lerp(
            Colors.transparent,
            isDark ? AppColors.neutral700Dark : Colors.white,
            value,
          )!;
          final iconTextColor = Color.lerp(
            isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
            isDark ? Colors.white : AppColors.neutral900Light,
            value,
          )!;
          final badgeBgColor = Color.lerp(
            isDark ? AppColors.neutral600Dark : AppColors.neutral200Light,
            AppColors.primaryLight.withValues(alpha: 0.15),
            value,
          )!;
          final badgeTextColor = Color.lerp(
            isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
            AppColors.primaryLight,
            value,
          )!;
          final shadowOpacity = 0.08 * value;

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              boxShadow: value > 0.01
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: shadowOpacity),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: iconTextColor),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTypography.bodyMedium.copyWith(
                    color: iconTextColor,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: AppTypography.small.copyWith(
                        color: badgeTextColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

