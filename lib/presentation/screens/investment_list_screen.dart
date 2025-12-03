import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/domain/entities/investment.dart';
import 'package:inv_tracker/presentation/providers/repository_providers.dart';

/// Investment list screen.
class InvestmentListScreen extends ConsumerWidget {
  const InvestmentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final investmentsAsync = ref.watch(investmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Investments'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.filter_list), onPressed: () {}),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(investmentsProvider),
        child: investmentsAsync.when(
          data: (investments) => investments.isEmpty
              ? _buildEmptyState(context)
              : _buildInvestmentList(context, investments),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('${AppRoutes.investments}/new'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 80, color: Colors.grey[400]),
            AppSpacing.gapVerticalXl,
            Text('No investments yet', style: Theme.of(context).textTheme.titleLarge),
            AppSpacing.gapVerticalSm,
            Text(
              'Start tracking your investments by tapping the + button',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvestmentList(BuildContext context, List<Investment> investments) {
    return ListView.builder(
      padding: AppSpacing.paddingVerticalSm,
      itemCount: investments.length,
      itemBuilder: (context, index) {
        final inv = investments[index];
        return _InvestmentCard(investment: inv);
      },
    );
  }
}

class _InvestmentCard extends StatelessWidget {
  final Investment investment;

  const _InvestmentCard({required this.investment});

  @override
  Widget build(BuildContext context) {
    final categoryColor = AppColors.getCategoryColor(investment.category);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      child: InkWell(
        onTap: () => context.go('${AppRoutes.investments}/${investment.id}'),
        borderRadius: AppSpacing.borderRadiusMd,
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Row(
            children: [
              // Category indicator
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.1),
                  borderRadius: AppSpacing.borderRadiusSm,
                ),
                child: Center(
                  child: Text(
                    investment.name.isNotEmpty ? investment.name[0].toUpperCase() : '?',
                    style: TextStyle(color: categoryColor, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              AppSpacing.gapHorizontalMd,

              // Investment details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(investment.name, style: Theme.of(context).textTheme.titleMedium),
                    AppSpacing.gapVerticalXs,
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: categoryColor.withOpacity(0.1),
                            borderRadius: AppSpacing.borderRadiusXs,
                          ),
                          child: Text(
                            _formatCategory(investment.category),
                            style: TextStyle(color: categoryColor, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCategory(String category) {
    return category.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}').trim();
  }
}

