// A112: auto-lock and the PIN lockout read Android's boot clock
// (SystemClock.elapsedRealtime), which counts deep sleep and cannot be set
// by whoever holds the phone.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/security/data/services/security_clock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.invtracker/security');
  late List<String> calls;
  late _ManualStopwatch stopwatch;

  void answer(Object? Function() reply) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return reply();
        });
  }

  setUp(() {
    calls = [];
    stopwatch = _ManualStopwatch()..value = const Duration(seconds: 7);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('reads elapsedRealtime from the security channel', () async {
    answer(() => 2800000);
    final clock = SecurityClock(stopwatch: stopwatch);

    expect(await clock.elapsed(), const Duration(milliseconds: 2800000));
    expect(calls, ['elapsedRealtime']);
  });

  test('without the channel, uses the stopwatch and stops asking', () async {
    final clock = SecurityClock(stopwatch: stopwatch);

    expect(await clock.elapsed(), const Duration(seconds: 7));
    answer(() => 2800000);
    stopwatch.value = const Duration(seconds: 9);
    // One timeline per run: once on the stopwatch, it stays there.
    expect(await clock.elapsed(), const Duration(seconds: 9));
    expect(calls, isEmpty);
  });

  test(
    'a channel error or an empty answer falls back to the stopwatch',
    () async {
      answer(() => throw PlatformException(code: 'ERROR'));
      expect(
        await SecurityClock(stopwatch: stopwatch).elapsed(),
        const Duration(seconds: 7),
      );

      answer(() => null);
      expect(
        await SecurityClock(stopwatch: stopwatch).elapsed(),
        const Duration(seconds: 7),
      );
      expect(calls, ['elapsedRealtime', 'elapsedRealtime']);
    },
  );
}

class _ManualStopwatch extends Stopwatch {
  Duration value = Duration.zero;

  @override
  Duration get elapsed => value;
}
