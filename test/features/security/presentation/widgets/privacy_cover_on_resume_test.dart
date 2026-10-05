// A112: the auto-lock check on resume waits for the boot clock, which
// answers over a platform channel. Until it has decided, the privacy cover
// must stay up: a frame drawn in between would show the portfolio, and take
// taps, before the lock.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/features/security/data/services/security_clock.dart';
import 'package:inv_tracker/features/security/data/services/security_service.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/security/presentation/widgets/privacy_protection_wrapper.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/mock_analytics_service.dart';
import '../../../../mocks/mock_security_service.dart';

void main() {
  late _SlowClock clock;

  Finder cover() => find.byWidgetPredicate(
    (widget) =>
        widget is Positioned &&
        widget.left == 0 &&
        widget.right == 0 &&
        widget.top == 0 &&
        widget.bottom == 0,
  );

  /// PIN set, auto-lock after 60 s; left at boot time 1,000 s.
  Future<void> leaveWithPin(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'auto_lock_duration': 60});
    final prefs = await SharedPreferences.getInstance();
    clock = _SlowClock();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          securityClockProvider.overrideWithValue(clock),
          securityServiceProvider.overrideWithValue(
            SecurityService(
              FakeFlutterSecureStorage(),
              FakeLocalAuthentication(),
              prefs,
              clock,
            ),
          ),
          analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        ],
        child: MaterialApp(
          home: PrivacyProtectionWrapper(
            child: Scaffold(
              body: Consumer(
                builder: (_, ref, _) => Text(
                  ref.watch(securityProvider).isLocked
                      ? 'Lock screen'
                      : 'Portfolio',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await ProviderScope.containerOf(
      tester.element(find.byType(PrivacyProtectionWrapper)),
    ).read(securityProvider.notifier).setPin('1234');
    await tester.pump();
    expect(find.text('Portfolio').hitTestable(), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(cover(), findsOneWidget);
    // No frames are drawn while paused.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  }

  testWidgets('away past the auto-lock: the first frame after resume shows '
      'the cover, not the portfolio, until the lock lands', (tester) async {
    await leaveWithPin(tester);
    clock.now += const Duration(seconds: 120);
    clock.slow = true;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(cover(), findsOneWidget);
    expect(find.text('Portfolio').hitTestable(), findsNothing);

    clock.answer();
    await tester.pumpAndSettle();

    expect(find.text('Lock screen'), findsOneWidget);
    expect(cover(), findsNothing);
  });

  testWidgets('back within the auto-lock: the cover lifts once the check '
      'has decided', (tester) async {
    await leaveWithPin(tester);
    clock.now += const Duration(seconds: 10);
    clock.slow = true;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(cover(), findsOneWidget);

    clock.answer();
    await tester.pumpAndSettle();

    expect(cover(), findsNothing);
    expect(find.text('Portfolio').hitTestable(), findsOneWidget);
  });
}

/// Boot clock that tests move by hand. While [slow], readings wait for
/// [answer], like a platform channel whose main thread is busy.
class _SlowClock extends SecurityClock {
  Duration now = const Duration(seconds: 1000);
  bool slow = false;
  final _pending = <Completer<void>>[];

  void answer() {
    slow = false;
    for (final reading in _pending) {
      reading.complete();
    }
    _pending.clear();
  }

  @override
  Future<Duration> elapsed() async {
    if (slow) {
      final reading = Completer<void>();
      _pending.add(reading);
      await reading.future;
    }
    return now;
  }
}
