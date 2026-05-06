import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/reports/domain/entities/report_configuration.dart';
import 'package:inv_tracker/features/reports/domain/entities/report_type.dart';

void main() {
  group('ReportConfiguration', () {
    group('Factory constructors', () {
      test('weeklySummary creates correct configuration', () {
        final config = ReportConfiguration.weeklySummary();

        expect(config.reportType, ReportType.weeklySummary);
        expect(config.dateRange, isNotNull);
        expect(config.dateRange!.duration.inDays, equals(6)); // Mon-Sun
        expect(config.fromNotification, isFalse);
      });

      test('weeklySummary with custom dates', () {
        final start = DateTime(2024, 1, 1);
        final end = DateTime(2024, 1, 7);
        final config = ReportConfiguration.weeklySummary(
          startDate: start,
          endDate: end,
        );

        expect(config.dateRange!.start, start);
        expect(config.dateRange!.end, end);
      });

      test('weeklySummary with notification context', () {
        final context = NotificationContext(
          notificationType: 'weekly_summary',
          timestamp: DateTime.now(),
        );
        final config = ReportConfiguration.weeklySummary(
          notificationContext: context,
        );

        expect(config.fromNotification, isTrue);
        expect(config.notificationContext, context);
      });

      test('monthlyIncome creates correct configuration', () {
        final month = DateTime(2024, 3, 15);
        final config = ReportConfiguration.monthlyIncome(month: month);

        expect(config.reportType, ReportType.monthlyIncome);
        expect(config.dateRange!.start, DateTime(2024, 3, 1));
        expect(config.dateRange!.end, DateTime(2024, 3, 31));
      });

      test('fyReport creates correct configuration', () {
        final config = ReportConfiguration.fyReport(fyYear: 2023);

        expect(config.reportType, ReportType.fyReport);
        expect(config.dateRange!.start, DateTime(2023, 4, 1));
        expect(config.dateRange!.end, DateTime(2024, 3, 31));
        expect(config.parameters['fyYear'], 2023);
      });

      test('maturityCalendar with investment and days', () {
        final config = ReportConfiguration.maturityCalendar(
          investmentId: 'inv123',
          daysToMaturity: 7,
        );

        expect(config.reportType, ReportType.maturityCalendar);
        expect(config.investmentId, 'inv123');
        expect(config.parameters['daysToMaturity'], 7);
      });

      test('goalProgress with goal ID and milestone', () {
        final config = ReportConfiguration.goalProgress(
          goalId: 'goal456',
          milestonePercent: 50,
        );

        expect(config.reportType, ReportType.goalProgress);
        expect(config.goalId, 'goal456');
        expect(config.parameters['milestonePercent'], 50);
      });

      test('performance creates correct configuration', () {
        final config = ReportConfiguration.performance();

        expect(config.reportType, ReportType.performance);
        expect(config.fromNotification, isFalse);
      });

      test('actionRequired creates correct configuration', () {
        final config = ReportConfiguration.actionRequired();

        expect(config.reportType, ReportType.actionRequired);
      });

      test('portfolioHealth creates correct configuration', () {
        final config = ReportConfiguration.portfolioHealth();

        expect(config.reportType, ReportType.portfolioHealth);
      });
    });

    group('Query parameter serialization', () {
      test('toQueryParams includes all fields', () {
        final config = ReportConfiguration(
          reportType: ReportType.weeklySummary,
          investmentId: 'inv123',
          dateRange: DateRangeFilter(
            start: DateTime(2024, 1, 1),
            end: DateTime(2024, 1, 7),
          ),
          parameters: {'custom': 'value'},
        );

        final params = config.toQueryParams();

        expect(params['type'], 'weekly_summary');
        expect(params['investmentId'], 'inv123');
        expect(params['startDate'], '2024-01-01T00:00:00.000');
        expect(params['endDate'], '2024-01-07T00:00:00.000');
        expect(params['custom'], 'value');
      });

      test('toQueryParams includes notification context', () {
        final context = NotificationContext(
          notificationType: 'maturity_reminder',
          timestamp: DateTime.now(),
        );
        final config = ReportConfiguration.maturityCalendar(
          notificationContext: context,
        );

        final params = config.toQueryParams();

        expect(params['fromNotification'], 'true');
        expect(params['notificationType'], 'maturity_reminder');
      });

      test('fromQueryParams reconstructs configuration', () {
        final params = {
          'type': 'weekly_summary',
          'investmentId': 'inv123',
          'startDate': '2024-01-01T00:00:00.000',
          'endDate': '2024-01-07T00:00:00.000',
          'customParam': 'value',
        };

        final config = ReportConfiguration.fromQueryParams(params);

        expect(config.reportType, ReportType.weeklySummary);
        expect(config.investmentId, 'inv123');
        expect(config.dateRange!.start, DateTime(2024, 1, 1));
        expect(config.dateRange!.end, DateTime(2024, 1, 7));
        expect(config.parameters['customParam'], 'value');
      });
    });
  });
}
