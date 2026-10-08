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

/// One investment in the file, and where its rows go.
class _ImportGroup {
  const _ImportGroup({
    required this.name,
    required this.rows,
    required this.toImport,
    required this.existingId,
    required this.matchesArchived,
    required this.hasAmbiguousActiveMatches,
  });

  final String name;

  /// Every valid row, each shown with its duplicate label.
  final List<ParsedCashFlowRow> rows;

  /// The rows Import writes: likely duplicates are left out while skipping.
  final List<ParsedCashFlowRow> toImport;

  /// The active investment that already holds some of these rows; the rest
  /// are added to it instead of to a second investment with the same name.
  /// Null for a new investment.
  final String? existingId;

  /// Some rows match an archived investment, so the others become a new
  /// investment beside it (archived ones take no new cash flows).
  final bool matchesArchived;

  /// More than one active investment matched duplicate rows for this name.
  /// Import must stop rather than guessing which investment owns the new rows.
  final bool hasAmbiguousActiveMatches;
}

class _ImportConfirmationScreenState
    extends ConsumerState<ImportConfirmationScreen> {
  bool _isImporting = false;
  final _dateFormat = DateFormat('MMM d, yyyy');

  /// Leave rows that match an existing cash flow out of the import.
  bool _skipDuplicates = true;

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

  String _normalizeInvestmentName(String name) {
    // Normalize for grouping but preserve original display name
    return name.trim();
  }

  /// How duplicates compare names: ignoring case and surrounding spaces.
  static String _nameKey(String name) => name.trim().toLowerCase();

  /// Where each investment in the file goes, given the likely [duplicates]
  /// (row number to the investment holding it) and the ids of the user's
  /// active investments.
  List<_ImportGroup> _plan(
    Map<int, String> duplicates,
    Set<String> activeIds,
  ) => [
    for (final MapEntry(key: name, value: rows) in _groupByInvestment(
      widget.parseResult.validRowsOnly,
    ).entries)
      _planGroup(name, rows, duplicates, activeIds),
  ];

  _ImportGroup _planGroup(
    String name,
    List<ParsedCashFlowRow> rows,
    Map<int, String> duplicates,
    Set<String> activeIds,
  ) {
    // The active investment holding most of this group's duplicates.
    final matches = <String, int>{};
    var matchesArchived = false;
    for (final row in rows) {
      final id = duplicates[row.rowNumber];
      if (id == null) continue;
      if (activeIds.contains(id)) {
        matches[id] = (matches[id] ?? 0) + 1;
      } else {
        matchesArchived = true;
      }
    }
    final hasAmbiguousActiveMatches = matches.length > 1;
    final existingId = matches.length == 1 ? matches.keys.single : null;
    return _ImportGroup(
      name: name,
      rows: rows,
      toImport: [
        for (final row in rows)
          if (!_skipDuplicates || !duplicates.containsKey(row.rowNumber)) row,
      ],
      existingId: existingId,
      matchesArchived: existingId == null && matchesArchived,
      hasAmbiguousActiveMatches: hasAmbiguousActiveMatches,
    );
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

  Future<void> _importAll(List<_ImportGroup> groups) async {
    HapticFeedback.mediumImpact();
    final l10n = AppLocalizations.of(context);
    setState(() => _isImporting = true);

    try {
      final notifier = ref.read(investmentNotifierProvider.notifier);
      final baseCurrency = ref.read(currencyCodeProvider);
      const uuid = Uuid();
      final now = DateTime.now();

      // Prepare all data upfront - no calculations, just data preparation
      final investments = <InvestmentEntity>[];
      final cashFlows = <CashFlowEntity>[];

      for (final group in groups) {
        final rows = group.toImport;
        if (rows.isEmpty) continue;
        final investmentId = group.existingId ?? uuid.v4();

        if (group.existingId == null) {
          // Get investment type and status from the first row (if available)
          // All rows for the same investment should have the same type/status
          final firstRow = rows.first;
          investments.add(
            InvestmentEntity(
              id: investmentId,
              name: group.name,
              type: firstRow.investmentType ?? InvestmentType.other,
              status: firstRow.investmentStatus ?? InvestmentStatus.open,
              createdAt: now,
              updatedAt: now,
              currency: _investmentCurrency(rows, baseCurrency),
            ),
          );
        }

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
          result.investments == 0
              ? l10n.importAddedSummary(
                  l10n.importCashFlowCount(result.cashFlows),
                )
              : l10n.importCreatedSummary(
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

  /// Loads the user's investments again after the duplicate check failed.
  void _retryDuplicateCheck() {
    reloadPortfolio(ref);
    ref.invalidate(archivedCashFlowsByInvestmentProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseCurrency = ref.watch(currencyCodeProvider);
    final validRows = widget.parseResult.validRowsOnly;

    // Duplicates are checked against active and archived investments.
    // Archived cash flows are only loaded for names that are in the file.
    final active = ref.watch(allInvestmentsProvider);
    final activeFlows = ref.watch(allCashFlowsStreamProvider);
    final archived = ref.watch(archivedInvestmentsProvider);
    final fileNames = {for (final r in validRows) _nameKey(r.investmentName)};
    final archivedMatches = [
      for (final i in archived.value ?? const <InvestmentEntity>[])
        if (fileNames.contains(_nameKey(i.name))) i,
    ];
    final archivedFlows = [
      for (final i in archivedMatches)
        ref.watch(archivedCashFlowsByInvestmentProvider(i.id)),
    ];
    final sources = <AsyncValue<Object?>>[
      active,
      activeFlows,
      archived,
      ...archivedFlows,
    ];
    // A failed load is not "no duplicates": import waits for a retry.
    final checkFailed = sources.any((s) => s.hasError);
    final checkingDuplicates = !checkFailed && sources.any((s) => !s.hasValue);
    final duplicates = checkFailed || checkingDuplicates
        ? const <int, String>{}
        : findLikelyDuplicateRows(
            validRows,
            investments: [...active.requireValue, ...archivedMatches],
            cashFlows: [
              ...activeFlows.requireValue,
              for (final flows in archivedFlows) ...flows.requireValue,
            ],
            baseCurrency: baseCurrency,
          );
    final activeIds = {
      for (final i in active.value ?? const <InvestmentEntity>[]) i.id,
    };
    final groups = _plan(duplicates, activeIds);
    final hasAmbiguousActiveMatches = groups.any(
      (group) => group.hasAmbiguousActiveMatches,
    );
    final newInvestmentCount = groups
        .where((g) => g.existingId == null && g.toImport.isNotEmpty)
        .length;
    final cashFlowCount = groups.fold(0, (n, g) => n + g.toImport.length);

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
                    l10n.importInvestmentCount(newInvestmentCount),
                    l10n.importCashFlowCount(cashFlowCount),
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
                if (checkFailed) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.importDuplicateCheckFailed,
                    style: TextStyle(color: Colors.orange[700], fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: _retryDuplicateCheck,
                    child: Text(l10n.retry),
                  ),
                ],
                if (duplicates.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.importLikelyDuplicates(duplicates.length),
                    style: TextStyle(color: Colors.orange[700], fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  if (hasAmbiguousActiveMatches) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.importDuplicateCheckFailed,
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
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
              itemCount: groups.length,
              itemBuilder: (context, index) => _buildInvestmentCard(
                groups[index],
                isDark,
                baseCurrency,
                duplicates,
                activeIds,
              ),
            ),
          ),

          // Import button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: GradientButton(
                onPressed:
                    _isImporting ||
                        checkingDuplicates ||
                        checkFailed ||
                        hasAmbiguousActiveMatches ||
                        cashFlowCount == 0
                    ? null
                    : () => _importAll(groups),
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
    _ImportGroup group,
    bool isDark,
    String baseCurrency,
    Map<int, String> duplicates,
    Set<String> activeIds,
  ) {
    final l10n = AppLocalizations.of(context);
    // Counts and totals cover only what Import writes.
    final rows = group.toImport;
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
        title: Text(group.name, style: AppTypography.h4),
        subtitle: Text(
          l10n.importCardSubtitle(
            l10n.importCashFlowCount(rows.length),
            currency,
          ),
          style: AppTypography.caption,
        ),
        children: [
          if (group.existingId != null || group.matchesArchived)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Text(
                group.existingId != null
                    ? l10n.importAddsToExisting
                    : l10n.importNewBesideArchived,
                style: AppTypography.caption,
              ),
            ),
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
          ...group.rows.map(
            (row) => ListTile(
              dense: true,
              leading: _buildTypeChip(row.type, l10n),
              title: Text(_dateFormat.format(row.date)),
              subtitle: Wrap(
                spacing: AppSpacing.sm,
                children: [
                  Text(_rowCurrency(row, baseCurrency)),
                  if (duplicates[row.rowNumber] case final id?)
                    Text(
                      activeIds.contains(id)
                          ? l10n.importDuplicateLabel
                          : l10n.importDuplicateArchivedLabel,
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
