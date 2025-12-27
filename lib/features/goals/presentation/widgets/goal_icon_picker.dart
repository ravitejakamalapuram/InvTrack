import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';

/// Bottom sheet for selecting goal icon and color
class GoalIconPicker extends StatefulWidget {
  final String selectedIcon;
  final Color selectedColor;
  final ValueChanged<String> onIconSelected;
  final ValueChanged<Color> onColorSelected;

  const GoalIconPicker({
    super.key,
    required this.selectedIcon,
    required this.selectedColor,
    required this.onIconSelected,
    required this.onColorSelected,
  });

  @override
  State<GoalIconPicker> createState() => _GoalIconPickerState();
}

class _GoalIconPickerState extends State<GoalIconPicker> {
  late String _currentIcon;
  late Color _currentColor;

  @override
  void initState() {
    super.initState();
    _currentIcon = widget.selectedIcon;
    _currentColor = widget.selectedColor;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.neutral600Dark : AppColors.neutral300Light,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.lg),

                // Preview
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_currentColor, _currentColor.withValues(alpha: 0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _currentColor.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(_currentIcon, style: const TextStyle(fontSize: 40)),
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.xl),

                // Colors
                Text(
                  'Colors',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.neutral900Light,
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: GoalColors.available.map((color) {
                    final isSelected = color.toARGB32() == _currentColor.toARGB32();
                    return GestureDetector(
                      onTap: () {
                        setState(() => _currentColor = color);
                        widget.onColorSelected(color);
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: AppSpacing.xl),

                // Icons
                Text(
                  'Icons',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.neutral900Light,
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: GoalIcons.available.length,
                  itemBuilder: (context, index) {
                    final icon = GoalIcons.available[index];
                    final isSelected = icon == _currentIcon;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _currentIcon = icon);
                        widget.onIconSelected(icon);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _currentColor.withValues(alpha: 0.2)
                              : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(color: _currentColor, width: 2)
                              : null,
                        ),
                        child: Center(
                          child: Text(icon, style: const TextStyle(fontSize: 24)),
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: AppSpacing.xl),
              ],
            ),
          );
        },
      ),
    );
  }
}

