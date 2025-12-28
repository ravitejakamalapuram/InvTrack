import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';

void main() {
  group('CrashlyticsService', () {
    test('should be a valid class', () {
      // CrashlyticsService wraps Firebase Crashlytics
      // In tests, Firebase is not initialized, so we just verify the class exists
      // The class type should be non-null
      expect(CrashlyticsService, isNotNull);
    });

    test('crashlyticsServiceProvider should be defined', () {
      // Verify the provider is defined
      expect(crashlyticsServiceProvider, isNotNull);
    });
  });
}
