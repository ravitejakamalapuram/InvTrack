import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/utils/financial_calculators.dart';
import 'package:inv_tracker/domain/entities/entry.dart';
import 'package:inv_tracker/domain/entities/investment.dart';
import 'package:inv_tracker/presentation/providers/repository_providers.dart';
import 'package:inv_tracker/presentation/screens/entry_form_modal.dart';

/// Investment detail screen.
class InvestmentDetailScreen extends ConsumerWidget {
  final String investmentId;

  const InvestmentDetailScreen({super.key, required this.investmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final investmentsAsync = ref.watch(investmentsProvider);
    final entriesAsync = ref.watch(entriesProvider(investmentId));

    return investmentsAsync.when(
      data: (investments) {
        final investment = investments.where((i) => i.id == investmentId).firstOrNull;
        if (investment == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Investment not found')));
        }
        return _buildContent(context, ref, investment, entriesAsync);
      },
      loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, Investment investment, AsyncValue<List<Entry>> entriesAsync) {
    final categoryColor = AppColors.getCategoryColor(investment.category);

    return Scaffold(
      appBar: AppBar(
        title: Text(investment.name),
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: () => context.go('${AppRoutes.investments}/${investment.id}/edit')),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Investment'),
                    content: const Text('Are you sure you want to delete this investment? This action cannot be undone.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.error))),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  final repo = ref.read(investmentRepositoryProvider);
                  await repo?.delete(investment.id);
                  if (context.mounted) context.go(AppRoutes.investments);
                }
              }
            },
            itemBuilder: (ctx) => [const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.error)))],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Card(
              child: Padding(
                padding: AppSpacing.cardPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(color: categoryColor.withOpacity(0.1), borderRadius: AppSpacing.borderRadiusSm),
                          child: Center(child: Text(investment.name[0].toUpperCase(), style: TextStyle(color: categoryColor, fontSize: 24, fontWeight: FontWeight.bold))),
                        ),
                        AppSpacing.gapHorizontalMd,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(investment.name, style: Theme.of(context).textTheme.titleLarge),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: categoryColor.withOpacity(0.1), borderRadius: AppSpacing.borderRadiusXs),
                                child: Text(_formatCategory(investment.category), style: TextStyle(color: categoryColor, fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (investment.notes != null && investment.notes!.isNotEmpty) ...[
                      AppSpacing.gapVerticalMd,
                      Text(investment.notes!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
                    ],
                  ],
                ),
              ),
            ),
            AppSpacing.gapVerticalMd,

            // Financial metrics
            _buildMetricsCard(context, entriesAsync),
            AppSpacing.gapVerticalXl,

            // Entries section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Transactions', style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(icon: const Icon(Icons.add, size: 18), label: const Text('Add'), onPressed: () => showEntryFormModal(context, investmentId)),
              ],
            ),
            AppSpacing.gapVerticalSm,
            _buildEntriesList(context, entriesAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildEntriesList(BuildContext context, AsyncValue<List<Entry>> entriesAsync) {
    return entriesAsync.when(
      data: (entries) {
        if (entries.isEmpty) {
          return Card(child: Padding(padding: AppSpacing.cardPadding, child: Center(child: Text('No transactions yet', style: TextStyle(color: Colors.grey[600])))));
        }
        return Column(children: entries.map((e) => _EntryTile(entry: e)).toList());
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildMetricsCard(BuildContext context, AsyncValue<List<Entry>> entriesAsync) {
    return entriesAsync.when(
      data: (entries) {
        if (entries.isEmpty) return const SizedBox.shrink();
        final invested = FinancialCalculators.calculateTotalInvested(entries);
        final currentValue = FinancialCalculators.getCurrentValue(entries);
        final dividends = FinancialCalculators.calculateTotalDividends(entries);
        if (currentValue == null) {
          return Card(
            child: Padding(
              padding: AppSpacing.cardPadding,
              child: Column(
                children: [
                  _MetricRow(label: 'Total Invested', value: '₹${invested.toStringAsFixed(0)}'),
                  if (dividends > 0) _MetricRow(label: 'Dividends', value: '₹${dividends.toStringAsFixed(0)}', color: AppColors.success),
                  const Divider(),
                  Text('Add a valuation entry to see returns', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
          );
        }
        final pl = FinancialCalculators.calculateAbsolutePL(currentValue, invested);
        final plPercent = FinancialCalculators.calculatePercentagePL(currentValue, invested);
        final moic = FinancialCalculators.calculateMOIC(currentValue, invested);
        final isProfit = pl >= 0;
        return Card(
          child: Padding(
            padding: AppSpacing.cardPadding,
            child: Column(
              children: [
                _MetricRow(label: 'Current Value', value: '₹${currentValue.toStringAsFixed(0)}', isBold: true),
                _MetricRow(label: 'Total Invested', value: '₹${invested.toStringAsFixed(0)}'),
                _MetricRow(label: 'P/L', value: '${isProfit ? '+' : ''}₹${pl.toStringAsFixed(0)} (${plPercent.toStringAsFixed(1)}%)', color: isProfit ? AppColors.profit : AppColors.loss),
                _MetricRow(label: 'MOIC', value: '${moic.toStringAsFixed(2)}x'),
                if (dividends > 0) _MetricRow(label: 'Dividends', value: '₹${dividends.toStringAsFixed(0)}', color: AppColors.success),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  String _formatCategory(String category) => category.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}').trim();
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool isBold;
  const _MetricRow({required this.label, required this.value, this.color, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: TextStyle(color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.w500, fontSize: isBold ? 18 : 14)),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final Entry entry;
  const _EntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isInflow = entry.type == EntryType.inflow || entry.type == EntryType.dividend;
    final color = isInflow ? AppColors.profit : (entry.type == EntryType.outflow ? AppColors.loss : Colors.grey);
    final icon = isInflow ? Icons.arrow_downward : (entry.type == EntryType.outflow ? Icons.arrow_upward : Icons.sync);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 20)),
        title: Text(entry.type.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(DateFormat.yMMMd().format(entry.date)),
        trailing: Text('₹${entry.amount.toStringAsFixed(2)}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}

