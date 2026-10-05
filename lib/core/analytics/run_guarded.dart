import 'dart:async';

import 'package:inv_tracker/core/analytics/crashlytics_service.dart';

/// Runs the app so that every uncaught error reaches [service]: async errors
/// through the guarded zone, framework errors through `FlutterError.onError`
/// and platform errors through `PlatformDispatcher.onError`.
///
/// The global handlers are installed before [body] runs, so an error while
/// drawing the first frame is reported too.
void runGuarded(
  Future<void> Function() body, {
  required CrashlyticsService service,
}) {
  CrashlyticsService.installGlobalHandlers(service);
  runZonedGuarded(body, service.handleZoneError);
}
