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

    test('should have correct error event names', () {
      expect(AnalyticsEvents.errorOccurred, 'error_occurred');
    });
  });

  group('AnalyticsService.setUserId', () {
    test('propagates Firebase failures so identity sync can retry', () async {
      final firebase = _MockFirebaseAnalytics();
      final error = StateError('analytics unavailable');
      when(() => firebase.setUserId(id: 'g1'))
          .thenThrow(error);

      final service = AnalyticsService(analytics: firebase);

      await expectLater(
        service.setUserId('g1'),
        throwsA(same(error)),
      );
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
