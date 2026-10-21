import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/consent_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAnalytics extends Mock implements FirebaseAnalytics {}

class _MockCrashlytics extends Mock implements FirebaseCrashlytics {}

void main() {
  late _MockAnalytics analytics;
  late _MockCrashlytics crashlytics;

  Future<ConsentService> service([Map<String, Object> prefs = const {}]) async {
    SharedPreferences.setMockInitialValues(prefs);
    return ConsentService(
      await SharedPreferences.getInstance(),
      analytics: analytics,
      crashlytics: crashlytics,
    );
  }

  setUp(() {
    analytics = _MockAnalytics();
    crashlytics = _MockCrashlytics();
    when(
      () => analytics.setAnalyticsCollectionEnabled(any()),
    ).thenAnswer((_) async {});
    when(
      () => crashlytics.setCrashlyticsCollectionEnabled(any()),
    ).thenAnswer((_) async {});
  });

  test('both choices default to on for a user who never chose', () async {
    final s = await service();
    expect(s.analyticsEnabled, isTrue);
    expect(s.crashReportingEnabled, isTrue);
  });

  test('startup with analytics off turns Analytics collection off', () async {
    final s = await service({analyticsConsentPrefKey: false});
    await s.applyAtStartup();
    verify(() => analytics.setAnalyticsCollectionEnabled(false)).called(1);
    verifyNever(() => crashlytics.setCrashlyticsCollectionEnabled(any()));
  });

  test(
    'startup with crash reporting off turns Crashlytics collection off',
    () async {
      final s = await service({crashReportingConsentPrefKey: false});
      await s.applyAtStartup();
      verify(
        () => crashlytics.setCrashlyticsCollectionEnabled(false),
      ).called(1);
      verify(() => analytics.setAnalyticsCollectionEnabled(true)).called(1);
    },
  );

  test(
    'startup for an existing user leaves Crashlytics to its own init',
    () async {
      final s = await service();
      await s.applyAtStartup();
      verify(() => analytics.setAnalyticsCollectionEnabled(true)).called(1);
      verifyNever(() => crashlytics.setCrashlyticsCollectionEnabled(any()));
    },
  );

  test('setAnalytics applies the choice, then stores it', () async {
    final s = await service();
    await s.setAnalytics(false);
    verify(() => analytics.setAnalyticsCollectionEnabled(false)).called(1);
    expect(s.analyticsEnabled, isFalse);
  });

  test('setAnalytics stores nothing when Firebase throws', () async {
    when(
      () => analytics.setAnalyticsCollectionEnabled(any()),
    ).thenThrow(Exception('boom'));
    final s = await service();
    await expectLater(s.setAnalytics(false), throwsException);
    expect(s.analyticsEnabled, isTrue);
  });

  test('setCrashReporting off turns collection off and stores it', () async {
    final s = await service();
    await s.setCrashReporting(false);
    verify(() => crashlytics.setCrashlyticsCollectionEnabled(false)).called(1);
    expect(s.crashReportingEnabled, isFalse);
  });
}
