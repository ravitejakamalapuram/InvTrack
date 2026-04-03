/// Analytics and trend providers for investments.
/// These provide derived data for charts and comparisons.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_stats_provider.dart';

// Re-export data classes
export 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart'
    show MonthlyCashFlowData, TypeDistribution, YoYComparison;

// ============ DISPLAY MODELS ============

/// Investment with its stats for display
class InvestmentWithStats {
  final InvestmentEntity investment;
  final InvestmentStats stats;

  InvestmentWithStats({required this.investment, required this.stats});
}

// ============ ANALYTICS PROVIDERS ============

/// Recently closed investments (derived from streams - auto-updates)
/// Only includes non-archived investments.
final recentlyClosedInvestmentsProvider =
    Provider<AsyncValue<List<InvestmentWithStats>>>((ref) {
      final investmentsAsync = ref.watch(activeInvestmentsProvider);
      final cashFlowsAsync = ref.watch(validCashFlowsProvider);

      return investmentsAsync.when(
        data: (investments) {
          final closed =
              investments
                  .where((i) => i.status == InvestmentStatus.closed)
                  .toList()
                ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

          final recentClosed = closed.take(3).toList();

          return cashFlowsAsync.when(
            data: (allCashFlows) {
              final result = <InvestmentWithStats>[];
              final recentClosedIds = recentClosed.map((e) => e.id).toSet();
              final cashFlowsByInv = <String, List<CashFlowEntity>>{};

              // Optimization: Single pass loop for all metrics replacing multiple sequential .where().toList() calls
              for (final cf in allCashFlows) {
                if (recentClosedIds.contains(cf.investmentId)) {
                  cashFlowsByInv.putIfAbsent(cf.investmentId, () => []).add(cf);
                }
              }

              for (final inv in recentClosed) {
                final invCashFlows = cashFlowsByInv[inv.id] ?? const [];
                final stats = invCashFlows.isEmpty
                    ? InvestmentStats.empty()
                    : calculateStats(invCashFlows);
                result.add(InvestmentWithStats(investment: inv, stats: stats));
              }
              return AsyncValue.data(result);
            },
            loading: () => const AsyncValue.loading(),
            error: (e, st) => AsyncValue.error(e, st),
          );
        },
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    });

/// Monthly cash flow trend (derived from streams - auto-updates)
final monthlyCashFlowTrendProvider =
    Provider<AsyncValue<List<MonthlyCashFlowData>>>((ref) {
      final cashFlowsAsync = ref.watch(validCashFlowsProvider);

      return cashFlowsAsync.when(
        data: (cashFlows) {
          // Get last 6 months
          final now = DateTime.now();
          final months = List.generate(6, (i) {
            final date = DateTime(now.year, now.month - i, 1);
            return DateTime(date.year, date.month, 1);
          }).reversed.toList();

          final result = <MonthlyCashFlowData>[];

          for (final month in months) {
            final nextMonth = DateTime(month.year, month.month + 1, 1);
            double inflows = 0;
            double outflows = 0;

            for (final cf in cashFlows) {
              if (cf.date.isAfter(month.subtract(const Duration(days: 1))) &&
                  cf.date.isBefore(nextMonth)) {
                if (cf.type.isOutflow) {
                  outflows += cf.amount;
                } else {
                  inflows += cf.amount;
                }
              }
            }

            result.add(
              MonthlyCashFlowData(
                month: month,
                inflows: inflows,
                outflows: outflows,
              ),
            );
          }

          return AsyncValue.data(result);
        },
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    });

/// Distribution by investment type (derived from streams - auto-updates)
/// Only includes non-archived investments.
final investmentTypeDistributionProvider =
    Provider<AsyncValue<List<TypeDistribution>>>((ref) {
      final investmentsAsync = ref.watch(activeInvestmentsProvider);
      final cashFlowsAsync = ref.watch(validCashFlowsProvider);

      return investmentsAsync.when(
        data: (investments) {
          return cashFlowsAsync.when(
            data: (allCashFlows) {
              // Optimization: Pre-calculate total invested per investment in O(C)
              // instead of O(I * C) by iterating through all cash flows once.
              final investedPerInvestment = <String, double>{};
              for (final cf in allCashFlows) {
                if (cf.type.isOutflow) {
                  investedPerInvestment[cf.investmentId] =
                      (investedPerInvestment[cf.investmentId] ?? 0.0) +
                      cf.amount;
                }
              }

              final distribution = <InvestmentType, TypeDistribution>{};

              for (final inv in investments) {
                final invested = investedPerInvestment[inv.id] ?? 0.0;

                if (distribution.containsKey(inv.type)) {
                  final existing = distribution[inv.type]!;
                  distribution[inv.type] = TypeDistribution(
                    type: inv.type,
                    totalInvested: existing.totalInvested + invested,
                    count: existing.count + 1,
                  );
                } else {
                  distribution[inv.type] = TypeDistribution(
                    type: inv.type,
                    totalInvested: invested,
                    count: 1,
                  );
                }
              }

              final result = distribution.values.toList()
                ..sort((a, b) => b.totalInvested.compareTo(a.totalInvested));

              return AsyncValue.data(result);
            },
            loading: () => const AsyncValue.loading(),
            error: (e, st) => AsyncValue.error(e, st),
          );
        },
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    });

/// Year over Year comparison (derived from streams - auto-updates)
final yoyComparisonProvider = Provider<AsyncValue<YoYComparison>>((ref) {
  final cashFlowsAsync = ref.watch(validCashFlowsProvider);

  return cashFlowsAsync.when(
    data: (cashFlows) {
      final now = DateTime.now();
      final thisYearStart = DateTime(now.year, 1, 1);
      final lastYearStart = DateTime(now.year - 1, 1, 1);
      final lastYearEnd = DateTime(now.year, 1, 1);

      double thisYearInvested = 0, thisYearReturned = 0;
      double lastYearInvested = 0, lastYearReturned = 0;

      for (final cf in cashFlows) {
        // This year
        if (!cf.date.isBefore(thisYearStart)) {
          if (cf.type.isOutflow) {
            thisYearInvested += cf.amount;
          } else {
            thisYearReturned += cf.amount;
          }
        }
        // Last year
        else if (!cf.date.isBefore(lastYearStart) &&
            cf.date.isBefore(lastYearEnd)) {
          if (cf.type.isOutflow) {
            lastYearInvested += cf.amount;
          } else {
            lastYearReturned += cf.amount;
          }
        }
      }

      return AsyncValue.data(
        YoYComparison(
          thisYearNet: thisYearReturned - thisYearInvested,
          lastYearNet: lastYearReturned - lastYearInvested,
          thisYearInvested: thisYearInvested,
          lastYearInvested: lastYearInvested,
          thisYearReturned: thisYearReturned,
          lastYearReturned: lastYearReturned,
        ),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});
