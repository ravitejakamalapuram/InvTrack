import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseAnalytics extends Mock implements FirebaseAnalytics {}

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
  });

  group('AnalyticsService parameters', () {
    late _MockFirebaseAnalytics firebase;
    late AnalyticsService service;

    setUp(() {
      firebase = _MockFirebaseAnalytics();
      when(
        () => firebase.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => firebase.logScreenView(
          screenName: any(named: 'screenName'),
          screenClass: any(named: 'screenClass'),
        ),
      ).thenAnswer((_) async {});
      service = AnalyticsService(analytics: firebase);
    });

    // The Firebase plugin asserts that every value is a String or a num, and
    // GA4 stores nothing else, so a bool flag must go out as 1 or 0.
    test('investment_created sends the notes flag as 1, not true', () async {
      await service.logInvestmentCreated(investmentType: 'fd', hasNotes: true);

      verify(
        () => firebase.logEvent(
          name: 'investment_created',
          parameters: {
            'investment_type': 'fd',
            'has_notes': 1,
            'has_amount': 0,
          },
        ),
      ).called(1);
    });

    test('screen_view sends the screen name and no class', () async {
      await service.logScreenView(screenName: 'goal_create');

      verify(
        () => firebase.logScreenView(
          screenName: 'goal_create',
          screenClass: null,
        ),
      ).called(1);
    });
  });

  group('AnalyticsService.setUserId', () {
    test('propagates Firebase failures so identity sync can retry', () async {
      final firebase = _MockFirebaseAnalytics();
      final error = StateError('analytics unavailable');
      final expectedStack = StackTrace.current;
      when(() => firebase.setUserId(id: 'g1')).thenAnswer((_) async {
        Error.throwWithStackTrace(error, expectedStack);
      });

      final service = AnalyticsService(analytics: firebase);

      try {
        await service.setUserId('g1');
        fail('setUserId should propagate Firebase failures');
      } catch (e, stackTrace) {
        expect(e, same(error));
        expect(stackTrace.toString(), expectedStack.toString());
      }
    });

    test('clears the Firebase identity when user ID is null', () async {
      final firebase = _MockFirebaseAnalytics();
      when(() => firebase.setUserId(id: null)).thenAnswer((_) async {});

      final service = AnalyticsService(analytics: firebase);

      await service.setUserId(null);

      verify(() => firebase.setUserId(id: null)).called(1);
    });
  });
}
