// A112: auto-lock and the PIN lockout use a trusted, sleep-inclusive clock.
// Production never falls back to a sleep-unaware stopwatch.
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

  test('an explicitly injected stopwatch is test-only and deterministic', () async {
    final clock = SecurityClock(stopwatch: stopwatch);

    expect(await clock.elapsed(), const Duration(seconds: 7));
    expect(clock.isBootClock, isFalse);

    stopwatch.value = const Duration(seconds: 9);
    expect(await clock.elapsed(), const Duration(seconds: 9));
    expect(calls, isEmpty);
  });

  test('channel failure fails closed instead of using a stopwatch', () async {
    answer(() => throw PlatformException(code: 'ERROR'));

    final clock = SecurityClock();

    await expectLater(
      clock.elapsed(),
      throwsA(isA<SecurityClockUnavailable>()),
    );
    expect(calls, ['elapsedRealtime']);
  });

  test('an empty channel answer also fails closed', () async {
    answer(() => null);

    await expectLater(
      SecurityClock().elapsed(),
      throwsA(isA<SecurityClockUnavailable>()),
    );
  });
}

class _ManualStopwatch extends Stopwatch {
  Duration value = Duration.zero;

  @override
  Duration get elapsed => value;
}
