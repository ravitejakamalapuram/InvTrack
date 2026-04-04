/// Badge showing portfolio health score improvement/decline
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/providers/portfolio_health_provider.dart';

/// Badge showing score change (e.g., "+5 points this week")
class ScoreImprovementBadge extends ConsumerWidget {
  const ScoreImprovementBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historicalAsync = ref.watch(historicalHealthScoresProvider);

    return historicalAsync.when(
      data: (snapshots) {
        if (snapshots.length < 2) {
          return const SizedBox.shrink(); // Need at least 2 data points
        }

        // Compare current score vs last week
        final current = snapshots.last.overallScore;
        final previous = snapshots[snapshots.length - 2].overallScore;
        final delta = current - previous;

        if (delta.abs() < 1.0) {
          return const SizedBox.shrink(); // No significant change
        }

        return _buildBadge(delta);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildBadge(double delta) {
    final isPositive = delta > 0;
    final color = isPositive ? Colors.green : Colors.red;
    final icon = isPositive ? Icons.trending_up : Icons.trending_down;
    final text = isPositive
        ? '+${delta.round()} points this week'
        : '${delta.round()} points this week';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
