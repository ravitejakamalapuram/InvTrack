import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The data in [value], as a future for use inside a `FutureProvider` that
/// `ref.watch`es [value].
///
/// While [value] is loading the future never completes, so the provider stays
/// loading; it is rebuilt, and the pending future dropped, once [value]
/// changes. If [value] holds an error the future fails with it, so the
/// provider shows the error. Never substitute an empty list for these states:
/// screens would show "no data" to users who have data.
Future<T> dataOf<T>(AsyncValue<T> value) {
  if (value.isLoading) return Completer<T>().future;
  if (value.hasError) {
    return Future<T>.error(value.error!, value.stackTrace);
  }
  return Future<T>.value(value.requireValue);
}
