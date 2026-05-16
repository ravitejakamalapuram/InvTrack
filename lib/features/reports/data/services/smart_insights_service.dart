/// Smart Insights Service
///
/// Generates auto-insights based on user's investment data
library;

import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/reports/domain/entities/smart_insight.dart';

/// Service to generate smart insights from user data
class SmartInsightsService {
  /// Generate all applicable insights for the user
  List<SmartInsight> generateInsights({
    required List<InvestmentEntity> investments,
    required List<CashFlowEntity> cashFlows,
    required List<GoalEntity> goals,
    required String currencySymbol,
    required String locale,
  }) {
    final insights = <SmartInsight>[];
    final now = DateTime.now();

    // 1. Weekly Summary
    final weeklyInsight = _generateWeeklySummary(cashFlows, now, currencySymbol, locale);
    if (weeklyInsight != null) insights.add(weeklyInsight);

    // 2. Monthly Summary
    final monthlyInsight = _generateMonthlySummary(cashFlows, now, currencySymbol, locale);
    if (monthlyInsight != null) insights.add(monthlyInsight);
    
    // 3. Upcoming Maturities
    final maturityInsights = _generateMaturityAlerts(investments, now);
    insights.addAll(maturityInsights);
    
    // 4. Declining Investments
    final decliningInsights = _generateDecliningAlerts(investments, cashFlows);
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
  ) {
    final weekStart = _getWeekStart(now);
    final weekEnd = _getWeekEnd(now);
    final weekStartBound = weekStart.subtract(const Duration(days: 1));
    final weekEndBound = weekEnd.add(const Duration(days: 1));

    // Optimization: Single pass loop for metrics replacing sequential .where().toList() and .fold() calls
    double netInvested = 0;
    double returns = 0;
    bool hasCashFlows = false;

    for (final cf in cashFlows) {
      if (cf.date.isAfter(weekStartBound) && cf.date.isBefore(weekEndBound)) {
        hasCashFlows = true;
        if (cf.type == CashFlowType.invest) {
          netInvested += cf.amount;
        } else if (cf.type == CashFlowType.returnFlow) {
          returns += cf.amount;
        }
      }
    }

    if (!hasCashFlows || (netInvested == 0 && returns == 0)) return null;

    // Format amounts using locale-aware currency formatting
    final netInvestedStr = formatCompactCurrency(netInvested, symbol: currencySymbol, locale: locale);
    final returnsStr = returns > 0
        ? '+${formatCompactCurrency(returns, symbol: currencySymbol, locale: locale)}'
        : formatCompactCurrency(0, symbol: currencySymbol, locale: locale);

    return SmartInsight(
      type: InsightType.weeklySummary,
      priority: InsightPriority.info,
      title: 'This Week', // TODO: Localize using AppLocalizations
      subtitle: 'Net invested: $netInvestedStr', // TODO: Localize using AppLocalizations
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
  ) {
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final monthStartBound = monthStart.subtract(const Duration(days: 1));
    final monthEndBound = monthEnd.add(const Duration(days: 1));

    // Optimization: Single pass loop for metrics replacing sequential .where().toList() and .fold() calls
    double income = 0;
    int sourcesCount = 0;
    bool hasCashFlows = false;

    for (final cf in cashFlows) {
      if (cf.date.isAfter(monthStartBound) && cf.date.isBefore(monthEndBound)) {
        hasCashFlows = true;
        sourcesCount++;
        if (cf.type == CashFlowType.income) {
          income += cf.amount;
        }
      }
    }

    if (!hasCashFlows || income == 0) return null;

    // Format income using locale-aware currency formatting
    final incomeStr = formatCompactCurrency(income, symbol: currencySymbol, locale: locale);

    return SmartInsight(
      type: InsightType.monthlySummary,
      priority: InsightPriority.info,
      title: 'This Month', // TODO: Localize using AppLocalizations
      subtitle: 'Income received', // TODO: Localize using AppLocalizations
      value: incomeStr,
      secondaryValue: '$sourcesCount sources', // TODO: Localize using AppLocalizations
      icon: 'trending_up',
      generatedAt: now,
    );
  }

  /// Generate maturity alerts
  List<SmartInsight> _generateMaturityAlerts(List<InvestmentEntity> investments, DateTime now) {
    final insights = <SmartInsight>[];
    final next30Days = now.add(const Duration(days: 30));

    // Optimization: Single pass loop replacing .where().toList() to avoid closure and intermediate list allocation
    int count = 0;
    DateTime? firstMaturityDate;

    for (final inv in investments) {
      if (inv.maturityDate != null &&
          inv.maturityDate!.isAfter(now) &&
          inv.maturityDate!.isBefore(next30Days)) {
        count++;
        // Keep track of the nearest maturity date found for display
        if (firstMaturityDate == null || inv.maturityDate!.isBefore(firstMaturityDate)) {
          firstMaturityDate = inv.maturityDate;
        }
      }
    }

    if (count == 0 || firstMaturityDate == null) return insights;

    // Use count for now (accurate amount would require cash flow aggregation)
    final days = firstMaturityDate.difference(now).inDays;

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
  List<SmartInsight> _generateDecliningAlerts(
    List<InvestmentEntity> investments,
    List<CashFlowEntity> cashFlows,
  ) {
    // TODO: Implement declining investment detection
    return [];
  }
  
  /// Generate goal progress insights
  List<SmartInsight> _generateGoalProgressInsights(List<GoalEntity> goals) {
    // TODO: Implement goal progress insights
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
