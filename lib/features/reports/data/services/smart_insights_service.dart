/// Smart Insights Service
///
/// Generates auto-insights based on user's investment data
library;

import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/reports/domain/entities/smart_insight.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Service to generate smart insights from user data
class SmartInsightsService {
  /// Generate all applicable insights for the user
  List<SmartInsight> generateInsights({
    required List<InvestmentEntity> investments,
    required List<CashFlowEntity> cashFlows,
    required List<GoalEntity> goals,
    required String currencySymbol,
    required String locale,
    required AppLocalizations l10n,
  }) {
    final insights = <SmartInsight>[];
    final now = DateTime.now();

    // 1. Weekly Summary
    final weeklyInsight = _generateWeeklySummary(
      cashFlows,
      now,
      currencySymbol,
      locale,
      l10n,
    );
    if (weeklyInsight != null) insights.add(weeklyInsight);

    // 2. Monthly Summary
    final monthlyInsight = _generateMonthlySummary(
      cashFlows,
      now,
      currencySymbol,
      locale,
      l10n,
    );
    if (monthlyInsight != null) insights.add(monthlyInsight);

    // 3. Upcoming Maturities
    final maturityInsights = _generateMaturityAlerts(investments, now);
    insights.addAll(maturityInsights);

    // 4. Declining Investments
    final decliningInsights = _generateDecliningAlerts(
      investments,
      cashFlows,
      l10n,
    );
    insights.addAll(decliningInsights);

    // 5. Goal Progress
    final goalInsights = _generateGoalProgressInsights(goals);
    insights.addAll(goalInsights);

    return insights;
  }

  /// Generate weekly summary insight
  SmartInsight? _generateWeeklySummary(
    List<CashFlowEntity> cashFlows,
    DateTime now,
    String currencySymbol,
    String locale,
    AppLocalizations l10n,
  ) {
    final weekStart = _getWeekStart(now);
    final weekEnd = _getWeekEnd(now);

    // Optimization: Hoist invariant date boundary calculations outside the loop
    final startBoundary = weekStart.subtract(const Duration(days: 1));
    final endBoundary = weekEnd.add(const Duration(days: 1));

    // Optimization: Single pass loop for all metrics replacing multiple sequential .where().toList() calls
    double netInvested = 0;
    double returns = 0;
    bool hasWeekCashFlows = false;

    for (final cf in cashFlows) {
      if (cf.date.isAfter(startBoundary) && cf.date.isBefore(endBoundary)) {
        hasWeekCashFlows = true;
        if (cf.type == CashFlowType.invest) {
          netInvested += cf.amount;
        } else if (cf.type == CashFlowType.returnFlow) {
          returns += cf.amount;
        }
      }
    }

    if (!hasWeekCashFlows) return null;

    if (netInvested == 0 && returns == 0) return null;

    // Format returns using locale-aware currency formatting
    final returnsStr = returns > 0
        ? '+${formatCompactCurrency(returns, symbol: currencySymbol, locale: locale)}'
        : formatCompactCurrency(0, symbol: currencySymbol, locale: locale);

    return SmartInsight(
      type: InsightType.weeklySummary,
      priority: InsightPriority.info,
      title: l10n.thisWeek,
      subtitle: l10n.netInvestedThisWeek,
      value: returnsStr,
      icon: 'calendar_today',
      generatedAt: now,
    );
  }

  /// Generate monthly summary insight
  SmartInsight? _generateMonthlySummary(
    List<CashFlowEntity> cashFlows,
    DateTime now,
    String currencySymbol,
    String locale,
    AppLocalizations l10n,
  ) {
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    // Optimization: Hoist invariant date boundary calculations outside the loop
    final startBoundary = monthStart.subtract(const Duration(days: 1));
    final endBoundary = monthEnd.add(const Duration(days: 1));

    // Optimization: Single pass loop for all metrics replacing multiple sequential .where().toList() calls
    double income = 0;
    int sourcesCount = 0;
    bool hasMonthCashFlows = false;

    for (final cf in cashFlows) {
      if (cf.date.isAfter(startBoundary) && cf.date.isBefore(endBoundary)) {
        hasMonthCashFlows = true;
        sourcesCount++;
        if (cf.type == CashFlowType.income) {
          income += cf.amount;
        }
      }
    }

    if (!hasMonthCashFlows) return null;

    if (income == 0) return null;

    // Format income using locale-aware currency formatting
    final incomeStr = formatCompactCurrency(
      income,
      symbol: currencySymbol,
      locale: locale,
    );

    return SmartInsight(
      type: InsightType.monthlySummary,
      priority: InsightPriority.info,
      title: l10n.thisMonth,
      subtitle: l10n.incomeReceived,
      value: incomeStr,
      secondaryValue: l10n.sourcesCount(sourcesCount),
      icon: 'trending_up',
      generatedAt: now,
    );
  }

