import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/presentation/ui_extensions/investment_ui.dart';

/// Bottom sheet for selecting investment type filter
class TypeFilterSheet extends StatelessWidget {
  final bool isDark;
  final InvestmentType? currentType;
  final ValueChanged<InvestmentType?> onTypeSelected;

  const TypeFilterSheet({
    super.key,
    required this.isDark,
    required this.currentType,
    required this.onTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.neutral600Dark
                    : AppColors.neutral300Light,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Text(
                    'Filter by Type',
                    style: AppTypography.h3.copyWith(
                      color: isDark ? Colors.white : AppColors.neutral900Light,
                    ),
                  ),
                  const Spacer(),
                  if (currentType != null)
                    TextButton(
                      onPressed: () => onTypeSelected(null),
                      child: Text(
                        'Clear',
                        style: AppTypography.body.copyWith(
                          color: AppColors.primaryLight,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Type options
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: InvestmentType.values.map((type) {
                    final isSelected = currentType == type;
                    return ListTile(
                      selected: isSelected,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: type.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(type.icon, color: type.color, size: 20),
                      ),
                      title: Text(
                        type.displayName,
                        style: AppTypography.body.copyWith(
                          color: isDark
                              ? Colors.white
                              : AppColors.neutral900Light,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_rounded,
                              color: AppColors.primaryLight,
                            )
                          : null,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onTypeSelected(type);
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
            SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
