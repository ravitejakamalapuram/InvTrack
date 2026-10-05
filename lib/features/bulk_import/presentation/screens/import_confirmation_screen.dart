import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/gradient_button.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/features/bulk_import/data/services/import_duplicate_detector.dart';
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

  /// Leave rows that match an existing cash flow out of the import.
  bool _skipDuplicates = true;

  /// Still waiting for the first load, so duplicates cannot be checked yet.
  static bool _pending(AsyncValue<Object?> value) =>
      !value.hasValue && !value.hasError;

  /// Group rows by investment name
  Map<String, List<ParsedCashFlowRow>> _groupByInvestment(
    Iterable<ParsedCashFlowRow> rows,
  ) {
    final map = <String, List<ParsedCashFlowRow>>{};
    for (final row in rows) {
      final name = _normalizeInvestmentName(row.investmentName);
      map.putIfAbsent(name, () => []).add(row);
    }
    return map;
  }

  Map<String, List<ParsedCashFlowRow>> get _groupedByInvestment =>
      _groupByInvestment(widget.parseResult.validRowsOnly);

  String _normalizeInvestmentName(String name) {
    // Normalize for grouping but preserve original display name
    return name.trim();
  }

  /// A row's currency: from the CSV, or the user's base currency when the
  /// CSV has none (never USD).
  String _rowCurrency(ParsedCashFlowRow row, String baseCurrency) =>
      row.currency ?? baseCurrency;

  /// The investment's currency: the one its rows share, else the base.
  String _investmentCurrency(
    List<ParsedCashFlowRow> rows,
    String baseCurrency,
  ) => resolveSharedCurrency(
    rows.map((r) => _rowCurrency(r, baseCurrency)),
    baseCurrency,
  );

  String _formatIn(double amount, String currency) => formatCompactCurrency(
    amount,
    symbol: getCurrencySymbol(currency),
    locale: getCurrencyLocale(currency),
  );

  Future<void> _importAll(Set<int> duplicates) async {
    HapticFeedback.mediumImpact();
    final l10n = AppLocalizations.of(context);
    setState(() => _isImporting = true);

    try {
      final notifier = ref.read(investmentNotifierProvider.notifier);
      final grouped = _groupByInvestment(
        widget.parseResult.validRowsOnly.where(
          (row) => !_skipDuplicates || !duplicates.contains(row.rowNumber),
        ),
      );
      final baseCurrency = ref.read(currencyCodeProvider);
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
            currency: _investmentCurrency(rows, baseCurrency),
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
              currency: _rowCurrency(row, baseCurrency), // Rule 21.4
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
          l10n.importCreatedSummary(
            l10n.importInvestmentCount(result.investments),
            l10n.importCashFlowCount(result.cashFlows),
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e, st) {
      // The error text can hold a file path or a name, so only its type is
      // reported (CLAUDE.md rule 7), and the user sees a fixed message.
      LoggerService.error(
        'CSV import failed to save',
        stackTrace: st,
        metadata: {
          'operation': 'csvImport',
          'errorType': e.runtimeType.toString(),
        },
      );
      if (mounted) {
        AppFeedback.showError(context, l10n.importFailedTryAgain);
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final grouped = _groupedByInvestment;
    final baseCurrency = ref.watch(currencyCodeProvider);
    final existingInvestments = ref.watch(allInvestmentsProvider);
    final existingCashFlows = ref.watch(allCashFlowsStreamProvider);
    // Importing before the user's data has loaded would skip the check.
    final checkingDuplicates =
        _pending(existingInvestments) || _pending(existingCashFlows);
    final duplicates = findLikelyDuplicateRows(
      widget.parseResult.validRowsOnly,
      investments: existingInvestments.value ?? const [],
      cashFlows: existingCashFlows.value ?? const [],
      baseCurrency: baseCurrency,
    );
    final nothingToImport =
        _skipDuplicates &&
        duplicates.length == widget.parseResult.validRowsOnly.length;

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
                Text(l10n.readyToImport, style: AppTypography.h3),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.importCountsSummary(
                    l10n.importInvestmentCount(grouped.length),
                    l10n.importCashFlowCount(widget.parseResult.validRows),
                  ),
                  style: AppTypography.body,
                ),
                if (widget.parseResult.hasErrors) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.importRowsSkipped(widget.parseResult.errors.length),
                    style: TextStyle(color: Colors.orange[700], fontSize: 12),
                  ),
                ],
                if (duplicates.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.importLikelyDuplicates(duplicates.length),
                    style: TextStyle(color: Colors.orange[700], fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  SwitchListTile(
                    value: _skipDuplicates,
                    onChanged: _isImporting
                        ? null
                        : (value) => setState(() => _skipDuplicates = value),
                    title: Text(
                      l10n.importSkipDuplicates,
                      style: AppTypography.body,
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
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
                return _buildInvestmentCard(
                  name,
                  rows,
                  isDark,
                  baseCurrency,
                  duplicates,
                );
              },
            ),
          ),

          // Import button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: GradientButton(
                onPressed: _isImporting || checkingDuplicates || nothingToImport
                    ? null
                    : () => _importAll(duplicates),
                isLoading: _isImporting || checkingDuplicates,
                icon: Icons.check_circle_rounded,
                label: l10n.importAllButton,
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
    String baseCurrency,
    Set<int> duplicates,
  ) {
    final l10n = AppLocalizations.of(context);
    final currency = _investmentCurrency(rows, baseCurrency);
    // Totals are only meaningful when every row is in the same currency
    final singleCurrency = rows.every(
      (r) => _rowCurrency(r, baseCurrency) == currency,
    );
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
          l10n.importCardSubtitle(
            l10n.importCashFlowCount(rows.length),
            currency,
          ),
          style: AppTypography.caption,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  l10n.investedLabel,
                  singleCurrency ? _formatIn(totalInvested, currency) : null,
                  Colors.red,
                ),
                _buildSummaryItem(
                  l10n.importIncomeLabel,
                  singleCurrency ? _formatIn(totalIncome, currency) : null,
                  Colors.green,
                ),
                _buildSummaryItem(
                  l10n.returnedLabel,
                  singleCurrency ? _formatIn(totalReturned, currency) : null,
                  Colors.blue,
                ),
              ],
            ),
          ),
          const Divider(),
          ...rows.map(
            (row) => ListTile(
              dense: true,
              leading: _buildTypeChip(row.type, l10n),
              title: Text(_dateFormat.format(row.date)),
              subtitle: Wrap(
                spacing: AppSpacing.sm,
                children: [
                  Text(_rowCurrency(row, baseCurrency)),
                  if (duplicates.contains(row.rowNumber))
                    Text(
                      l10n.importDuplicateLabel,
                      style: TextStyle(color: Colors.orange[700]),
                    ),
                ],
              ),
              trailing: MaskedAmountText(
                text: _formatIn(row.amount, _rowCurrency(row, baseCurrency)),
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

  /// A total, hidden in privacy mode. Null when the rows are in more than
  /// one currency, shown as "—".
  Widget _buildSummaryItem(String label, String? formattedAmount, Color color) {
    final style = TextStyle(fontWeight: FontWeight.bold, color: color);
    return Column(
      children: [
        Text(label, style: AppTypography.caption),
        formattedAmount == null
            ? Text('—', style: style)
            : MaskedAmountText(text: formattedAmount, style: style),
      ],
    );
  }

  Widget _buildTypeChip(CashFlowType type, AppLocalizations l10n) {
    Color color;
    String label;
    switch (type) {
      case CashFlowType.invest:
        color = Colors.red;
        label = l10n.importTypeChipInvest;
        break;
      case CashFlowType.income:
        color = Colors.green;
        label = l10n.importTypeChipIncome;
        break;
      case CashFlowType.returnFlow:
        color = Colors.blue;
        label = l10n.importTypeChipReturn;
        break;
      case CashFlowType.fee:
        color = Colors.orange;
        label = l10n.importTypeChipFee;
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
