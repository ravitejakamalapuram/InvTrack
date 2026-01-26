import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/utils/date_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

/// A card widget displaying a single cash flow transaction.
/// Supports swipe-to-edit (right) and swipe-to-delete (left) gestures.
class CashFlowCardWidget extends StatelessWidget {
  final CashFlowEntity cashFlow;
  final bool isDark;
  final NumberFormat currencyFormat;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final Future<bool?> Function() onConfirmDelete;
  final VoidCallback onDeleted;

  const CashFlowCardWidget({
    super.key,
    required this.cashFlow,
    required this.isDark,
    required this.currencyFormat,
    required this.onTap,
    required this.onEdit,
    required this.onConfirmDelete,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final isOutflow = cashFlow.type.isOutflow;
    final color = isOutflow ? AppColors.errorLight : AppColors.successLight;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Dismissible(
          key: Key(cashFlow.id),
          direction: DismissDirection.horizontal,
          // Swipe right (startToEnd) - Edit action
          background: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 24),
            child: const Icon(Icons.edit_rounded, color: Colors.white),
          ),
          // Swipe left (endToStart) - Delete action
          secondaryBackground: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              gradient: AppColors.dangerGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: const Icon(Icons.delete_rounded, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              // Swipe right - Navigate to edit screen
              onEdit();
              return false; // Don't dismiss, just navigate
            } else {
              // Swipe left - Confirm delete
              return onConfirmDelete();
            }
          },
          onDismissed: (direction) {
            // Only called for delete action
            onDeleted();
          },
          child: _buildCardContent(color, isOutflow),
        ),
      ),
    );
  }

  Widget _buildCardContent(Color color, bool isOutflow) {
    return Material(
      color: isDark ? AppColors.cardDark : AppColors.cardLight,
      borderRadius: BorderRadius.circular(16),
      elevation: isDark ? 0 : 1,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              // Icon
              _buildIcon(color, isOutflow),
              const SizedBox(width: 14),
              // Details
              Expanded(child: _buildDetails(color)),
              // Amount
              _buildAmount(color, isOutflow),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(Color color, bool isOutflow) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        isOutflow ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
        color: color,
      ),
    );
  }

  Widget _buildDetails(Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            cashFlow.type.displayName,
            style: AppTypography.small.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          AppDateUtils.formatShort(cashFlow.date),
          style: AppTypography.small.copyWith(
            color: isDark
                ? AppColors.neutral400Dark
                : AppColors.neutral500Light,
          ),
        ),
        if (cashFlow.notes != null && cashFlow.notes!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            cashFlow.notes!,
            style: AppTypography.small.copyWith(
              color: isDark
                  ? AppColors.neutral400Dark
                  : AppColors.neutral500Light,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildAmount(Color color, bool isOutflow) {
    return Text(
      '${isOutflow ? '-' : '+'}${currencyFormat.formatSmart(cashFlow.amount)}',
      style: AppTypography.bodyLarge.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
