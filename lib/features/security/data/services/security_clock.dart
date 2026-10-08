import 'package:flutter/services.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';

/// Time source for auto-lock and the PIN lockout.
///
/// Production reads Android's SystemClock.elapsedRealtime() through the
/// security channel. Android's clock includes deep sleep. iOS provides the
/// same contract through mach_continuous_time().
///
/// A stopwatch is accepted only when explicitly injected by tests. Production
/// never silently falls back to a sleep-unaware clock: if the trusted clock
/// cannot be read, callers must fail closed.
class SecurityClock {
  SecurityClock({
    MethodChannel channel = const MethodChannel('com.invtracker/security'),
    Stopwatch? stopwatch,
  }) : _channel = channel,
       _testStopwatch = stopwatch;

  final MethodChannel _channel;
  final Stopwatch? _testStopwatch;

  /// The current reading. Readings are only comparable with each other.
  Future<Duration> elapsed() async {
    final testStopwatch = _testStopwatch;
    if (testStopwatch != null) return testStopwatch.elapsed;

    try {
      final ms = await _channel.invokeMethod<int>('elapsedRealtime');
      if (ms != null) return Duration(milliseconds: ms);
      throw const SecurityClockUnavailable('Trusted clock returned no value');
    } catch (e, st) {
      LoggerService.warn(
        'Trusted security clock unavailable',
        metadata: {'errorType': e.runtimeType.toString()},
      );
      if (e is SecurityClockUnavailable) {
        Error.throwWithStackTrace(e, st);
      }
      Error.throwWithStackTrace(
        SecurityClockUnavailable('Trusted clock invocation failed'),
        st,
      );
    }
  }

  /// Whether readings come from a trusted boot/continuous clock.
  ///
  /// Explicit test stopwatches are deliberately not considered trusted.
  bool get isBootClock => _testStopwatch == null;

  /// The device clock. Kept only for legacy lockout migration paths.
  DateTime wallTime() => DateTime.now();
}

class SecurityClockUnavailable implements Exception {
  const SecurityClockUnavailable(this.message);

  final String message;

  @override
  String toString() => 'SecurityClockUnavailable: $message';
}
