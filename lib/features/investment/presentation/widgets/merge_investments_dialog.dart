import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

/// Result returned from the merge investments dialog
typedef MergeDialogResult = ({String name, InvestmentType type});

/// Dialog for merging investments with name and type selection
class MergeInvestmentsDialog extends StatefulWidget {
  final int selectedCount;
  final InvestmentType defaultType;
  final List<InvestmentType> investmentTypes;

  const MergeInvestmentsDialog({
    super.key,
    required this.selectedCount,
    required this.defaultType,
    required this.investmentTypes,
  });

  /// Shows the merge investments dialog and returns the result
  static Future<MergeDialogResult?> show({
    required BuildContext context,
    required int selectedCount,
    required InvestmentType defaultType,
    required List<InvestmentType> investmentTypes,
  }) {
    return showDialog<MergeDialogResult>(
      context: context,
      builder: (context) => MergeInvestmentsDialog(
        selectedCount: selectedCount,
        defaultType: defaultType,
        investmentTypes: investmentTypes,
      ),
    );
  }

  @override
  State<MergeInvestmentsDialog> createState() => _MergeInvestmentsDialogState();
}

class _MergeInvestmentsDialogState extends State<MergeInvestmentsDialog> {
  final _nameController = TextEditingController();
  late InvestmentType _selectedType;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.defaultType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasMultipleTypes = widget.investmentTypes.length > 1;

    return AlertDialog(
      title: const Text('Merge Investments'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Merge ${widget.selectedCount} investments into one.'),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'New Investment Name',
                hintText: 'Enter name for merged investment',
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            Text(
              'Investment Type',
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (hasMultipleTypes) ...[
              const SizedBox(height: 4),
              Text(
                'Selected investments have different types',
                style: AppTypography.caption.copyWith(
                  color: isDark
                      ? AppColors.neutral400Dark
                      : AppColors.neutral500Light,
                ),
              ),
            ],
            const SizedBox(height: 8),
            _buildTypeSelector(isDark),
            const SizedBox(height: 12),
            Text(
              'All cash flows will be combined.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _onMergePressed, child: const Text('Merge')),
      ],
    );
  }

  Widget _buildTypeSelector(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: InvestmentType.values.map((type) {
        final isSelected = type == _selectedType;
        final isFromSelection = widget.investmentTypes.contains(type);

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedType = type);
          },
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: isSelected ? 1.0 : 0.0),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              final bgColor = Color.lerp(
                isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                type.color.withValues(alpha: 0.2),
                value,
              )!;
              final borderColor = Color.lerp(
                Colors.transparent,
                type.color,
                value,
              )!;
              final iconColor = Color.lerp(
                isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                type.color,
                value,
              )!;
              final textColor = Color.lerp(
                isDark ? AppColors.neutral300Dark : AppColors.neutral600Light,
                type.color,
                value,
              )!;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(type.icon, size: 16, color: iconColor),
                    const SizedBox(width: 6),
                    Text(
                      type.displayName,
                      style: AppTypography.caption.copyWith(
                        color: textColor,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    if (isFromSelection) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.check_circle,
                        size: 12,
                        color: type.color.withValues(alpha: 0.7),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      }).toList(),
    );
  }

  void _onMergePressed() {
    if (_nameController.text.trim().isNotEmpty) {
      Navigator.of(
        context,
      ).pop((name: _nameController.text.trim(), type: _selectedType));
    }
  }
}
