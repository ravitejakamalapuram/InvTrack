import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_provider.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_transaction_screen.dart';
import 'package:intl/intl.dart';

class InvestmentDetailScreen extends ConsumerWidget {
  final InvestmentEntity investment;

  const InvestmentDetailScreen({super.key, required this.investment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsByInvestmentProvider(investment.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(investment.name, style: AppTypography.h3),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Edit Investment
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Card (Placeholder for now)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppColors.neutral100Light,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Symbol: ${investment.symbol ?? "N/A"}', style: AppTypography.body),
                Text('Type: ${investment.type}', style: AppTypography.body),
              ],
            ),
          ),
          Expanded(
            child: transactionsAsync.when(
              data: (transactions) {
                if (transactions.isEmpty) {
                  return const Center(child: Text('No transactions yet.'));
                }
                return ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    return Dismissible(
                      key: Key(transaction.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text("Confirm"),
                              content: const Text("Are you sure you want to delete this transaction?"),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text("CANCEL"),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text("DELETE"),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      onDismissed: (direction) {
                        ref.read(investmentProvider.notifier).deleteTransaction(transaction.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Transaction deleted')),
                        );
                      },
                      child: ListTile(
                        leading: Icon(
                          transaction.type == 'BUY' ? Icons.arrow_downward : Icons.arrow_upward,
                          color: transaction.type == 'BUY' ? Colors.green : Colors.red,
                        ),
                        title: Text('${transaction.type} ${transaction.quantity} units'),
                        subtitle: Text(DateFormat.yMMMd().format(transaction.date)),
                        trailing: Text(
                          '\$${transaction.totalAmount.toStringAsFixed(2)}',
                          style: AppTypography.body.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AddTransactionScreen(investmentId: investment.id),
            ),
          );
        },
        label: const Text('Add Transaction'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
