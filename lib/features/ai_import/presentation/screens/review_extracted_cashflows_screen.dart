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
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final initialName = ref.read(aiImportProvider).newInvestmentName ?? '';
    _nameController = TextEditingController(text: initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
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
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else if (next.state == AIImportState.error && next.errorMessage != null) {
        AppFeedback.showError(context, next.errorMessage!);
      }
    });

    final extractionResult = importState.extractionResult;
    if (extractionResult == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review')),
        body: const Center(child: Text('No data to review')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Extracted Data'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => ref.read(aiImportProvider.notifier).selectAll(),
            child: const Text('Select All'),
          ),
          TextButton(
            onPressed: () => ref.read(aiImportProvider.notifier).deselectAll(),
            child: const Text('Deselect'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Investment name input
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Investment Name',
                hintText: 'Enter investment name',
                prefixIcon: const Icon(Icons.business_center),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                ref.read(aiImportProvider.notifier).setNewInvestmentName(value);
              },
            ),
          ),

          // Info bar
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            child: Row(
              children: [
                Text(
                  '${extractionResult.selectedCount} of ${extractionResult.cashFlows.length} selected',
                  style: AppTypography.body,
                ),
                const Spacer(),
                _buildConfidenceLegend(isDark),
              ],
            ),
          ),

          // Cash flows list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: extractionResult.cashFlows.length,
              itemBuilder: (context, index) {
                final cf = extractionResult.cashFlows[index];
                return _buildCashFlowCard(cf, isDark, currencySymbol);
              },
            ),
          ),

          // Bottom save button
          _buildBottomBar(isDark, importState, extractionResult),
        ],
      ),
    );
  }

  Widget _buildConfidenceLegend(bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _confidenceDot(Colors.green, 'High'),
        const SizedBox(width: AppSpacing.sm),
        _confidenceDot(Colors.orange, 'Med'),
        const SizedBox(width: AppSpacing.sm),
        _confidenceDot(Colors.red, 'Low'),
      ],
    );
  }

  Widget _confidenceDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _buildCashFlowCard(ExtractedCashFlow cf, bool isDark, String currencySymbol) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final confidenceColor = cf.confidence >= 0.9
        ? Colors.green
        : cf.confidence >= 0.7
            ? Colors.orange
            : Colors.red;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GlassCard(
        child: CheckboxListTile(
          value: cf.isSelected,
          onChanged: (_) {
            HapticFeedback.selectionClick();
            ref.read(aiImportProvider.notifier).toggleCashFlowSelection(cf.id);
          },
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cf.type.isOutflow ? Colors.red.withAlpha(50) : Colors.green.withAlpha(50),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  cf.type.displayName,
                  style: TextStyle(
                    color: cf.type.isOutflow ? Colors.red : Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(color: confidenceColor, shape: BoxShape.circle),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$currencySymbol${cf.amount.toStringAsFixed(2)}',
                style: AppTypography.h3,
              ),
              Text(
                dateFormat.format(cf.date),
                style: AppTypography.body,
              ),
              if (cf.notes != null && cf.notes!.isNotEmpty)
                Text(cf.notes!, style: AppTypography.caption),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool isDark, AIImportStateData importState, AIExtractionResult extractionResult) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
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
                  final count = await ref.read(aiImportProvider.notifier).saveSelectedCashFlows();
                  if (count > 0 && mounted) {
                    if (context.mounted) {
                      AppFeedback.showSuccess(context, 'Imported $count cash flows successfully!');
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
    );
  }
}

