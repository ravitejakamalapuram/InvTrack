import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inv_tracker/core/theme/app_sizes.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/presentation/ui_extensions/investment_ui.dart';

/// Chip showing the active type filter with clear button
class ActiveTypeFilterChip extends StatelessWidget {
  final InvestmentType type;
  final bool isDark;
  final VoidCallback onClear;

  const ActiveTypeFilterChip({
    super.key,
    required this.type,
    required this.isDark,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: type.color.withValues(alpha: 0.15),
            borderRadius: AppSizes.borderRadiusMd,
            border: Border.all(color: type.color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(type.icon, color: type.color, size: 16),
              SizedBox(width: AppSpacing.xs),
              Text(
                type.displayName,
                style: AppTypography.caption.copyWith(
                  color: type.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: AppSpacing.xs),
              Semantics(
                button: true,
                label: 'Clear ${type.displayName} filter',
                onTap: onClear,
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onClear();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: EdgeInsets.all(AppSpacing.xs),
                    child: Icon(
                      Icons.close_rounded,
                      color: type.color,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
