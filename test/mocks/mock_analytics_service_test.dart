/// Tests for FakeAnalyticsService mock
///
/// Verifies that the FakeAnalyticsService correctly:
/// - Records events with their parameters
/// - Tracks screen views separately
/// - Resets all state via reset()
/// - Implements all remaining analytics methods correctly
///
/// Note: Portfolio health analytics methods (logPortfolioHealthViewed,
/// logPortfolioHealthDetailsOpened, logHealthScoreCalculated,
/// logHealthComponentExpanded, logHealthScoreShared) were removed in this PR
/// along with the corresponding AnalyticsService methods.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'mock_analytics_service.dart';

void main() {
  late FakeAnalyticsService fakeAnalytics;

  setUp(() {
    fakeAnalytics = FakeAnalyticsService();
  });

  group('FakeAnalyticsService', () {
    group('logEvent', () {
      test('records event name and parameters', () async {
        await fakeAnalytics.logEvent(
          name: 'test_event',
          parameters: {'key': 'value'},
        );

        expect(fakeAnalytics.loggedEvents.length, 1);
        expect(fakeAnalytics.loggedEvents.first.name, 'test_event');
        expect(fakeAnalytics.loggedEvents.first.parameters, {'key': 'value'});
      });

      test('records multiple events in order', () async {
        await fakeAnalytics.logEvent(name: 'event_a');
        await fakeAnalytics.logEvent(name: 'event_b');
        await fakeAnalytics.logEvent(name: 'event_c');

        expect(fakeAnalytics.loggedEvents.length, 3);
        expect(fakeAnalytics.loggedEvents[0].name, 'event_a');
        expect(fakeAnalytics.loggedEvents[1].name, 'event_b');
        expect(fakeAnalytics.loggedEvents[2].name, 'event_c');
      });

      test('records event without parameters', () async {
        await fakeAnalytics.logEvent(name: 'no_params_event');

        expect(fakeAnalytics.loggedEvents.first.name, 'no_params_event');
        expect(fakeAnalytics.loggedEvents.first.parameters, isNull);
      });
    });

    group('reset', () {
      test('clears all logged events', () async {
        await fakeAnalytics.logEvent(name: 'event1');
        await fakeAnalytics.logEvent(name: 'event2');
        expect(fakeAnalytics.loggedEvents.length, 2);

        fakeAnalytics.reset();

        expect(fakeAnalytics.loggedEvents, isEmpty);
      });

      test('clears screen views', () async {
        await fakeAnalytics.logScreenView(screenName: 'HomeScreen');
        expect(fakeAnalytics.screenViews.length, 1);

        fakeAnalytics.reset();

        expect(fakeAnalytics.screenViews, isEmpty);
      });

      test('clears current user ID', () async {
        await fakeAnalytics.setUserId('user123');
        expect(fakeAnalytics.currentUserId, 'user123');

        fakeAnalytics.reset();

        expect(fakeAnalytics.currentUserId, isNull);
      });

      test('clears user properties', () async {
        await fakeAnalytics.setUserProperty(name: 'prop', value: 'val');
        expect(fakeAnalytics.userProperties['prop'], 'val');

        fakeAnalytics.reset();

        expect(fakeAnalytics.userProperties, isEmpty);
      });

      test('allows fresh recording after reset', () async {
        await fakeAnalytics.logEvent(name: 'before_reset');
        fakeAnalytics.reset();
        await fakeAnalytics.logEvent(name: 'after_reset');

        expect(fakeAnalytics.loggedEvents.length, 1);
        expect(fakeAnalytics.loggedEvents.first.name, 'after_reset');
      });
    });

    group('logScreenView', () {
      test('records screen name in screenViews list', () async {
        await fakeAnalytics.logScreenView(screenName: 'HomeScreen');

        expect(fakeAnalytics.screenViews.length, 1);
        expect(fakeAnalytics.screenViews.first, 'HomeScreen');
      });

      test('does not add screen view to loggedEvents', () async {
        await fakeAnalytics.logScreenView(screenName: 'HomeScreen');

        expect(fakeAnalytics.loggedEvents, isEmpty);
      });
    });

    group('setUserId', () {
      test('stores user ID', () async {
        await fakeAnalytics.setUserId('user-abc');
        expect(fakeAnalytics.currentUserId, 'user-abc');
      });

      test('stores null user ID', () async {
        await fakeAnalytics.setUserId('user-abc');
        await fakeAnalytics.setUserId(null);
        expect(fakeAnalytics.currentUserId, isNull);
      });
    });

    group('setUserProperty', () {
      test('stores user property', () async {
        await fakeAnalytics.setUserProperty(name: 'plan', value: 'premium');
        expect(fakeAnalytics.userProperties['plan'], 'premium');
      });

      test('stores null user property value', () async {
        await fakeAnalytics.setUserProperty(name: 'plan', value: null);
        expect(fakeAnalytics.userProperties['plan'], isNull);
      });
    });

    group('getObserver', () {
      test('returns null (no Firebase in tests)', () {
        expect(fakeAnalytics.getObserver(), isNull);
      });
    });

    group('report analytics methods', () {
      test('logReportViewed logs correct event name and parameters', () async {
        await fakeAnalytics.logReportViewed(
          reportType: 'performance',
          isHistorical: false,
          period: 'FY2023-24',
        );

        expect(fakeAnalytics.loggedEvents.length, 1);
        expect(fakeAnalytics.loggedEvents.first.name, AnalyticsEvents.reportViewed);
        final params = fakeAnalytics.loggedEvents.first.parameters!;
        expect(params['report_type'], 'performance');
        expect(params['is_historical'], 0);
        expect(params['period'], 'FY2023-24');
      });

      test('logReportViewed defaults isHistorical to false', () async {
        await fakeAnalytics.logReportViewed(reportType: 'goals');

        final params = fakeAnalytics.loggedEvents.first.parameters!;
        expect(params['is_historical'], 0);
        expect(params.containsKey('period'), isFalse);
      });

      test('logReportExported logs correct event with all parameters', () async {
        await fakeAnalytics.logReportExported(
          reportType: 'performance',
          format: 'pdf',
          recordCount: 25,
        );

        expect(fakeAnalytics.loggedEvents.first.name, AnalyticsEvents.reportExported);
        final params = fakeAnalytics.loggedEvents.first.parameters!;
        expect(params['report_type'], 'performance');
        expect(params['format'], 'pdf');
        expect(params['record_count'], 25);
      });

      test('logReportExported works without optional recordCount', () async {
        await fakeAnalytics.logReportExported(
          reportType: 'maturity_calendar',
          format: 'csv',
        );

        final params = fakeAnalytics.loggedEvents.first.parameters!;
        expect(params.containsKey('record_count'), isFalse);
      });

      test('logHistoricalReportAccessed logs correct event', () async {
        await fakeAnalytics.logHistoricalReportAccessed(
          reportType: 'fy_report',
          periodsBack: 2,
          period: 'FY',
        );

        expect(fakeAnalytics.loggedEvents.first.name, AnalyticsEvents.historicalReportAccessed);
        final params = fakeAnalytics.loggedEvents.first.parameters!;
        expect(params['report_type'], 'fy_report');
        expect(params['periods_back'], 2);
        expect(params['period'], 'FY');
      });

      test('logReportMetricTooltipViewed logs correct event', () async {
        await fakeAnalytics.logReportMetricTooltipViewed(
          metricName: 'xirr',
          reportType: 'performance',
        );

        expect(fakeAnalytics.loggedEvents.first.name, AnalyticsEvents.reportMetricTooltipViewed);
        final params = fakeAnalytics.loggedEvents.first.parameters!;
        expect(params['metric_name'], 'xirr');
        expect(params['report_type'], 'performance');
      });
    });
  });
}