  /// Generate maturity alerts
  List<SmartInsight> _generateMaturityAlerts(
    List<InvestmentEntity> investments,
    DateTime now,
  ) {
    final insights = <SmartInsight>[];
    final next30Days = now.add(const Duration(days: 30));

    final maturingSoon = investments.where((inv) {
      return inv.maturityDate != null &&
          inv.maturityDate!.isAfter(now) &&
          inv.maturityDate!.isBefore(next30Days);
    }).toList();

    if (maturingSoon.isEmpty) return insights;

    // Use count for now (accurate amount would require cash flow aggregation)
    final count = maturingSoon.length;
    final days = maturingSoon.first.maturityDate!.difference(now).inDays;

    insights.add(
      SmartInsight(
        type: InsightType.upcomingMaturity,
        priority: days <= 7 ? InsightPriority.urgent : InsightPriority.warning,
        title: 'Upcoming Maturity',
        subtitle: '$count investment${count > 1 ? 's' : ''} maturing',
        value: 'in $days days',
        icon: 'schedule',
        generatedAt: now,
      ),
    );

    return insights;
  }

  /// Generate declining investment alerts
  /// Detects investments with significant value decline over the past month
  List<SmartInsight> _generateDecliningAlerts(
    List<InvestmentEntity> investments,
    List<CashFlowEntity> cashFlows,
    AppLocalizations l10n,
  ) {
    final insights = <SmartInsight>[];
    if (investments.isEmpty || cashFlows.isEmpty) return insights;

    final now = DateTime.now();
    final monthAgo = now.subtract(const Duration(days: 30));

    // Optimization: Group cashflows by investmentId in a single pass (O(N))
    final Map<String, List<CashFlowEntity>> cashFlowsByInvestment = {};
    for (final cf in cashFlows) {
      (cashFlowsByInvestment[cf.investmentId] ??= []).add(cf);
    }

    for (final investment in investments) {
      // O(1) map lookup instead of O(N) .where() scan
      final investmentCashFlows = cashFlowsByInvestment[investment.id];
      if (investmentCashFlows == null || investmentCashFlows.isEmpty) continue;

      // Optimization: Single pass loop replacing multiple sequential .where() and .fold() calls
      double totalInvested = 0;
      double totalReturned = 0;
      double oldInvested = 0;
      double oldReturned = 0;

      for (final cf in investmentCashFlows) {
        final isInvestOrFee =
            cf.type == CashFlowType.invest || cf.type == CashFlowType.fee;
        final isReturnOrIncome =
            cf.type == CashFlowType.returnFlow ||
            cf.type == CashFlowType.income;

        if (isInvestOrFee) {
          totalInvested += cf.amount;
          if (cf.date.isBefore(monthAgo)) {
            oldInvested += cf.amount;
          }
        } else if (isReturnOrIncome) {
          totalReturned += cf.amount;
          if (cf.date.isBefore(monthAgo)) {
            oldReturned += cf.amount;
          }
        }
      }

      if (totalInvested == 0 || oldInvested == 0) continue;

      final currentValue = totalReturned - totalInvested;
      final oldValue = oldReturned - oldInvested;

      // Calculate decline as change in return percentage
      final oldReturnPct = (oldValue / oldInvested) * 100;
      final currentReturnPct = (currentValue / totalInvested) * 100;
      final decline = currentReturnPct - oldReturnPct;

      // Alert if decline > 10% (significant drop in returns)
      if (decline < -10) {
        insights.add(
          SmartInsight(
            type: InsightType.decliningInvestment,
            priority: decline < -20
                ? InsightPriority.urgent
                : InsightPriority.warning,
            title: investment.name,
            subtitle: l10n.decliningInValue,
            value: '${decline.toStringAsFixed(1)}%',
            icon: 'trending_down',
            generatedAt: now,
          ),
        );
      }
    }

    // ⚡ Bolt: Replace O(N log N) sorting with O(N) bounded linear scan
    // Return top 3 most declining investments (lowest percentages)
    final topDeclining = <SmartInsight>[];
    for (final insight in insights) {
      int insertIdx = 0;
      final insightValue =
          double.tryParse(insight.value.replaceAll('%', '')) ?? 0;

      while (insertIdx < topDeclining.length) {
        final currentTopValue =
            double.tryParse(
              topDeclining[insertIdx].value.replaceAll('%', ''),
            ) ??
            0;
        if (insightValue <= currentTopValue) {
          break;
        }
        insertIdx++;
      }

      if (insertIdx < 3) {
        topDeclining.insert(insertIdx, insight);
        if (topDeclining.length > 3) {
          topDeclining.removeLast();
        }
      }
    }

    return topDeclining;
  }

  /// Generate goal progress insights
  /// Highlights goals nearing completion or significant milestones
  ///
  /// Note: This is a simplified implementation that doesn't calculate actual progress.
  /// Full implementation would require investment and cash flow data to calculate
  /// current vs target amounts using GoalProgressCalculator.
  /// For now, returns empty list - will be implemented in future iteration.
  List<SmartInsight> _generateGoalProgressInsights(List<GoalEntity> goals) {
    // TODO(@raviteja, 2026-05-24, #SmartInsights-GoalProgress): Implement full goal progress calculation
    // Requires:
    // 1. Investment and cash flow data to calculate current amount
    // 2. GoalProgressCalculator.calculate() to get actual progress
    // 3. Multi-currency conversion for accurate percentages
    //
    // For now, return empty list to avoid compilation errors
    return [];
  }

  // Helper methods
  static DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday;
    final daysToSubtract = weekday - 1;
    final monday = date.subtract(Duration(days: daysToSubtract));
    return DateTime(monday.year, monday.month, monday.day);
  }

  static DateTime _getWeekEnd(DateTime date) {
    final weekday = date.weekday;
    final daysToAdd = 7 - weekday;
    final sunday = date.add(Duration(days: daysToAdd));
    return DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59, 999);
  }
}
