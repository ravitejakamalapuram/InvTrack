/// Report Builder Service
///
/// Core service that takes a ReportConfiguration and dynamically builds
/// a DynamicReportData by aggregating data from Riverpod providers.
/// This is the heart of the builder pattern.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/reports/domain/entities/report_configuration.dart';
import 'package:inv_tracker/features/reports/domain/entities/dynamic_report_data.dart';
import 'package:inv_tracker/features/reports/domain/entities/report_type.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';

/// Provider for ReportBuilderService
final reportBuilderServiceProvider = Provider<ReportBuilderService>((ref) {
  return ReportBuilderService();
});

/// Service for building dynamic reports
class ReportBuilderService {
  /// Build a report from configuration
  Future<DynamicReportData> buildReport(
    ReportConfiguration config,
    ProviderContainer container,
  ) async {
    switch (config.reportType) {
      case ReportType.weeklySummary:
        return _buildWeeklySummary(config, container);

      case ReportType.monthlyIncome:
        return _buildMonthlyIncome(config, container);

      case ReportType.fyReport:
        return _buildFyReport(config, container);

      case ReportType.performance:
        return _buildPerformance(config, container);

      case ReportType.goalProgress:
        return _buildGoalProgress(config, container);

      case ReportType.maturityCalendar:
        return _buildMaturityCalendar(config, container);

      case ReportType.actionRequired:
        return _buildActionRequired(config, container);

      case ReportType.portfolioHealth:
        return _buildPortfolioHealth(config, container);
    }
  }

  /// Build weekly summary report
  Future<DynamicReportData> _buildWeeklySummary(
    ReportConfiguration config,
    ProviderContainer container,
  ) async {
    // Get data from providers
    // Read the AsyncValue and extract data properly
    final cashFlowsAsync = container.read(validCashFlowsProvider);

    final cashFlows = await cashFlowsAsync.when(
      data: (data) => Future.value(data),
      loading: () => Future.value(<CashFlowEntity>[]),
      error: (e, st) => throw e,
    );

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
    ProviderContainer container,
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
  Future<DynamicReportData> _buildFyReport(
    ReportConfiguration config,
    ProviderContainer container,
  ) async {
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
    ProviderContainer container,
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
    ProviderContainer container,
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
    ProviderContainer container,
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
    ProviderContainer container,
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
    ProviderContainer container,
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
    return cashFlows
        .where((cf) => dateRange.contains(cf.date))
        .toList();
  }

  /// Filter investments by ID
  List<InvestmentEntity> filterByInvestmentId(
    List<InvestmentEntity> investments,
    String investmentId,
  ) {
    return investments
        .where((inv) => inv.id == investmentId)
        .toList();
  }

  /// Calculate total amount for specific cashflow type
  double _calculateTotalByType(
    List<CashFlowEntity> cashFlows,
    CashFlowType type,
  ) {
    return cashFlows
        .where((cf) => cf.type == type)
        .fold(0.0, (sum, cf) => sum + cf.amount);
  }
}

