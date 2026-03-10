import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Transaction FAB for adding new transactions.
class TransactionFab extends StatelessWidget {
  final bool hasTransactions;
  final VoidCallback onTap;

  const TransactionFab({
    super.key,
    required this.hasTransactions,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    void handleTap() {
      HapticFeedback.selectionClick();
      onTap();
    }

    return Semantics(
      button: true,
      label: 'Add Transaction',
      excludeSemantics: true,
      onTap: handleTap,
      child: GestureDetector(
        onTap: handleTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryLight.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Add Transaction',
                style: AppTypography.button.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Gets the smart default transaction type.
  /// First transaction should be 'invest', subsequent ones should be 'income'.
  static CashFlowType getSmartDefaultType(bool hasTransactions) {
    return hasTransactions ? CashFlowType.income : CashFlowType.invest;
  }
}

/// Document FAB for adding new documents.
class DocumentFab extends StatelessWidget {
  final VoidCallback onTap;

  const DocumentFab({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryLight.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        heroTag: 'investment_detail_fab',
        onPressed: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
        label: Text(
          l10n.addDocument,
          style: AppTypography.button.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}
