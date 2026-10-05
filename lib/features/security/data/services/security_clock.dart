import 'package:flutter/services.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';

/// Time source for auto-lock and the PIN lockout.
///
/// Reads Android's `SystemClock.elapsedRealtime()`: time since the phone
/// started, deep sleep included. Whoever holds the phone cannot change it,
/// unlike the wall clock, so moving the device clock can neither skip nor
/// force a lock. It restarts at zero when the phone restarts.
///
/// Where the channel is missing or fails (other platforms, tests), it falls
/// back to a stopwatch for the rest of this run. The stopwatch cannot be
/// changed either, but it stops while the phone sleeps and restarts with the
/// app, so it can only count less time, never more.
class SecurityClock {
  SecurityClock({
    MethodChannel channel = const MethodChannel('com.invtracker/security'),
    Stopwatch? stopwatch,
  }) : _channel = channel,
       _stopwatch = stopwatch ?? (Stopwatch()..start());

  final MethodChannel _channel;
  final Stopwatch _stopwatch;
  bool _useStopwatch = false;

  /// The current reading. Readings are only comparable with each other.
  Future<Duration> elapsed() async {
    if (!_useStopwatch) {
      try {
        final ms = await _channel.invokeMethod<int>('elapsedRealtime');
        if (ms != null) return Duration(milliseconds: ms);
      } catch (e) {
        LoggerService.warn(
          'Boot clock unavailable; using a stopwatch',
          metadata: {'errorType': e.runtimeType.toString()},
        );
      }
      _useStopwatch = true;
    }
    return _stopwatch.elapsed;
  }

  /// Whether readings come from the boot clock; false once this run has
  /// fallen back to the stopwatch. Readings from the two are not comparable.
  bool get isBootClock => !_useStopwatch;

  /// The device clock. Whoever holds the phone can set it, so it only judges
  /// what the readings cannot: a PIN lockout from before a phone restart,
  /// from the stopwatch, or from an older version.
  DateTime wallTime() => DateTime.now();
}
