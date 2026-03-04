/// Filter tabs widget for the investment list screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_sizes.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_list_enums.dart';

/// Filter tabs for All, Open, Closed, and Archived investments
class InvestmentListFilterTabs extends ConsumerWidget {
  const InvestmentListFilterTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final listState = ref.watch(investmentListStateProvider);
    final counts = ref.watch(investmentCountsProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            count: counts.all,
            filter: InvestmentFilter.all,
            isSelected: listState.filter == InvestmentFilter.all,
            isDark: isDark,
          ),
          SizedBox(width: AppSpacing.xs),
          _FilterChip(
            label: 'Open',
            count: counts.open,
            filter: InvestmentFilter.open,
            isSelected: listState.filter == InvestmentFilter.open,
            isDark: isDark,
          ),
          SizedBox(width: AppSpacing.xs),
          _FilterChip(
            label: 'Closed',
            count: counts.closed,
            filter: InvestmentFilter.closed,
            isSelected: listState.filter == InvestmentFilter.closed,
            isDark: isDark,
          ),
          SizedBox(width: AppSpacing.xs),
          _FilterChip(
            label: 'Archived',
            count: counts.archived,
            filter: InvestmentFilter.archived,
            isSelected: listState.filter == InvestmentFilter.archived,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends ConsumerStatefulWidget {
  final String label;
  final int count;
  final InvestmentFilter filter;
  final bool isSelected;
  final bool isDark;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.filter,
    required this.isSelected,
    required this.isDark,
  });

  @override
  ConsumerState<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends ConsumerState<_FilterChip> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    void onTap() {
      HapticFeedback.selectionClick();
      ref.read(investmentListStateProvider.notifier).setFilter(widget.filter);
    }

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: '${widget.label}, ${widget.count} items',
      excludeSemantics: true,
      onTap: onTap,
      child: Focus(
        onFocusChange: (hasFocus) {
          setState(() {
            _isFocused = hasFocus;
          });
        },
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space)) {
            onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: onTap,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: widget.isSelected ? 1.0 : 0.0),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              final bgColor = Color.lerp(
                (widget.isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.05),
                AppColors.primaryLight,
                value,
              )!;
              final textColor = Color.lerp(
                widget.isDark ? Colors.white70 : AppColors.neutral700Light,
                Colors.white,
                value,
              )!;
              final badgeBgColor = Color.lerp(
                (widget.isDark ? Colors.white : AppColors.primaryLight)
                    .withValues(alpha: 0.15),
                Colors.white.withValues(alpha: 0.2),
                value,
              )!;
              final badgeTextColor = Color.lerp(
                widget.isDark ? Colors.white70 : AppColors.primaryLight,
                Colors.white,
                value,
              )!;

              // Visual focus indicator
              final borderColor = _isFocused
                  ? (widget.isDark ? Colors.white : AppColors.neutral900Light)
                  : Colors.transparent;

              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(AppSizes.radiusXl),
                  border: Border.all(color: borderColor, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: AppTypography.small.copyWith(
                        color: textColor,
                        fontWeight:
                            widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    if (widget.count > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: badgeBgColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${widget.count}',
                          style: AppTypography.small.copyWith(
                            fontSize: 10,
                            color: badgeTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
