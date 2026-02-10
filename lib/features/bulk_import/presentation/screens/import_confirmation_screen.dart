import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/gradient_button.dart';
import 'package:inv_tracker/features/bulk_import/data/services/simple_csv_parser.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:uuid/uuid.dart';

class ImportConfirmationScreen extends ConsumerStatefulWidget {
  final ParsedCsvResult parseResult;
  final String fileName;

  const ImportConfirmationScreen({
    super.key,
    required this.parseResult,
    required this.fileName,
  });

  @override
  ConsumerState<ImportConfirmationScreen> createState() =>
      _ImportConfirmationScreenState();
}

class _ImportConfirmationScreenState
    extends ConsumerState<ImportConfirmationScreen> {
  bool _isImporting = false;
  final _dateFormat = DateFormat('MMM d, yyyy');

  /// Group rows by investment name
  Map<String, List<ParsedCashFlowRow>> get _groupedByInvestment {
    final map = <String, List<ParsedCashFlowRow>>{};
    for (final row in widget.parseResult.validRowsOnly) {
      final name = _normalizeInvestmentName(row.investmentName);
      map.putIfAbsent(name, () => []).add(row);
    }
    return map;
  }

  String _normalizeInvestmentName(String name) {
    // Normalize for grouping but preserve original display name
    return name.trim();
  }

  Future<void> _importAll() async {
    HapticFeedback.mediumImpact();
    setState(() => _isImporting = true);

    try {
      final notifier = ref.read(investmentNotifierProvider.notifier);
      final grouped = _groupedByInvestment;
      const uuid = Uuid();
      final now = DateTime.now();

      // Prepare all data upfront - no calculations, just data preparation
      final investments = <InvestmentEntity>[];
      final cashFlows = <CashFlowEntity>[];

      for (final entry in grouped.entries) {
        final investmentName = entry.key;
        final rows = entry.value;
        final investmentId = uuid.v4();

        // Get investment type and status from the first row (if available)
        // All rows for the same investment should have the same type/status
        final firstRow = rows.first;
        final investmentType = firstRow.investmentType ?? InvestmentType.other;
        final investmentStatus =
            firstRow.investmentStatus ?? InvestmentStatus.open;

        // Create investment entity
        investments.add(
          InvestmentEntity(
            id: investmentId,
            name: investmentName,
            type: investmentType,
            status: investmentStatus,
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Create all cash flow entities for this investment
        for (final row in rows) {
          cashFlows.add(
            CashFlowEntity(
              id: uuid.v4(),
              investmentId: investmentId,
              type: row.type,
              amount: row.amount,
              date: row.date,
              notes: row.notes,
              createdAt: now,
            ),
          );
        }
      }

      // Bulk import all data at once - single batch write, single provider invalidation
      final result = await notifier.bulkImport(
        investments: investments,
        cashFlows: cashFlows,
      );

      // Track successful import
      ref
          .read(analyticsServiceProvider)
          .logCsvImportCompleted(
            rowCount: widget.parseResult.validRows,
            successCount: result.investments,
          );

      if (mounted) {
        AppFeedback.showSuccess(
          context,
          'Created ${result.investments} investments with ${result.cashFlows} cash flows',
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, 'Import failed: $e');
      }
    } finally {
      setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final grouped = _groupedByInvestment;
    final currencyFormat = ref.watch(currencyFormatProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.confirmImport), centerTitle: true),
      body: Column(
        children: [
          // Summary header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            child: Column(
              children: [
                Text('Ready to Import', style: AppTypography.h3),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${grouped.length} investments • ${widget.parseResult.validRows} cash flows',
                  style: AppTypography.body,
                ),
                if (widget.parseResult.hasErrors) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${widget.parseResult.errors.length} rows skipped due to errors',
                    style: TextStyle(color: Colors.orange[700], fontSize: 12),
                  ),
                ],
              ],
            ),
          ),

          // Investment list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: grouped.length,
              itemBuilder: (context, index) {
                final name = grouped.keys.elementAt(index);
                final rows = grouped[name]!;
                return _buildInvestmentCard(name, rows, isDark, currencyFormat);
              },
            ),
          ),

          // Import button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: GradientButton(
                onPressed: _isImporting ? null : _importAll,
                isLoading: _isImporting,
                icon: Icons.check_circle_rounded,
                label: 'Import All',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvestmentCard(
    String name,
    List<ParsedCashFlowRow> rows,
    bool isDark,
    NumberFormat currencyFormat,
  ) {
    double totalInvested = 0;
    double totalIncome = 0;
    double totalReturned = 0;

    for (final row in rows) {
      switch (row.type) {
        case CashFlowType.invest:
        case CashFlowType.fee:
          totalInvested += row.amount;
          break;
        case CashFlowType.income:
          totalIncome += row.amount;
          break;
        case CashFlowType.returnFlow:
          totalReturned += row.amount;
          break;
      }
    }

    return GlassCard(
      child: ExpansionTile(
        title: Text(name, style: AppTypography.h4),
        subtitle: Text(
          '${rows.length} cash flows',
          style: AppTypography.caption,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  'Invested',
                  totalInvested,
                  Colors.red,
                  currencyFormat,
                ),
                _buildSummaryItem(
                  'Income',
                  totalIncome,
                  Colors.green,
                  currencyFormat,
                ),
                _buildSummaryItem(
                  'Returned',
                  totalReturned,
                  Colors.blue,
                  currencyFormat,
                ),
              ],
            ),
          ),
          const Divider(),
          ...rows.map(
            (row) => ListTile(
              dense: true,
              leading: _buildTypeChip(row.type),
              title: Text(_dateFormat.format(row.date)),
              trailing: Text(
                currencyFormat.formatCompact(row.amount),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:
                      row.type == CashFlowType.invest ||
                          row.type == CashFlowType.fee
                      ? Colors.red
                      : Colors.green,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    double amount,
    Color color,
    NumberFormat currencyFormat,
  ) {
    return Column(
      children: [
        Text(label, style: AppTypography.caption),
        Text(
          currencyFormat.formatCompact(amount),
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildTypeChip(CashFlowType type) {
    Color color;
    String label;
    switch (type) {
      case CashFlowType.invest:
        color = Colors.red;
        label = 'INV';
        break;
      case CashFlowType.income:
        color = Colors.green;
        label = 'INC';
        break;
      case CashFlowType.returnFlow:
        color = Colors.blue;
        label = 'RET';
        break;
      case CashFlowType.fee:
        color = Colors.orange;
        label = 'FEE';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
