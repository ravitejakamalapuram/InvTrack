import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/widgets/empty_state_widget.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_provider.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_investment_screen.dart';
import 'package:inv_tracker/features/investment/presentation/screens/investment_detail_screen.dart';
import 'package:inv_tracker/features/portfolio/presentation/providers/portfolio_provider.dart';

class InvestmentListScreen extends ConsumerWidget {
  const InvestmentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfoliosAsync = ref.watch(allPortfoliosProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Investments', style: AppTypography.h3),
      ),
      body: portfoliosAsync.when(
        data: (portfolios) {
          if (portfolios.isEmpty) {
            return EmptyStateWidget(
              title: 'No Portfolios',
              message: 'Create a portfolio to start tracking your investments.',
              icon: Icons.pie_chart_outline,
              actionLabel: 'Create Default Portfolio',
              onAction: () {
                ref.read(portfolioProvider.notifier).createDefaultPortfolioIfNone();
              },
            );
          }

          // For now, just show investments for the first portfolio
          // In real app, we'd have a tab bar or dropdown to switch portfolios
          final portfolioId = portfolios.first.id;
          final investmentsAsync = ref.watch(investmentsByPortfolioProvider(portfolioId));

          return investmentsAsync.when(
            data: (investments) {
              if (investments.isEmpty) {
                return EmptyStateWidget(
                  title: 'No Investments',
                  message: 'Add your first investment to see it here.',
                  icon: Icons.show_chart,
                  actionLabel: 'Add Investment',
                  onAction: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const AddInvestmentScreen()),
                    );
                  },
                );
              }
              return ListView.builder(
                itemCount: investments.length,
                itemBuilder: (context, index) {
                  final investment = investments[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryLight.withValues(alpha: 0.1),
                      child: Text(investment.symbol?.substring(0, 1) ?? investment.name.substring(0, 1)),
                    ),
                    title: Text(investment.name, style: AppTypography.body),
                    subtitle: Text(investment.type, style: AppTypography.caption),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => InvestmentDetailScreen(investment: investment),
                        ),
                      );
                    },
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading portfolios: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddInvestmentScreen()),
          );
        },
        backgroundColor: AppColors.primaryLight,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
