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
    final weeklyInsight = _generateWeeklySummary(cashFlows, now, currencySymbol, locale, l10n);
    if (weeklyInsight != null) insights.add(weeklyInsight);

    // 2. Monthly Summary
    final monthlyInsight = _generateMonthlySummary(cashFlows, now, currencySymbol, locale, l10n);
    if (monthlyInsight != null) insights.add(monthlyInsight);
    
    // 3. Upcoming Maturities
    final maturityInsights = _generateMaturityAlerts(investments, now);
    insights.addAll(maturityInsights);
    
    // 4. Declining Investments
    final decliningInsights = _generateDecliningAlerts(investments, cashFlows, l10n);
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

    final weekCashFlows = cashFlows.where((cf) =>
      cf.date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
      cf.date.isBefore(weekEnd.add(const Duration(days: 1)))
    ).toList();

    if (weekCashFlows.isEmpty) return null;

    final netInvested = weekCashFlows
        .where((cf) => cf.type == CashFlowType.invest)
        .fold<double>(0, (sum, cf) => sum + cf.amount);

    final returns = weekCashFlows
        .where((cf) => cf.type == CashFlowType.returnFlow)
        .fold<double>(0, (sum, cf) => sum + cf.amount);

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

    final monthCashFlows = cashFlows.where((cf) =>
      cf.date.isAfter(monthStart.subtract(const Duration(days: 1))) &&
      cf.date.isBefore(monthEnd.add(const Duration(days: 1)))
    ).toList();

    if (monthCashFlows.isEmpty) return null;

    final income = monthCashFlows
        .where((cf) => cf.type == CashFlowType.income)
        .fold<double>(0, (sum, cf) => sum + cf.amount);

    if (income == 0) return null;

    // Format income using locale-aware currency formatting
    final incomeStr = formatCompactCurrency(income, symbol: currencySymbol, locale: locale);

    return SmartInsight(
      type: InsightType.monthlySummary,
      priority: InsightPriority.info,
      title: l10n.thisMonth,
      subtitle: l10n.incomeReceived,
      value: incomeStr,
      secondaryValue: l10n.sourcesCount(monthCashFlows.length),
      icon: 'trending_up',
      generatedAt: now,
    );
  }

  /// Generate maturity alerts
  List<SmartInsight> _generateMaturityAlerts(List<InvestmentEntity> investments, DateTime now) {
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

    insights.add(SmartInsight(
      type: InsightType.upcomingMaturity,
      priority: days <= 7 ? InsightPriority.urgent : InsightPriority.warning,
      title: 'Upcoming Maturity',
      subtitle: '$count investment${count > 1 ? 's' : ''} maturing',
      value: 'in $days days',
      icon: 'schedule',
      generatedAt: now,
    ));

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
    final now = DateTime.now();
    final monthAgo = now.subtract(const Duration(days: 30));

    for (final investment in investments) {
      // Get all cash flows for this investment
      final investmentCashFlows = cashFlows
          .where((cf) => cf.investmentId == investment.id)
          .toList();

      if (investmentCashFlows.isEmpty) continue;

      // Calculate current value (net cash flow)
      final totalInvested = investmentCashFlows
          .where((cf) => cf.type == CashFlowType.invest || cf.type == CashFlowType.fee)
          .fold<double>(0, (sum, cf) => sum + cf.amount);

      final totalReturned = investmentCashFlows
          .where((cf) => cf.type == CashFlowType.returnFlow || cf.type == CashFlowType.income)
          .fold<double>(0, (sum, cf) => sum + cf.amount);

      final currentValue = totalReturned - totalInvested;
      if (totalInvested == 0) continue;

      // Calculate value a month ago
      final oldCashFlows = investmentCashFlows
          .where((cf) => cf.date.isBefore(monthAgo))
          .toList();

      final oldInvested = oldCashFlows
          .where((cf) => cf.type == CashFlowType.invest || cf.type == CashFlowType.fee)
          .fold<double>(0, (sum, cf) => sum + cf.amount);

      final oldReturned = oldCashFlows
          .where((cf) => cf.type == CashFlowType.returnFlow || cf.type == CashFlowType.income)
          .fold<double>(0, (sum, cf) => sum + cf.amount);

      final oldValue = oldReturned - oldInvested;
      if (oldInvested == 0) continue;

      // Calculate decline as change in return percentage
      final oldReturnPct = (oldValue / oldInvested) * 100;
      final currentReturnPct = (currentValue / totalInvested) * 100;
      final decline = currentReturnPct - oldReturnPct;

      // Alert if decline > 10% (significant drop in returns)
      if (decline < -10) {
        insights.add(SmartInsight(
          type: InsightType.decliningInvestment,
          priority: decline < -20 ? InsightPriority.urgent : InsightPriority.warning,
          title: investment.name,
          subtitle: l10n.decliningInValue,
          value: '${decline.toStringAsFixed(1)}%',
          icon: 'trending_down',
          generatedAt: now,
        ));
      }
    }

    // Return top 3 most declining investments
    insights.sort((a, b) {
      final aValue = double.tryParse(a.value.replaceAll('%', '')) ?? 0;
      final bValue = double.tryParse(b.value.replaceAll('%', '')) ?? 0;
      return aValue.compareTo(bValue);
    });

    return insights.take(3).toList();
  }
  
  /// Generate goal progress insights
  /// Highlights goals nearing completion or significant milestones
  ///
  /// Note: This is a simplified implementation that doesn't calculate actual progress.
  /// Full implementation would require investment and cash flow data to calculate
  /// current vs target amounts using GoalProgressCalculator.
  /// For now, returns empty list - will be implemented in future iteration.
  List<SmartInsight> _generateGoalProgressInsights(List<GoalEntity> goals) {
    // TODO: Implement full goal progress calculation
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
