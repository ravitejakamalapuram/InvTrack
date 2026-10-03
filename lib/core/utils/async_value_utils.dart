import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The data in [value], as a future for use inside a `FutureProvider` that
/// `ref.watch`es [value].
///
/// If [value] holds an error the future fails with it, so the provider shows
/// the error. This includes an error that Riverpod is retrying, which is an
/// `AsyncLoading` that still carries the error: treating it as loading would
/// keep screens on skeletons for as long as the retries last. While [value]
/// is otherwise loading the future never completes, so the provider stays
/// loading; it is rebuilt, and the pending future dropped, once [value]
/// changes. Never substitute an empty list for these states: screens would
/// show "no data" to users who have data.
Future<T> dataOf<T>(AsyncValue<T> value) {
  if (value.hasError) {
    return Future<T>.error(value.error!, value.stackTrace);
  }
  if (value.isLoading) return Completer<T>().future;
  return Future<T>.value(value.requireValue);
}

/// [value], but an error is reported as an error even while Riverpod retries
/// it (an `AsyncLoading` that still carries the error), so screens show the
/// error and a retry action instead of loading indefinitely.
AsyncValue<T> errorFirst<T>(AsyncValue<T> value) {
  if (!value.hasError) return value;
  return AsyncValue<T>.error(
    value.error!,
    value.stackTrace ?? StackTrace.current,
  );
}
