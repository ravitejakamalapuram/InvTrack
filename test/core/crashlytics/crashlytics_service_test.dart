import 'dart:async';
import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:mockito/mockito.dart';

class MockFirebaseCrashlytics extends Mock implements FirebaseCrashlytics {}

void main() {
  group('CrashlyticsService', () {
    test('should be a valid class', () {
      expect(CrashlyticsService, isNotNull);
    });

    test('crashlyticsServiceProvider should be defined', () {
      expect(crashlyticsServiceProvider, isNotNull);
    });

    group('isTransientError', () {
      late CrashlyticsService service;

      setUp(() {
        service = CrashlyticsService(
          debugModeEnabled: false,
          crashlytics: MockFirebaseCrashlytics(),
        );
      });

      test('identifies network and timeout errors as transient', () {
        expect(service.isTransientError(TimeoutException('timeout')), isTrue);
        expect(service.isTransientError(const SocketException('connection reset')), isTrue);
        expect(service.isTransientError(const HttpException('bad response')), isTrue);
      });

      test('identifies non-reportable AppException as transient', () {
        final nonReportable = AuthException.signInCancelled();
        expect(nonReportable.shouldReport, isFalse);
        expect(service.isTransientError(nonReportable), isTrue);
      });

      test('identifies unwrapped transient cause in AppException as transient', () {
        final wrappedTimeout = NetworkException.timeout(cause: TimeoutException('timed out'));
        expect(service.isTransientError(wrappedTimeout), isTrue);
      });

      test('identifies fatal programming/state errors as non-transient', () {
        expect(service.isTransientError(FormatException('invalid syntax')), isFalse);
        expect(service.isTransientError(StateError('unexpected state')), isFalse);
        expect(service.isTransientError(RangeError.index(5, [])), isFalse);
      });
    });
  });
}
