/// A28: `dataOf` must keep the previous data during a refresh (pull-to-
/// refresh) but stay pending during a reload caused by a dependency change,
/// such as a different signed-in user.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/async_value_utils.dart';

void main() {
  late StateProvider<String> user;
  late StreamProvider<int> source;
  late StreamController<int> pending;
  late ProviderContainer container;

  setUp(() {
    user = StateProvider<String>((ref) => 'a');
    var subscriptions = 0;
    pending = StreamController<int>();
    // The first subscription emits 1; later ones never emit.
    source = StreamProvider<int>((ref) {
      ref.watch(user);
      return subscriptions++ == 0 ? Stream.value(1) : pending.stream;
    });
    container = ProviderContainer(retry: (_, _) => null);
    container.listen(source, (_, _) {});
  });

  tearDown(() async {
    container.dispose();
    await pending.close();
  });

  Future<bool> completes(Future<int> future) async {
    var done = false;
    unawaited(future.then((_) => done = true));
    await pumpEventQueue();
    return done;
  }

  test('returns the previous data while the source is refreshing', () async {
    await pumpEventQueue();
    container.invalidate(source);
    await pumpEventQueue();

    final value = container.read(source);
    expect(value.isRefreshing, isTrue);
    expect(await dataOf(value), 1);
  });

  test('stays pending while a dependency change reloads the source', () async {
    await pumpEventQueue();
    container.read(user.notifier).state = 'b';
    await pumpEventQueue();

    final value = container.read(source);
    expect(value.isReloading, isTrue);
    expect(value.hasValue, isTrue);
    expect(await completes(dataOf(value)), isFalse);
  });
}
