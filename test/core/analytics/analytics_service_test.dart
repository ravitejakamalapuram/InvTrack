import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';

void main() {
  group('AnalyticsEvents', () {
    test('should have correct core conversion event names', () {
      expect(AnalyticsEvents.investmentCreated, 'investment_created');
      expect(AnalyticsEvents.cashFlowAdded, 'cashflow_added');
    });

    test('should have correct feature adoption event names', () {
      expect(AnalyticsEvents.csvImportCompleted, 'csv_import_completed');
      expect(AnalyticsEvents.exportGenerated, 'export_generated');
    });

    test('should have correct error event names', () {
      expect(AnalyticsEvents.errorOccurred, 'error_occurred');
    });

    // Report event constants — verify these survived the portfolio health analytics removal
    test('should have correct report event names', () {
      expect(AnalyticsEvents.reportViewed, 'report_viewed');
      expect(AnalyticsEvents.reportExported, 'report_exported');
      expect(AnalyticsEvents.historicalReportAccessed, 'historical_report_accessed');
      expect(AnalyticsEvents.reportMetricTooltipViewed, 'report_metric_tooltip_viewed');
    });

    // Multi-currency event constants — verify these are intact after the refactor
    test('should have correct multi-currency event names', () {
      expect(AnalyticsEvents.currencySelected, 'currency_selected');
      expect(AnalyticsEvents.currencyConversionFailed, 'currency_conversion_failed');
      expect(AnalyticsEvents.exchangeRateCacheHit, 'exchange_rate_cache_hit');
    });
  });
}
