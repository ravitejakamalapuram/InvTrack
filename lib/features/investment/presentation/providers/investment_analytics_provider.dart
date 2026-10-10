/// Analytics and trend providers for investments.
/// These provide derived data for charts and comparisons, in the base
/// currency: they read the converted snapshot, never raw cash-flow amounts.
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

/// When [investment] was closed. Editing, archiving or unarchiving bumps
/// `updatedAt`, so it only stands in for items without a closing date.
DateTime _closedOn(InvestmentEntity investment) =>
    investment.closedAt ?? investment.updatedAt;

/// Recently closed investments (derived from streams - auto-updates)
/// Only includes non-archived investments.
final recentlyClosedInvestmentsProvider =
    Provider<AsyncValue<List<InvestmentWithStats>>>((ref) {
      final investmentsAsync = ref.watch(activeInvestmentsProvider);
      final cashFlowsAsync = ref.watch(convertedCashFlowsProvider);

      return investmentsAsync.when(
        data: (investments) {
          // Optimization: Single pass loop for all metrics replacing multiple sequential .where().toList() calls
          final recentClosed = <InvestmentEntity>[];
          for (final i in investments) {
            if (i.status == InvestmentStatus.closed) {
              // Maintain top 3 most recently closed
              int insertIdx = -1;
              for (int j = 0; j < recentClosed.length; j++) {
                if (_closedOn(i).isAfter(_closedOn(recentClosed[j]))) {
                  insertIdx = j;
                  break;
                }
              }

              if (insertIdx != -1) {
                recentClosed.insert(insertIdx, i);
              } else if (recentClosed.length < 3) {
                recentClosed.add(i);
              }

              if (recentClosed.length > 3) {
                recentClosed.removeLast();
              }
            }
          }

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
      final cashFlowsAsync = ref.watch(convertedCashFlowsProvider);

      return cashFlowsAsync.when(
        data: (cashFlows) {
          // Get last 6 months
          final now = DateTime.now();
          final months = List.generate(6, (i) {
            final date = DateTime(now.year, now.month - i, 1);
            return DateTime(date.year, date.month, 1);
          }).reversed.toList();

          final result = <MonthlyCashFlowData>[];

          // Optimization: Group cashflows by year-month to avoid O(D*N) performance bottleneck
          final cashFlowsByMonth = <String, List<CashFlowEntity>>{};
          for (final cf in cashFlows) {
            final key = '${cf.date.year}-${cf.date.month}';
            (cashFlowsByMonth[key] ??= []).add(cf);
          }

          for (final month in months) {
            double inflows = 0;
            double outflows = 0;

            final key = '${month.year}-${month.month}';
            final monthlyCashFlows = cashFlowsByMonth[key] ?? const [];

            for (final cf in monthlyCashFlows) {
              if (cf.type.isOutflow) {
                outflows += cf.amount;
              } else {
                inflows += cf.amount;
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
      final cashFlowsAsync = ref.watch(convertedCashFlowsProvider);

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

/// Year over Year: the financial year to date against the same days of the
/// previous financial year, in the base currency (derived from streams -
/// auto-updates).
final yoyComparisonProvider = Provider<AsyncValue<YoYComparison>>((ref) {
  final cashFlowsAsync = ref.watch(convertedCashFlowsProvider);
  final today = ref.watch(valuationDateProvider);

  return cashFlowsAsync.when(
    data: (cashFlows) => AsyncValue.data(
      YoYComparison.financialYearToDate(cashFlows, today: today),
    ),
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});
