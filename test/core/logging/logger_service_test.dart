// LoggerService -> Crashlytics contract (A30: ARCH-15, SEC-09).
//
// - Logged errors and warnings are non-fatal: only real crashes may count
//   against the crash-free rate.
// - Metadata reaches Crashlytics only through an allowlist, so user-entered
//   names, file names and device paths never leave the device.
import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseCrashlytics extends Mock implements FirebaseCrashlytics {}

void main() {
  late _MockFirebaseCrashlytics firebase;

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(const <Object>[]);
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
    // Tests run with kDebugMode == true, so reporting needs the debug override.
    CrashlyticsService.enableInDebugMode = true;
    LoggerService.crashlyticsServiceForTesting = CrashlyticsService(
      debugModeEnabled: true,
      crashlytics: firebase,
    );
  });

  tearDown(() {
    CrashlyticsService.enableInDebugMode = false;
    LoggerService.crashlyticsServiceForTesting = null;
  });

  List<Object?> capturedNamed(String name) => verify(
    () => firebase.recordError(
      any(),
      any(),
      reason: name == 'reason'
          ? captureAny(named: 'reason')
          : any(named: 'reason'),
      fatal: name == 'fatal' ? captureAny(named: 'fatal') : any(named: 'fatal'),
      information: any(named: 'information'),
    ),
  ).captured;

  group('LoggerService.error', () {
    test('records a non-fatal event, never a crash', () {
      LoggerService.error(
        'Error initializing currency cache',
        error: StateError('cache failed'),
        stackTrace: StackTrace.current,
        metadata: {'service': 'CurrencyConversionService'},
      );

      expect(capturedNamed('fatal'), [false]);
    });

    test('LoggerService.warn also records a non-fatal event', () {
      LoggerService.warn('Something odd', error: StateError('odd'));

      expect(capturedNamed('fatal'), [false]);
    });

    test(
      'a failed Crashlytics upload does not surface as an uncaught error',
      () async {
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
          LoggerService.error('Failed to save', error: StateError('boom'));
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
        }, (error, _) => uncaught.add(error));

        expect(uncaught, isEmpty);
      },
    );
  });

  group('metadata sent to Crashlytics (SEC-09)', () {
    const documentName = 'Aadhaar - Ravi';
    const fileName = 'HDFC FD receipt 5L.pdf';
    const localPath =
        '/data/user/0/com.invtracker.inv_tracker/app_flutter/documents/uid-abc123/inv-1/receipt.pdf';

    test('drops names, file names and paths but keeps ids', () {
      LoggerService.warn(
        'Document not found or inaccessible during export',
        metadata: {
          'documentId': 'doc-1',
          'documentName': documentName,
          'fileName': fileName,
          'localPath': localPath,
          'path': localPath,
          'investmentName': 'Ravi gold loan',
          'investmentId': 'inv-1',
        },
      );

      final reasons = capturedNamed('reason');
      expect(reasons, hasLength(1));
      final reason = reasons.single! as String;
      expect(
        reason,
        contains('Document not found or inaccessible during export'),
      );
      expect(reason, contains('documentId=doc-1'));
      expect(reason, contains('investmentId=inv-1'));
      for (final leaked in [
        documentName,
        fileName,
        localPath,
        'uid-abc123',
        'Ravi gold loan',
        'documentName',
        'fileName',
        'localPath',
      ]) {
        expect(reason, isNot(contains(leaked)), reason: 'leaked "$leaked"');
      }
    });

    test('drops free-text values such as error descriptions and user ids', () {
      LoggerService.error(
        'Sign-in failed',
        metadata: {
          'code': 'invalid-credential',
          'description': 'No account for ravi@example.com',
          'message': 'ravi@example.com',
          'details': '{email: ravi@example.com}',
          'userId': 'uid-abc123',
        },
      );

      final reason = capturedNamed('reason').single! as String;
      expect(reason, 'Sign-in failed | Metadata: code=invalid-credential');
    });

    test('the allowlist holds no key that can carry PII or amounts', () {
      // `platform` and `notes` are also user-entered investment fields.
      final risky = RegExp(
        r'name|path|file|amount|value|email|phone|message|description|^details$|error$|^user|^platform$|notes',
        caseSensitive: false,
      );
      expect(
        LoggerService.crashlyticsMetadataAllowlist.where(risky.hasMatch),
        isEmpty,
      );
    });

    test('never sets Crashlytics custom keys from log metadata', () {
      LoggerService.error(
        'Failed',
        metadata: {'documentName': documentName, 'path': localPath},
      );

      verifyNever(() => firebase.setCustomKey(any(), any()));
    });
  });
}
