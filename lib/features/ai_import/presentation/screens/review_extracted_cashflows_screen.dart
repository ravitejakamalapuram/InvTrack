import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/gradient_button.dart';
import 'package:inv_tracker/features/ai_import/domain/entities/extracted_cash_flow.dart';
import 'package:inv_tracker/features/ai_import/presentation/providers/ai_import_provider.dart';

class ReviewExtractedCashflowsScreen extends ConsumerStatefulWidget {
  const ReviewExtractedCashflowsScreen({super.key});

  @override
  ConsumerState<ReviewExtractedCashflowsScreen> createState() =>
      _ReviewExtractedCashflowsScreenState();
}

class _ReviewExtractedCashflowsScreenState
    extends ConsumerState<ReviewExtractedCashflowsScreen> {
  final TextEditingController _investmentNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(aiImportProvider);
      if (state.newInvestmentName != null) {
        _investmentNameController.text = state.newInvestmentName!;
      }
    });
  }

  @override
  void dispose() {
    _investmentNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencySymbol = ref.watch(currencySymbolProvider);
    final importState = ref.watch(aiImportProvider);

    // Listen for completion
    ref.listen<AIImportStateData>(aiImportProvider, (previous, next) {
      if (next.state == AIImportState.completed) {
        AppFeedback.showSuccess(context, 'Cash flows imported successfully!');
        // Pop both screens
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else if (next.state == AIImportState.error && next.errorMessage != null) {
        AppFeedback.showError(context, next.errorMessage!);
      }
    });

    final extractionResult = importState.extractionResult;
    if (extractionResult == null) {
      return const Scaffold(body: Center(child: Text('No data to review')));
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : AppColors.neutral700Light,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Review Extracted Data',
          style: AppTypography.h3.copyWith(
            color: isDark ? Colors.white : AppColors.neutral900Light,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              final notifier = ref.read(aiImportProvider.notifier);
              if (extractionResult.selectedCount == extractionResult.count) {
                notifier.deselectAll();
              } else {
                notifier.selectAll();
              }
            },
            child: Text(
              extractionResult.selectedCount == extractionResult.count
                  ? 'Deselect All'
                  : 'Select All',
              style: AppTypography.body.copyWith(color: AppColors.primaryLight),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Investment Name',
                    style: AppTypography.small.copyWith(
                      color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _investmentNameController,
                    style: AppTypography.bodyLarge.copyWith(
                      color: isDark ? Colors.white : AppColors.neutral900Light,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter investment name',
                      hintStyle: AppTypography.body.copyWith(
                        color: isDark ? AppColors.neutral500Dark : AppColors.neutral400Light,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (value) {
                      ref.read(aiImportProvider.notifier).setNewInvestmentName(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildSummaryChip(
                        '${extractionResult.selectedCount}/${extractionResult.count}',
                        'Selected',
                        AppColors.primaryLight,
                        isDark,
                      ),
                      const SizedBox(width: 12),
                      _buildSummaryChip(
                        _calculateTotal(extractionResult.selectedCashFlows, currencySymbol),
                        'Net Flow',
                        AppColors.successLight,
                        isDark,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Cash flows list
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: extractionResult.cashFlows.length,
              itemBuilder: (context, index) {
                final cashFlow = extractionResult.cashFlows[index];
                return _buildCashFlowCard(cashFlow, currencySymbol, isDark);
              },
            ),
          ),

          // Bottom action bar
          Container(
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: GradientButton(
                onPressed: extractionResult.selectedCount > 0
                    ? () async {
                        HapticFeedback.mediumImpact();
                        final navigator = Navigator.of(context);
                        final count = await ref
                            .read(aiImportProvider.notifier)
                            .saveSelectedCashFlows();
                        if (count > 0 && mounted) {
                          if (context.mounted) {
                            AppFeedback.showSuccess(
                              context,
                              'Imported $count cash flows successfully!',
                            );
                          }
                          navigator.popUntil((route) => route.isFirst);
                        }
                      }
                    : null,
                isLoading: importState.state == AIImportState.saving,
                icon: Icons.check_rounded,
                label: 'Import ${extractionResult.selectedCount} Cash Flows',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(String value, String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            label,
            style: AppTypography.small.copyWith(
              color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
            ),
          ),
        ],
      ),
    );
  }

  String _calculateTotal(List<ExtractedCashFlow> cashFlows, String currencySymbol) {
    double total = 0;
    for (final cf in cashFlows) {
      if (cf.type.isOutflow) {
        total -= cf.amount;
      } else {
        total += cf.amount;
      }
    }
    final prefix = total >= 0 ? '+' : '';
    return '$prefix$currencySymbol${total.abs().toStringAsFixed(0)}';
  }

  Widget _buildCashFlowCard(ExtractedCashFlow cashFlow, String currencySymbol, bool isDark) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(aiImportProvider.notifier).toggleCashFlowSelection(cashFlow.id);
        },
        child: Row(
          children: [
            // Checkbox
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: cashFlow.isSelected
                    ? AppColors.primaryLight
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: cashFlow.isSelected
                      ? AppColors.primaryLight
                      : (isDark ? AppColors.neutral600Dark : AppColors.neutral300Light),
                  width: 2,
                ),
              ),
              child: cashFlow.isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 16),
            // Type icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cashFlow.type.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                cashFlow.type.iconData,
                color: cashFlow.type.color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        cashFlow.type.displayName,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.neutral900Light,
                        ),
                      ),
                      Text(
                        '${cashFlow.type.isOutflow ? '-' : '+'}$currencySymbol${cashFlow.amount.toStringAsFixed(2)}',
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cashFlow.type.isOutflow
                              ? AppColors.dangerLight
                              : AppColors.successLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dateFormat.format(cashFlow.date),
                        style: AppTypography.small.copyWith(
                          color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                        ),
                      ),
                      _buildConfidenceBadge(cashFlow, isDark),
                    ],
                  ),
                  if (cashFlow.notes != null && cashFlow.notes!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      cashFlow.notes!,
                      style: AppTypography.small.copyWith(
                        color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfidenceBadge(ExtractedCashFlow cashFlow, bool isDark) {
    Color color;
    if (cashFlow.confidence >= 0.9) {
      color = AppColors.successLight;
    } else if (cashFlow.confidence >= 0.7) {
      color = AppColors.warningLight;
    } else {
      color = AppColors.dangerLight;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${(cashFlow.confidence * 100).toInt()}%',
        style: AppTypography.small.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

