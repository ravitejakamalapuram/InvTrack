import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Permanently deletes EVERYTHING stored for a user under `users/{uid}` in
/// Cloud Firestore, and only reports success once the server has confirmed it.
///
/// Why this exists: the regular repositories use an offline-first write
/// pattern (`_executeWrite`) that treats a timed-out write as "cached locally,
/// will sync later". That is right for normal edits but wrong for account
/// deletion: the Firebase Auth account is deleted right after the data, and
/// Firestore security rules require `request.auth.uid == userId`, so any
/// deletion still queued offline could never be applied afterwards and the
/// data would stay on the server forever.
///
/// Preferred path: [serverDelete] calls the `deleteUserData` Cloud Function,
/// which recursively deletes `users/{uid}` on the server (including
/// subcollections this client does not know about) and runs to completion even
/// if the phone disconnects; retrying it resumes where it stopped. If that
/// function is not deployed ([ServerDeletionUnavailableException]), the
/// client-side path below is used instead, exactly as before.
///
/// The client-side fallback:
///  * reads each collection from the SERVER (not the local cache), so it also
///    finds documents this device never synced (e.g. orphaned cash flows);
///  * deletes in batches of at most [batchSize] (Firestore limit is 500);
///  * awaits each batch commit with a timeout - a commit only completes once
///    the server has acknowledged it, so a timeout means "not confirmed";
///  * throws [NetworkException] on timeout/offline instead of swallowing it.
///
/// Callers MUST NOT delete the Auth account (or report success) unless
/// [deleteAllServerData] completes normally.
class AccountDataDeletionService {
  AccountDataDeletionService({
    required FirebaseFirestore firestore,
    required String userId,
    Future<void> Function()? serverDelete,
    this.batchSize = 500,
    this.confirmTimeout = const Duration(seconds: 20),
  }) : assert(batchSize > 0 && batchSize <= 500),
       _firestore = firestore,
       _userId = userId,
       _serverDelete = serverDelete;

  final FirebaseFirestore _firestore;
  final String _userId;

  /// Server-side recursive delete (see [CallableAccountDataDeleter]). Must
  /// complete only once the server confirmed, throw [NetworkException] when
  /// unreachable, and throw [ServerDeletionUnavailableException] when the
  /// function is not deployed. Null = client-side deletion only.
  final Future<void> Function()? _serverDelete;

  /// Max writes per batch (Firestore hard limit is 500).
  final int batchSize;

  /// How long to wait for the server before treating the step as unconfirmed.
  final Duration confirmTimeout;

  /// Every subcollection the app writes under `users/{uid}`.
  ///
  /// Keep in sync with the Firestore repositories in `lib/features/**/data`
  /// and `lib/core/services/currency_conversion_service.dart`. A unit test
  /// asserts that each of these is emptied.
  static const List<String> userCollections = [
    'investments',
    'cashflows',
    'archivedInvestments',
    'archivedCashflows',
    'goals',
    'archivedGoals',
    'expectedCashFlows',
    'documents',
    'healthScores',
    'fireSettings',
    'profile',
    'exchangeRates',
  ];

  /// Per-user data cached in SharedPreferences (sample-data bookkeeping and
  /// exchange-rate cache timestamps). App-wide settings such as theme or
  /// notification toggles are not user financial data and are left alone.
  static const List<String> userPreferenceKeys = [
    'sample_data_mode_active',
    'sample_data_investment_ids',
    'sample_data_goal_ids',
    'last_live_cache_refresh',
    'currency_live_cache_last_refresh',
  ];

  /// Full deletion: server data first (must be confirmed), then local files
  /// and preferences. If the server step fails, NOTHING local is touched and
  /// the exception propagates so the caller can tell the user deletion did
  /// not happen and must not delete the Auth account.
  Future<void> deleteEverything({
    required Future<void> Function() deleteLocalFiles,
    required SharedPreferences prefs,
  }) async {
    await deleteAllServerData();
    await deleteLocalFiles();
    for (final key in userPreferenceKeys) {
      await prefs.remove(key);
    }
  }

  /// Deletes all user data on the server. Throws on any failure or when the
  /// server cannot be reached; completes only when everything is confirmed.
  Future<void> deleteAllServerData() async {
    final serverDelete = _serverDelete;
    if (serverDelete != null) {
      try {
        await serverDelete();
        LoggerService.info('Account data deletion complete on server');
        return;
      } on ServerDeletionUnavailableException {
        LoggerService.warn(
          'deleteUserData function unavailable; deleting from the client',
        );
      }
    }
    await _deleteFromClient();
  }

  Future<void> _deleteFromClient() async {
    final userDoc = _firestore.collection('users').doc(_userId);

    for (final name in userCollections) {
      await _deleteCollection(userDoc.collection(name), name);
    }

    // Finally the (possibly non-existent) parent user document itself.
    final batch = _firestore.batch();
    batch.delete(userDoc);
    await _confirm(batch.commit(), 'users/$_userId');
    LoggerService.info('Account data deletion complete on server');
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
    String name,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _confirm(
      collection.get(const GetOptions(source: Source.server)),
      name,
    );
    final refs = snapshot.docs.map((d) => d.reference).toList();

    for (var i = 0; i < refs.length; i += batchSize) {
      final end = (i + batchSize < refs.length) ? i + batchSize : refs.length;
      final batch = _firestore.batch();
      for (var j = i; j < end; j++) {
        batch.delete(refs[j]);
      }
      await _confirm(batch.commit(), name);
    }
  }

  Future<T> _confirm<T>(Future<T> operation, String what) async {
    try {
      return await operation.timeout(confirmTimeout);
    } on TimeoutException catch (e, st) {
      LoggerService.warn('Deletion of $what not confirmed (timeout)');
      throw NetworkException.noConnection(cause: e, stackTrace: st);
    } on FirebaseException catch (e, st) {
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        throw NetworkException.noConnection(cause: e, stackTrace: st);
      }
      rethrow;
    }
  }
}

/// The server-side deletion function is not deployed (or not reachable by
/// name), so the caller should fall back to client-side deletion.
class ServerDeletionUnavailableException implements Exception {
  const ServerDeletionUnavailableException(this.code);
  final String code;

  @override
  String toString() => 'ServerDeletionUnavailableException($code)';
}
