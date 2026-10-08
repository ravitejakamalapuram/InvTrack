// A113: start-up prompts wait for the app lock before they open.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/security/wait_until_unlocked.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';

void main() {
  final results = <bool>[];

  setUp(results.clear);

  Widget app({required bool locked, int waiters = 1}) => ProviderScope(
    overrides: [
      securityProvider.overrideWith(() => _TestSecurity(locked: locked)),
    ],
    child: _Waiter(waiters: waiters, results: results),
  );

  _TestSecurity security(WidgetTester tester) =>
      ProviderScope.containerOf(
            tester.element(find.byType(_Waiter)),
          ).read(securityProvider.notifier)
          as _TestSecurity;

  testWidgets('not locked: true at once', (tester) async {
    await tester.pumpWidget(app(locked: false));
    await tester.pump();

    expect(results, [true]);
  });

  testWidgets('locked: waits, then true for every waiter on unlock', (
    tester,
  ) async {
    await tester.pumpWidget(app(locked: true, waiters: 2));
    await tester.pump();
    expect(results, isEmpty);

    security(tester).unlock();
    await tester.pump();

    expect(results, [true, true]);
  });

  testWidgets('removed while locked: false for every waiter', (tester) async {
    await tester.pumpWidget(app(locked: true, waiters: 2));
    await tester.pump();

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(results, [false, false]);
    expect(tester.takeException(), isNull);
  });
}

class _Waiter extends ConsumerStatefulWidget {
  const _Waiter({required this.waiters, required this.results});

  final int waiters;
  final List<bool> results;

  @override
  ConsumerState<_Waiter> createState() => _WaiterState();
}

class _WaiterState extends ConsumerState<_Waiter> with WaitsForUnlock {
  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.waiters; i++) {
      waitUntilUnlocked().then(widget.results.add);
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _TestSecurity extends SecurityNotifier {
  _TestSecurity({required this.locked});

  final bool locked;

  @override
  SecurityState build() => SecurityState(hasPin: locked, isLocked: locked);

  void unlock() => state = state.copyWith(isLocked: false);
}
