import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:inv_tracker/features/sync/presentation/widgets/sync_status_icon.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(dashboardMetricsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard', style: AppTypography.h3),
        actions: const [
          SyncStatusIcon(),
          SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total Value Card
            // The original _buildSummaryCard is replaced by _buildMetricCard call
            _buildMetricCard(
              'Total Portfolio Value',
              metricsAsync.when(
                data: (m) => NumberFormat.currency(symbol: '\$').format(m.totalValue),
                loading: () => '...',
                error: (_, __) => 'Error',
              ),
              metricsAsync.when(
                data: (m) => '${m.dayChange >= 0 ? '+' : ''}${NumberFormat.currency(symbol: '\$').format(m.dayChange)} (${m.dayChangePercent.toStringAsFixed(2)}%)',
                loading: () => '...',
                error: (_, __) => '',
              ),
              metricsAsync.when(
                data: (m) => m.dayChange >= 0,
                loading: () => true,
                error: (_, __) => false,
              ),
            ),
            const SizedBox(height: 24),
            
            Text('Portfolio Performance', style: AppTypography.h3),
            const SizedBox(height: 16),
            Container(
              height: 250,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.neutral400Light.withOpacity(0.1)),
              ),
              child: metricsAsync.when(
                data: (m) {
                  if (m.historicalData.isEmpty) {
                    return const Center(child: Text('No historical data available'));
                  }
                  final spots = m.historicalData.entries.map((e) {
                    return FlSpot(e.key.millisecondsSinceEpoch.toDouble(), e.value);
                  }).toList();
                  
                  // Sort spots by X
                  spots.sort((a, b) => a.x.compareTo(b.x));

                  final minX = spots.first.x;
                  final maxX = spots.last.x;
                  final minY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
                  final maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
                  
                  // Add some padding to Y
                  final yPadding = (maxY - minY) * 0.1;

                  return PortfolioValueChart(
                    spots: spots,
                    minX: minX,
                    maxX: maxX,
                    minY: minY - yPadding,
                    maxY: maxY + yPadding,
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
            
            const SizedBox(height: 24),
            Text('Asset Allocation', style: AppTypography.h3),
            const SizedBox(height: 16),
            Container(
              height: 250,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.neutral400Light.withOpacity(0.1)),
              ),
              child: metricsAsync.when(
                data: (m) => AssetAllocationChart(allocation: m.allocation),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, String change, bool isPositive) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryLight.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.body.copyWith(color: Colors.white.withOpacity(0.8)),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.display.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      change,
                      style: AppTypography.caption.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
