// A128: the start-up wiring that sends uncaught errors to Crashlytics is
// tested, so removing it fails the suite. It is installed before the first
// frame, so a framework error while drawing it is reported too.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/core/analytics/run_guarded.dart';
import 'package:mocktail/mocktail.dart';

class _MockCrashlyticsService extends Mock implements CrashlyticsService {}

void main() {
  late _MockCrashlyticsService service;

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(FlutterErrorDetails(exception: Exception('x')));
  });

  setUp(() {
    service = _MockCrashlyticsService();
    final flutterOnError = FlutterError.onError;
    final platformOnError = PlatformDispatcher.instance.onError;
    addTearDown(() {
      CrashlyticsService.resetGlobalHandlersForTesting();
      FlutterError.onError = flutterOnError;
      PlatformDispatcher.instance.onError = platformOnError;
    });
  });

  test('an async error in the body reaches handleZoneError once', () async {
    runGuarded(() async {
      await Future<void>(() => throw StateError('boom'));
    }, service: service);
    await pumpEventQueue();

    final captured = verify(
      () => service.handleZoneError(captureAny(), any()),
    ).captured;
    expect(captured, hasLength(1));
    expect((captured.single as StateError).message, 'boom');
  });

  test('framework errors go to handleFlutterError', () {
    runGuarded(() async {}, service: service);
    final details = FlutterErrorDetails(exception: StateError('build'));

    FlutterError.onError!(details);

    verify(() => service.handleFlutterError(details)).called(1);
  });

  test('platform errors go to handlePlatformError and count as handled', () {
    runGuarded(() async {}, service: service);
    final error = StateError('platform');
    final stack = StackTrace.current;

    final handled = PlatformDispatcher.instance.onError!(error, stack);

    expect(handled, isTrue);
    verify(() => service.handlePlatformError(error, stack)).called(1);
  });

  test('installing again does not report one error twice', () {
    runGuarded(() async {}, service: service);
    CrashlyticsService.installGlobalHandlers(service);
    final details = FlutterErrorDetails(exception: StateError('build'));

    FlutterError.onError!(details);

    verify(() => service.handleFlutterError(details)).called(1);
  });

  test('main() starts the app through runGuarded', () {
    final main = File('lib/main.dart').readAsStringSync();

    expect(main, contains('runGuarded('));
    expect(main, isNot(contains('runZonedGuarded(')));
  });
}
