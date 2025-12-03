import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/presentation/providers/repository_providers.dart';

/// Dashboard/Home screen with KPI summary.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final investmentsAsync = ref.watch(investmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('InvTracker'),
        actions: [
          IconButton(
            icon: CircleAvatar(
              radius: 16,
              backgroundImage: user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
              child: user?.photoUrl == null ? const Icon(Icons.person, size: 20) : null,
            ),
            onPressed: () => context.go(AppRoutes.settings),
          ),
          AppSpacing.gapHorizontalSm,
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(investmentsProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome message
              Text('Welcome back,', style: Theme.of(context).textTheme.bodyLarge),
              Text(
                user?.displayName ?? 'Investor',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              AppSpacing.gapVerticalXl,

              // KPI Cards
              _buildKpiCards(context, ref, investmentsAsync),
              AppSpacing.gapVerticalXl,

              // Recent Investments
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Investments', style: Theme.of(context).textTheme.titleMedium),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.investments),
                    child: const Text('See All'),
                  ),
                ],
              ),
              AppSpacing.gapVerticalSm,
              _buildRecentInvestments(context, investmentsAsync),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('${AppRoutes.investments}/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add Investment'),
      ),
    );
  }

  Widget _buildKpiCards(BuildContext context, WidgetRef ref, AsyncValue investments) {
    final count = investments.whenData((d) => d).value?.length ?? 0;

    return Row(
      children: [
        Expanded(child: _KpiCard(title: 'Total Investments', value: count.toString(), icon: Icons.account_balance_wallet, color: AppColors.primary)),
        AppSpacing.gapHorizontalMd,
        Expanded(child: _KpiCard(title: 'Active', value: count.toString(), icon: Icons.trending_up, color: AppColors.success)),
      ],
    );
  }

  Widget _buildRecentInvestments(BuildContext context, AsyncValue investments) {
    return investments.when(
      data: (list) {
        if (list.isEmpty) {
          return Card(
            child: Padding(
              padding: AppSpacing.cardPadding,
              child: Column(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 48, color: Colors.grey[400]),
                  AppSpacing.gapVerticalMd,
                  const Text('No investments yet'),
                  AppSpacing.gapVerticalSm,
                  const Text('Tap the button below to add your first investment', textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }
        final recent = list.take(5).toList();
        return Column(
          children: recent.map((inv) => Card(
            child: ListTile(
              leading: CircleAvatar(backgroundColor: AppColors.getCategoryColor(inv.category), child: Text(inv.name[0].toUpperCase())),
              title: Text(inv.name),
              subtitle: Text(inv.category),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('${AppRoutes.investments}/${inv.id}'),
            ),
          )).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            AppSpacing.gapVerticalMd,
            Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

