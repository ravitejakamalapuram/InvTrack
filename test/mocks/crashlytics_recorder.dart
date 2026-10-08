import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';

/// One `recordError` call that reached Firebase Crashlytics.
typedef CrashRecord = ({String exception, String? reason, bool fatal});

/// Stands in for Firebase Crashlytics and keeps every non-fatal or fatal
/// error it is asked to record.
class _RecordingFirebaseCrashlytics extends Fake
    implements FirebaseCrashlytics {
  final records = <CrashRecord>[];

  @override
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    dynamic reason,
    Iterable<Object> information = const [],
    bool? printDetails,
    bool fatal = false,
  }) async {
    records.add((
      exception: exception.toString(),
      reason: reason?.toString(),
      fatal: fatal,
    ));
  }
}

/// Routes [LoggerService]'s shared Crashlytics service to a recorder for the
/// current test. Call from `setUp` or a test body; it undoes itself when the
/// test ends.
List<CrashRecord> recordCrashReports() {
  final firebase = _RecordingFirebaseCrashlytics();
  // Tests run with kDebugMode == true, so reporting needs the debug override.
  CrashlyticsService.enableInDebugMode = true;
  LoggerService.crashlyticsServiceForTesting = CrashlyticsService(
    debugModeEnabled: true,
    crashlytics: firebase,
  );
  addTearDown(() {
    CrashlyticsService.enableInDebugMode = false;
    LoggerService.crashlyticsServiceForTesting = null;
  });
  return firebase.records;
}
