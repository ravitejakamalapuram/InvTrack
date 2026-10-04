// Global error handlers -> Crashlytics (A30: ARCH-15, ARCH-V01).
//
// One uncaught error must produce exactly one Crashlytics event: fatal when it
// is a real crash, and nothing at all when it is a transient network or
// Firestore error. This holds for all three global handlers.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseCrashlytics extends Mock implements FirebaseCrashlytics {}

void main() {
  late _MockFirebaseCrashlytics firebase;
  late CrashlyticsService service;

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(const <Object>[]);
    registerFallbackValue(
      FlutterErrorDetails(exception: Exception('fallback')),
    );
  });

  setUp(() {
    firebase = _MockFirebaseCrashlytics();
    when(
      () => firebase.recordError(
        any(),
        any(),
        reason: any(named: 'reason'),
        fatal: any(named: 'fatal'),
        information: any(named: 'information'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => firebase.recordFlutterFatalError(any()),
    ).thenAnswer((_) async {});
    // Tests run with kDebugMode == true, so reporting needs the debug override.
    CrashlyticsService.enableInDebugMode = true;
    service = CrashlyticsService(debugModeEnabled: true, crashlytics: firebase);
    // LoggerService reports through the same Crashlytics instance, so any
    // follow-up LoggerService.error from a handler shows up as a second event.
    LoggerService.crashlyticsServiceForTesting = service;
  });

  tearDown(() {
    CrashlyticsService.enableInDebugMode = false;
    LoggerService.crashlyticsServiceForTesting = null;
  });

  List<Object?> recordedFatalFlags() {
    final calls = verify(
      () => firebase.recordError(
        any(),
        any(),
        reason: any(named: 'reason'),
        fatal: captureAny(named: 'fatal'),
        information: any(named: 'information'),
      ),
    );
    return calls.captured;
  }

  void expectNothingRecorded() {
    verifyNever(
      () => firebase.recordError(
        any(),
        any(),
        reason: any(named: 'reason'),
        fatal: any(named: 'fatal'),
        information: any(named: 'information'),
      ),
    );
    verifyNever(() => firebase.recordFlutterFatalError(any()));
  }

  final transientErrors = <String, Object>{
    'TimeoutException': TimeoutException('Health score save timed out'),
    'Firestore unavailable': FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
    ),
  };

  group('PlatformDispatcher.onError', () {
    test('records one uncaught crash exactly once, as fatal', () {
      service.handlePlatformError(StateError('real crash'), StackTrace.current);

      expect(recordedFatalFlags(), [true]);
      verifyNever(() => firebase.recordFlutterFatalError(any()));
    });

    transientErrors.forEach((name, error) {
      test('does not record a transient $name', () {
        service.handlePlatformError(error, StackTrace.current);

        expectNothingRecorded();
      });
    });
  });

  group('runZonedGuarded handler', () {
    test('records one uncaught crash exactly once, as fatal', () {
      service.handleZoneError(StateError('real crash'), StackTrace.current);

      expect(recordedFatalFlags(), [true]);
    });

    transientErrors.forEach((name, error) {
      test('does not record a transient $name', () {
        service.handleZoneError(error, StackTrace.current);

        expectNothingRecorded();
      });
    });

    test('does not throw when Firebase is not initialised yet', () async {
      // No injected instance: FirebaseCrashlytics.instance throws in tests,
      // just like a zone error raised before Firebase.initializeApp completes.
      LoggerService.crashlyticsServiceForTesting = null;
      final early = CrashlyticsService(debugModeEnabled: true);

      final uncaught = <Object>[];
      await runZonedGuarded(() async {
        early.handleZoneError(StateError('early crash'), StackTrace.current);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
      }, (error, _) => uncaught.add(error));

      expect(uncaught, isEmpty);
    });
  });

  group('a rejected Crashlytics upload', () {
    final handlers = <String, void Function(CrashlyticsService, Object)>{
      'runZonedGuarded handler': (s, e) =>
          s.handleZoneError(e, StackTrace.current),
      'PlatformDispatcher.onError': (s, e) =>
          s.handlePlatformError(e, StackTrace.current),
    };

    handlers.forEach((name, handle) {
      test('from the $name does not surface as a new uncaught error', () async {
        when(
          () => firebase.recordError(
            any(),
            any(),
            reason: any(named: 'reason'),
            fatal: any(named: 'fatal'),
            information: any(named: 'information'),
          ),
        ).thenAnswer((_) => Future<void>.error(StateError('upload failed')));

        final uncaught = <Object>[];
        await runZonedGuarded(() async {
          handle(service, StateError('real crash'));
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
        }, (error, _) => uncaught.add(error));

        expect(uncaught, isEmpty);
      });
    });
  });

  group('FlutterError.onError', () {
    test('records one framework crash exactly once, as fatal', () {
      service.handleFlutterError(
        FlutterErrorDetails(
          exception: StateError('build failed'),
          stack: StackTrace.current,
          library: 'widgets library',
        ),
      );

      verify(() => firebase.recordFlutterFatalError(any())).called(1);
      verifyNever(
        () => firebase.recordError(
          any(),
          any(),
          reason: any(named: 'reason'),
          fatal: any(named: 'fatal'),
          information: any(named: 'information'),
        ),
      );
    });

    test('does not record a transient framework error', () {
      service.handleFlutterError(
        FlutterErrorDetails(exception: TimeoutException('image load')),
      );

      expectNothingRecorded();
    });
  });
}
