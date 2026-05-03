import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/reports/data/services/report_cache_service.dart';
import 'package:inv_tracker/features/reports/domain/entities/report_type.dart';

void main() {
  group('ReportCacheService', () {
    late ReportCacheService service;

    setUp(() {
      service = ReportCacheService();
    });

    test('should cache and retrieve data', () {
      final periodStart = DateTime(2024, 1, 1);
      final periodEnd = DateTime(2024, 1, 31);
      final reportData = {'test': 'data'};

      // Store in cache
      service.set(ReportType.weeklySummary, periodStart, periodEnd, reportData);

      // Retrieve from cache
      final cached = service.get<Map<String, String>>(
        ReportType.weeklySummary,
        periodStart,
        periodEnd,
      );

      expect(cached, isNotNull);
      expect(cached!['test'], 'data');
    });

    test('should return null for cache miss', () {
      final periodStart = DateTime(2024, 1, 1);
      final periodEnd = DateTime(2024, 1, 31);

      final cached = service.get<Map<String, String>>(
        ReportType.weeklySummary,
        periodStart,
        periodEnd,
      );

      expect(cached, isNull);
    });

    test('should clear cache for specific report type', () {
      final periodStart = DateTime(2024, 1, 1);
      final periodEnd = DateTime(2024, 1, 31);
      final reportData = {'test': 'data'};

      // Store in cache
      service.set(ReportType.weeklySummary, periodStart, periodEnd, reportData);

      // Verify it's cached
      expect(service.get(ReportType.weeklySummary, periodStart, periodEnd), isNotNull);

      // Clear type
      service.clearType(ReportType.weeklySummary);

      // Verify it's gone
      expect(service.get(ReportType.weeklySummary, periodStart, periodEnd), isNull);
    });

    test('should clear all cache', () {
      final periodStart = DateTime(2024, 1, 1);
      final periodEnd = DateTime(2024, 1, 31);

      // Cache multiple items
      service.set(ReportType.weeklySummary, periodStart, periodEnd, {'test': 'data1'});
      service.set(ReportType.monthlyIncome, periodStart, periodEnd, {'test': 'data2'});

      // Verify they're cached
      expect(service.get(ReportType.weeklySummary, periodStart, periodEnd), isNotNull);
      expect(service.get(ReportType.monthlyIncome, periodStart, periodEnd), isNotNull);

      // Clear all
      service.clearAll();

      // Verify they're gone
      expect(service.get(ReportType.weeklySummary, periodStart, periodEnd), isNull);
      expect(service.get(ReportType.monthlyIncome, periodStart, periodEnd), isNull);
    });

    test('should handle different report types independently', () {
      final periodStart = DateTime(2024, 1, 1);
      final periodEnd = DateTime(2024, 1, 31);

      service.set(ReportType.weeklySummary, periodStart, periodEnd, {'type': 'weekly'});
      service.set(ReportType.monthlyIncome, periodStart, periodEnd, {'type': 'monthly'});

      final weekly = service.get<Map<String, String>>(
        ReportType.weeklySummary,
        periodStart,
        periodEnd,
      );
      final monthly = service.get<Map<String, String>>(
        ReportType.monthlyIncome,
        periodStart,
        periodEnd,
      );

      expect(weekly!['type'], 'weekly');
      expect(monthly!['type'], 'monthly');
    });

    test('should handle different periods independently', () {
      final periodStart1 = DateTime(2024, 1, 1);
      final periodEnd1 = DateTime(2024, 1, 31);
      final periodStart2 = DateTime(2024, 2, 1);
      final periodEnd2 = DateTime(2024, 2, 29);

      service.set(ReportType.weeklySummary, periodStart1, periodEnd1, {'month': 'jan'});
      service.set(ReportType.weeklySummary, periodStart2, periodEnd2, {'month': 'feb'});

      final jan = service.get<Map<String, String>>(
        ReportType.weeklySummary,
        periodStart1,
        periodEnd1,
      );
      final feb = service.get<Map<String, String>>(
        ReportType.weeklySummary,
        periodStart2,
        periodEnd2,
      );

      expect(jan!['month'], 'jan');
      expect(feb!['month'], 'feb');
    });
  });
}
