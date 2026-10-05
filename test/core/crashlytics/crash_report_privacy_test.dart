// A125: no user-entered text, email or path reaches Crashlytics through an
// exception, a metadata value or ErrorHandler's reason (CLAUDE.md rule 7).
// Reports carry the error's type and, for Firebase and platform errors, its
// code; never its message.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/core/error/error_handler.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseCrashlytics extends Mock implements FirebaseCrashlytics {}

void main() {
  late _MockFirebaseCrashlytics firebase;
  late CrashlyticsService service;

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(const <Object>[]);
    registerFallbackValue(FlutterErrorDetails(exception: Exception('x')));
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
      () => firebase.recordFlutterError(any(), fatal: any(named: 'fatal')),
    ).thenAnswer((_) async {});
    when(
      () => firebase.recordFlutterFatalError(any()),
    ).thenAnswer((_) async {});
    // Tests run with kDebugMode == true, so reporting needs the debug override.
    CrashlyticsService.enableInDebugMode = true;
    service = CrashlyticsService(debugModeEnabled: true, crashlytics: firebase);
    LoggerService.crashlyticsServiceForTesting = service;
  });

  tearDown(() {
    CrashlyticsService.enableInDebugMode = false;
    LoggerService.crashlyticsServiceForTesting = null;
  });

  /// Every recorded (exception text, reason) pair.
  List<(String, String?)> recorded() {
    final captured = verify(
      () => firebase.recordError(
        captureAny(),
        any(),
        reason: captureAny(named: 'reason'),
        fatal: any(named: 'fatal'),
        information: any(named: 'information'),
      ),
    ).captured;
    return [
      for (var i = 0; i < captured.length; i += 2)
        (captured[i].toString(), captured[i + 1] as String?),
    ];
  }

  group('LoggerService', () {
    test('sends the exception type, not its message', () {
      LoggerService.warn(
        'Could not read',
        error: Exception('Ravi Kumar FD 500000'),
      );

      final records = recorded();
      expect(records, hasLength(1));
      final (exception, reason) = records.single;
      expect(reason, 'Could not read');
      expect(exception, '_Exception');
      for (final leaked in ['Ravi', 'Kumar', '500000']) {
        expect(exception, isNot(contains(leaked)));
        expect(reason, isNot(contains(leaked)));
      }
    });

    test(
      'keeps a metadata value only if it is a number, a bool or a token',
      () {
        expect(
          LoggerService.crashlyticsReason('m', {
            'from': 'Ravi Kumar',
            'errorCount': 3,
          }),
          'm | Metadata: errorCount=3',
        );
        expect(
          LoggerService.crashlyticsReason('m', {'from': 'INR', 'to': 'USD'}),
          'm | Metadata: from=INR, to=USD',
        );
        expect(
          LoggerService.crashlyticsReason('m', {
            'code': 'ravi@example.com',
            'source': '/data/user/0/app/receipt.pdf',
            'fatal': false,
            'operation': 'save:snapshot_v2',
          }),
          'm | Metadata: fatal=false, operation=save:snapshot_v2',
        );
        expect(LoggerService.crashlyticsReason('m', {'code': 'x' * 65}), 'm');
      },
    );
  });

  group('ErrorHandler', () {
    test('builds the reason from the type, not the message', () {
      ErrorHandler.logError(
        DataException(technicalMessage: 'user@example.com'),
      );

      final (exception, reason) = recorded().single;
      expect(reason, 'DataException');
      expect(exception, 'DataException');
    });

    test('keeps the code of an AuthException in the reason', () {
      ErrorHandler.logError(
        AuthException(
          technicalMessage: 'No account for ravi@example.com',
          code: AuthExceptionCode.invalidCredential,
        ),
      );

      final (exception, reason) = recorded().single;
      expect(reason, 'AuthException(invalidCredential)');
      expect(exception, 'AuthException(invalidCredential)');
    });

    test('sends the code of a Firebase cause, not its message', () {
      ErrorHandler.logError(
        ErrorHandler.mapException(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'failed-precondition',
            message: 'users/uid123/investments/Ravi FD',
          ),
        ),
      );

      final (exception, reason) = recorded().single;
      expect(reason, 'DataException');
      expect(
        exception,
        'FirebaseException(cloud_firestore/failed-precondition)',
      );
    });
  });

  group('uncaught errors', () {
    test('a zone error with a document path sends only plugin and code', () {
      service.handleZoneError(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'users/uid123/investments/abc',
        ),
        StackTrace.current,
      );

      final (exception, reason) = recorded().single;
      expect(exception, 'FirebaseException(cloud_firestore/not-found)');
      expect('$exception $reason', isNot(contains('users/')));
      expect('$exception $reason', isNot(contains('uid123')));
    });

    test('a platform error sends only its code', () {
      service.handlePlatformError(
        PlatformException(
          code: 'sign_in_failed',
          message: 'ravi@example.com',
          details: '/data/user/0/app',
        ),
        StackTrace.current,
      );

      final (exception, _) = recorded().single;
      expect(exception, 'PlatformException(sign_in_failed)');
    });

    test('a code that is not a plain token is dropped', () {
      service.handleZoneError(
        PlatformException(code: 'ravi@example.com'),
        StackTrace.current,
      );

      final (exception, _) = recorded().single;
      expect(exception, 'PlatformException');
    });

    test('a framework error sends the type, stack and library only', () {
      final stack = StackTrace.current;
      service.handleFlutterError(
        FlutterErrorDetails(
          exception: StateError('Ravi Kumar FD 500000'),
          stack: stack,
          library: 'widgets library',
          context: ErrorDescription('building Text("Ravi Kumar")'),
          informationCollector: () => [ErrorDescription('Ravi Kumar')],
        ),
      );

      final captured = verify(
        () => firebase.recordFlutterError(
          captureAny(),
          fatal: any(named: 'fatal'),
        ),
      ).captured;
      final details = captured.single as FlutterErrorDetails;
      expect(details.exceptionAsString(), 'StateError');
      expect(details.stack, stack);
      expect(details.library, 'widgets library');
      expect(details.context, isNull);
      expect(details.informationCollector, isNull);
    });
  });
}
