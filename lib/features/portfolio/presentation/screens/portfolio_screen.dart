import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/portfolio/presentation/providers/portfolio_provider.dart';

class PortfolioScreen extends ConsumerWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfoliosAsync = ref.watch(allPortfoliosProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Portfolios', style: AppTypography.h3),
      ),
      body: portfoliosAsync.when(
        data: (portfolios) {
          if (portfolios.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No portfolios yet.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _showAddPortfolioDialog(context, ref),
                    child: const Text('Create Portfolio'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: portfolios.length,
            itemBuilder: (context, index) {
              final portfolio = portfolios[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(portfolio.name, style: AppTypography.body),
                  subtitle: Text('${portfolio.currency} • Created ${DateFormat.yMMMd().format(portfolio.createdAt)}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Navigate to portfolio details or filter dashboard
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPortfolioDialog(context, ref),
        tooltip: 'Add Portfolio',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddPortfolioDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Portfolio'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Portfolio Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await ref.read(portfolioProvider.notifier).createPortfolio(
                  name: nameController.text,
                  currency: 'USD', // Default for now
                );
                if (context.mounted) context.pop();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
