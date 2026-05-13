/// Report Builder Service
///
/// Core service that takes a ReportConfiguration and dynamically builds
/// a DynamicReportData by aggregating data from Riverpod providers.
/// This is the heart of the builder pattern.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/reports/domain/entities/report_configuration.dart';
import 'package:inv_tracker/features/reports/domain/entities/dynamic_report_data.dart';
import 'package:inv_tracker/features/reports/domain/entities/report_type.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';

/// Provider for ReportBuilderService
final reportBuilderServiceProvider = Provider<ReportBuilderService>((ref) {
  return ReportBuilderService(ref);
});

/// Service for building dynamic reports
class ReportBuilderService {
  final Ref _ref;

  ReportBuilderService(this._ref);

  /// Build a report from configuration
  Future<DynamicReportData> buildReport(ReportConfiguration config) async {
    switch (config.reportType) {
      case ReportType.weeklySummary:
        return _buildWeeklySummary(config);

      case ReportType.monthlyIncome:
        return _buildMonthlyIncome(config);

      case ReportType.fyReport:
        return _buildFyReport(config);

      case ReportType.performance:
        return _buildPerformance(config);

      case ReportType.goalProgress:
        return _buildGoalProgress(config);

      case ReportType.maturityCalendar:
        return _buildMaturityCalendar(config);

      case ReportType.actionRequired:
        return _buildActionRequired(config);

      case ReportType.portfolioHealth:
        return _buildPortfolioHealth(config);
    }
  }

  /// Build weekly summary report
  Future<DynamicReportData> _buildWeeklySummary(
    ReportConfiguration config,
  ) async {
    // Get data from providers using ref instead of container
    final cashFlowsAsync = _ref.read(validCashFlowsProvider);

    // FIX: Properly handle AsyncValue states - don't collapse loading to empty list
    // If still loading, the FutureProvider will keep waiting
    if (cashFlowsAsync.isLoading) {
      // Return a never-completing future to signal "still loading"
      // The FutureProvider wrapper will show loading state to UI
      return Completer<DynamicReportData>().future;
    }

    if (cashFlowsAsync.hasError) {
      throw cashFlowsAsync.error!;
    }

    final cashFlows = cashFlowsAsync.value ?? [];

    // Apply date range filter
    final filteredCashFlows = config.dateRange != null
        ? applyDateRangeFilter(cashFlows, config.dateRange!)
        : cashFlows;

    // Build sections
    final sections = <ReportSection>[];

    // KPI Grid section
    final totalInvested = _calculateTotalByType(
      filteredCashFlows,
      CashFlowType.invest,
    );
    final totalReturns = _calculateTotalByType(
      filteredCashFlows,
      CashFlowType.returnFlow,
    );
    final totalIncome = _calculateTotalByType(
      filteredCashFlows,
      CashFlowType.income,
    );

    sections.add(
      ReportSection(
        type: ReportSectionType.kpiGrid,
        title: 'Key Metrics',
        data: [
          KpiData(
            label: 'Total Invested',
            value: totalInvested.toStringAsFixed(2),
            icon: 'trending_down',
          ),
          KpiData(
            label: 'Total Returns',
            value: totalReturns.toStringAsFixed(2),
            icon: 'trending_up',
          ),
          KpiData(
            label: 'Net Position',
            value: (totalReturns - totalInvested).toStringAsFixed(2),
            icon: 'arrow_upward',
          ),
          KpiData(
            label: 'Total Income',
            value: totalIncome.toStringAsFixed(2),
            icon: 'payments',
          ),
        ],
      ),
    );

    return DynamicReportData(
      reportType: ReportType.weeklySummary,
      title: 'Weekly Summary',
      sections: sections,
      configuration: config,
      dateRange: config.dateRange,
      hasData: filteredCashFlows.isNotEmpty,
    );
  }

  /// Build monthly income report
  Future<DynamicReportData> _buildMonthlyIncome(
    ReportConfiguration config,
  ) async {
    // Delegate to existing MonthlyIncomeService for now
    // This will be refactored to use DynamicReportData format
    return DynamicReportData(
      reportType: ReportType.monthlyIncome,
      title: 'Monthly Income',
      sections: [],
      configuration: config,
      dateRange: config.dateRange,
    );
  }

  /// Build FY report
  Future<DynamicReportData> _buildFyReport(ReportConfiguration config) async {
    return DynamicReportData(
      reportType: ReportType.fyReport,
      title: 'Financial Year Report',
      sections: [],
      configuration: config,
      dateRange: config.dateRange,
    );
  }

  // Placeholder implementations for other report types
  Future<DynamicReportData> _buildPerformance(
    ReportConfiguration config,
  ) async {
    return DynamicReportData(
      reportType: ReportType.performance,
      title: 'Performance Report',
      sections: [],
      configuration: config,
    );
  }

  Future<DynamicReportData> _buildGoalProgress(
    ReportConfiguration config,
  ) async {
    return DynamicReportData(
      reportType: ReportType.goalProgress,
      title: 'Goal Progress',
      sections: [],
      configuration: config,
      filteredGoalId: config.goalId,
    );
  }

  Future<DynamicReportData> _buildMaturityCalendar(
    ReportConfiguration config,
  ) async {
    return DynamicReportData(
      reportType: ReportType.maturityCalendar,
      title: 'Maturity Calendar',
      sections: [],
      configuration: config,
      filteredInvestmentId: config.investmentId,
    );
  }

  Future<DynamicReportData> _buildActionRequired(
    ReportConfiguration config,
  ) async {
    return DynamicReportData(
      reportType: ReportType.actionRequired,
      title: 'Action Required',
      sections: [],
      configuration: config,
    );
  }

  Future<DynamicReportData> _buildPortfolioHealth(
    ReportConfiguration config,
  ) async {
    return DynamicReportData(
      reportType: ReportType.portfolioHealth,
      title: 'Portfolio Health',
      sections: [],
      configuration: config,
    );
  }

  // Helper methods

  /// Apply date range filter to cashflows
  List<CashFlowEntity> applyDateRangeFilter(
    List<CashFlowEntity> cashFlows,
    DateRangeFilter dateRange,
  ) {
    return cashFlows.where((cf) => dateRange.contains(cf.date)).toList();
  }

  /// Filter investments by ID
  List<InvestmentEntity> filterByInvestmentId(
    List<InvestmentEntity> investments,
    String investmentId,
  ) {
    return investments.where((inv) => inv.id == investmentId).toList();
  }

  /// Calculate total amount for specific cashflow type
  double _calculateTotalByType(
    List<CashFlowEntity> cashFlows,
    CashFlowType type,
  ) {
    // Optimization: Replace .where().fold() with standard loop to avoid closure overhead
    double sum = 0.0;
    for (final cf in cashFlows) {
      if (cf.type == type) {
        sum += cf.amount;
      }
    }
    return sum;
  }
}
