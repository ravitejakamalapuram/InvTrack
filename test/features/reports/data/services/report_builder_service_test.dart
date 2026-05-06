import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/reports/data/services/report_builder_service.dart';
import 'package:inv_tracker/features/reports/domain/entities/report_configuration.dart';
import 'package:inv_tracker/features/reports/domain/entities/report_type.dart';
import 'package:inv_tracker/features/reports/domain/entities/dynamic_report_data.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';

void main() {
  group('ReportBuilderService', () {
    late ProviderContainer container;
    late ReportBuilderService service;

    setUp(() {
      final testInvestments = [
        InvestmentEntity(
          id: 'inv1',
          name: 'Test Investment 1',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
          maturityDate: DateTime(2024, 12, 31),
          currency: 'USD',
        ),
        InvestmentEntity(
          id: 'inv2',
          name: 'Test Investment 2',
          type: InvestmentType.bonds,
          status: InvestmentStatus.open,
          createdAt: DateTime(2024, 1, 15),
          updatedAt: DateTime(2024, 1, 15),
          currency: 'USD',
        ),
      ];

      final testCashFlows = [
        CashFlowEntity(
          id: 'cf1',
          investmentId: 'inv1',
          date: DateTime(2024, 1, 1),
          type: CashFlowType.invest,
          amount: 1000.0,
          createdAt: DateTime(2024, 1, 1),
          currency: 'USD',
        ),
        CashFlowEntity(
          id: 'cf2',
          investmentId: 'inv1',
          date: DateTime(2024, 1, 7),
          type: CashFlowType.income,
          amount: 50.0,
          createdAt: DateTime(2024, 1, 7),
          currency: 'USD',
        ),
      ];

      container = ProviderContainer(
        overrides: [
          // Override providers with test data - return AsyncValue, not Stream
          activeInvestmentsProvider.overrideWith((ref) {
            return AsyncValue.data(testInvestments);
          }),
          validCashFlowsProvider.overrideWith((ref) {
            return AsyncValue.data(testCashFlows);
          }),
        ],
      );
      service = container.read(reportBuilderServiceProvider);
    });

    tearDown(() {
      container.dispose();
    });

    group('buildReport', () {
      test('builds weekly summary report', () async {
        final config = ReportConfiguration.weeklySummary(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 7),
        );

        final report = await service.buildReport(config, container);

        expect(report, isA<DynamicReportData>());
        expect(report.reportType, ReportType.weeklySummary);
        expect(report.title, isNotNull);
        expect(report.sections, isNotEmpty);
      });

      test('builds monthly income report', () async {
        final config = ReportConfiguration.monthlyIncome(
          month: DateTime(2024, 1, 15),
        );

        final report = await service.buildReport(config, container);

        expect(report.reportType, ReportType.monthlyIncome);
        expect(report.dateRange, isNotNull);
      });

      test('builds maturity calendar report', () async {
        final config = ReportConfiguration.maturityCalendar();

        final report = await service.buildReport(config, container);

        expect(report.reportType, ReportType.maturityCalendar);
      });

      test('builds filtered report by investment ID', () async {
        final config = ReportConfiguration.maturityCalendar(
          investmentId: 'inv1',
        );

        final report = await service.buildReport(config, container);

        expect(report.filteredInvestmentId, 'inv1');
      });

      test('builds filtered report by goal ID', () async {
        final config = ReportConfiguration.goalProgress(
          goalId: 'goal1',
        );

        final report = await service.buildReport(config, container);

        expect(report.filteredGoalId, 'goal1');
      });

      // Note: All ReportType enum values are implemented, so no need to test unsupported types
    });

    group('applyFilters', () {
      test('filters cashflows by date range', () async {
        final cashFlowsAsync = container.read(validCashFlowsProvider);
        final cashFlows = await cashFlowsAsync.when(
          data: (data) => Future.value(data),
          loading: () => Future.value(<CashFlowEntity>[]),
          error: (e, st) => throw e,
        );

        final dateRange = DateRangeFilter(
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 1, 5),
        );

        final filtered = service.applyDateRangeFilter(cashFlows, dateRange);

        expect(filtered.length, 1);
        expect(filtered.first.date, DateTime(2024, 1, 1));
      });

      test('filters investments by ID', () async {
        final investmentsAsync = container.read(activeInvestmentsProvider);
        final investments = await investmentsAsync.when(
          data: (data) => Future.value(data),
          loading: () => Future.value(<InvestmentEntity>[]),
          error: (e, st) => throw e,
        );

        final filtered = service.filterByInvestmentId(investments, 'inv1');

        expect(filtered.length, 1);
        expect(filtered.first.id, 'inv1');
      });
    });
  });
}
