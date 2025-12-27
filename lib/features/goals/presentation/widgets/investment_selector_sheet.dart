import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';

/// Bottom sheet for selecting investments or investment types to link to a goal
class InvestmentSelectorSheet extends ConsumerStatefulWidget {
  final GoalTrackingMode trackingMode;
  final List<String> selectedInvestmentIds;
  final List<InvestmentType> selectedTypes;
  final ValueChanged<List<String>> onInvestmentsSelected;
  final ValueChanged<List<InvestmentType>> onTypesSelected;

  const InvestmentSelectorSheet({
    super.key,
    required this.trackingMode,
    required this.selectedInvestmentIds,
    required this.selectedTypes,
    required this.onInvestmentsSelected,
    required this.onTypesSelected,
  });

  @override
  ConsumerState<InvestmentSelectorSheet> createState() => _InvestmentSelectorSheetState();
}

class _InvestmentSelectorSheetState extends ConsumerState<InvestmentSelectorSheet> {
  late List<String> _selectedIds;
  late List<InvestmentType> _selectedTypes;

  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.selectedInvestmentIds);
    _selectedTypes = List.from(widget.selectedTypes);
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
          return Column(
            children: [
              // Header
              Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.neutral600Dark : AppColors.neutral300Light,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(height: AppSpacing.md),
                    Text(
                      widget.trackingMode == GoalTrackingMode.selected
                          ? 'Select Investments'
                          : 'Select Investment Types',
                      style: AppTypography.h3.copyWith(
                        color: isDark ? Colors.white : AppColors.neutral900Light,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: widget.trackingMode == GoalTrackingMode.selected
                    ? _buildInvestmentList(context, scrollController, isDark)
                    : _buildTypeList(scrollController, isDark),
              ),

              // Done button
              Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      widget.onInvestmentsSelected(_selectedIds);
                      widget.onTypesSelected(_selectedTypes);
                      Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    ),
                    child: const Text('Done'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInvestmentList(BuildContext context, ScrollController controller, bool isDark) {
    final investmentsAsync = ref.watch(allInvestmentsProvider);

    return investmentsAsync.when(
      data: (investments) {
        if (investments.isEmpty) {
          return Center(
            child: Text(
              'No investments found',
              style: AppTypography.bodyMedium.copyWith(
                color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
              ),
            ),
          );
        }

        return ListView.builder(
          controller: controller,
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          itemCount: investments.length,
          itemBuilder: (context, index) {
            final investment = investments[index];
            final isSelected = _selectedIds.contains(investment.id);

            return CheckboxListTile(
              value: isSelected,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selectedIds.add(investment.id);
                  } else {
                    _selectedIds.remove(investment.id);
                  }
                });
              },
              title: Text(investment.name),
              subtitle: Text(investment.type.displayName),
              secondary: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: investment.type.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(investment.type.icon, color: investment.type.color, size: 20),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildTypeList(ScrollController controller, bool isDark) {
    return ListView.builder(
      controller: controller,
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      itemCount: InvestmentType.values.length,
      itemBuilder: (context, index) {
        final type = InvestmentType.values[index];
        final isSelected = _selectedTypes.contains(type);

        return CheckboxListTile(
          value: isSelected,
          onChanged: (v) {
            setState(() {
              if (v == true) {
                _selectedTypes.add(type);
              } else {
                _selectedTypes.remove(type);
              }
            });
          },
          title: Text(type.displayName),
          secondary: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: type.color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(type.icon, color: type.color, size: 20),
          ),
        );
      },
    );
  }
}

