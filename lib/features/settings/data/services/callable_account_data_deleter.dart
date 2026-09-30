import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/features/settings/data/services/account_data_deletion_service.dart';

/// Calls the `deleteUserData` Cloud Function (functions/src/deleteUserData.ts),
/// which recursively deletes everything under `users/{uid}` for the signed-in
/// caller. Used as [AccountDataDeletionService]'s `serverDelete`.
///
/// Completes only when the function returned `{deleted: true}`. Errors are
/// mapped so the service can decide what to do:
///  * function not deployed -> [ServerDeletionUnavailableException] (fallback);
///  * offline / timed out   -> [NetworkException] (retry later; safe, the
///    server-side delete is idempotent and resumes where it stopped);
///  * anything else         -> rethrown.
class CallableAccountDataDeleter {
  CallableAccountDataDeleter({
    HttpsCallable Function()? callable,
    this.timeout = const Duration(seconds: 120),
  }) : _callable =
           callable ??
           (() => FirebaseFunctions.instance.httpsCallable(
             functionName,
             options: HttpsCallableOptions(timeout: timeout),
           ));

  static const functionName = 'deleteUserData';

  final HttpsCallable Function() _callable;

  /// How long to wait for the function before treating it as unconfirmed.
  final Duration timeout;

  Future<void> call() async {
    final HttpsCallableResult<dynamic> result;
    try {
      result = await _callable().call<dynamic>().timeout(
        timeout + const Duration(seconds: 5),
      );
    } on TimeoutException catch (e, st) {
      throw NetworkException.noConnection(cause: e, stackTrace: st);
    } on FirebaseFunctionsException catch (e, st) {
      throw mapError(e, st);
    }

    final data = result.data;
    if (data is! Map || data['deleted'] != true) {
      throw StateError('$functionName returned an unexpected result: $data');
    }
  }

  /// Maps a callable error to what [AccountDataDeletionService] expects.
  static Object mapError(FirebaseFunctionsException e, StackTrace st) {
    switch (e.code) {
      case 'not-found':
      case 'unimplemented':
        return ServerDeletionUnavailableException(e.code);
      case 'unavailable':
      case 'deadline-exceeded':
        return NetworkException.noConnection(cause: e, stackTrace: st);
      default:
        return e;
    }
  }
}
