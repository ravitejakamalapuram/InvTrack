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
  });
}
