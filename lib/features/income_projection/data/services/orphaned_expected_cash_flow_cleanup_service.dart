import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Removes, once, the expected payments (`users/{uid}/expectedCashFlows`) of
/// investments that no longer exist (#917).
///
/// Deleting an investment now deletes its expected payments with it. Older
/// builds did not, and a restore can bring payments back for an investment
/// deleted since. Left alone they would reach the income calendar, the trend
/// analyser and Income Guardian once that feature is turned on, so this runs
/// first, when Income Guardian starts.
///
/// A payment is an orphan only when the server says that neither
/// `investments/{id}` nor `archivedInvestments/{id}` exists. Nothing is
/// judged from the local cache, which is empty on a fresh install or after an
/// account switch and would make every payment look orphaned, and nothing is
/// deleted when any read fails: offline, the next start retries. Payments with
/// no `investmentId` are left alone, since there is nothing to check them
/// against.
class OrphanedExpectedCashFlowCleanupService {
  OrphanedExpectedCashFlowCleanupService({
    required FirebaseFirestore firestore,
    required String userId,
    required SharedPreferences prefs,
    Duration readTimeout = const Duration(seconds: 20),
    Duration writeTimeout = const Duration(seconds: 3),
  }) : _firestore = firestore,
       _userId = userId,
       _prefs = prefs,
       _readTimeout = readTimeout,
       _writeTimeout = writeTimeout;

  /// Deletes per batch (the Firestore limit is 500).
  static const int _batchSize = 450;

  final FirebaseFirestore _firestore;
  final String _userId;
  final SharedPreferences _prefs;
  final Duration _readTimeout;
  final Duration _writeTimeout;
  Future<bool>? _running;

  String get _doneKey => 'expected_payments_orphan_cleanup_done_$_userId';

  /// Whether the cleanup finished for this user.
  bool get isComplete => _prefs.getBool(_doneKey) ?? false;

  /// Runs [cleanup] once per user. Returns true when it is complete, false
  /// when it failed (the next call retries). Never throws.
  Future<bool> runOnce() {
    if (isComplete) return Future.value(true);
    return _running ??= _runGuarded().whenComplete(() {
      _running = null;
    });
  }

  Future<bool> _runGuarded() async {
    try {
      await cleanup();
      return true;
    } catch (e) {
      LoggerService.warn(
        'Expected payment cleanup did not finish; will retry',
        metadata: {'errorType': e.runtimeType.toString()},
      );
      return false;
    }
  }

  /// Deletes the orphaned payments and returns how many. Throws if a read or
  /// a delete fails, and then nothing is recorded, so the next call starts
  /// again; batches that already went through stay deleted, which is safe,
  /// because the orphans are found afresh. Completion is recorded only after
  /// every batch went through.
  Future<int> cleanup() async {
    final userDoc = _firestore.collection('users').doc(_userId);
    final payments = await userDoc
        .collection('expectedCashFlows')
        .get(const GetOptions(source: Source.server))
        .timeout(_readTimeout);

    final byInvestment = <String, List<DocumentReference>>{};
    for (final doc in payments.docs) {
      final investmentId = doc.data()['investmentId'];
      if (investmentId is! String || investmentId.trim().isEmpty) continue;
      (byInvestment[investmentId] ??= []).add(doc.reference);
    }

    // One fresh read per investment, after the payments were read, so an
    // investment created or moved between archive and active meanwhile is
    // still found.
    final exists = await Future.wait([
      for (final id in byInvestment.keys) _investmentExists(userDoc, id),
    ]).timeout(_readTimeout);
    final orphans = <DocumentReference>[];
    var index = 0;
    for (final refs in byInvestment.values) {
      if (!exists[index++]) orphans.addAll(refs);
    }

    for (var i = 0; i < orphans.length; i += _batchSize) {
      final batch = _firestore.batch();
      for (final ref in orphans.sublist(
        i,
        math.min(i + _batchSize, orphans.length),
      )) {
        batch.delete(ref);
      }
      try {
        await batch.commit().timeout(_writeTimeout);
      } on TimeoutException {
        // Queued locally while offline, and sent when back online, like every
        // other write in the app.
      }
    }

    await _prefs.setBool(_doneKey, true);
    // Counts only: never ids, names or amounts (CLAUDE.md rule 7).
    LoggerService.info(
      'Expected payment cleanup finished',
      metadata: {'removed': orphans.length},
    );
    return orphans.length;
  }

  Future<bool> _investmentExists(
    DocumentReference<Map<String, dynamic>> userDoc,
    String investmentId,
  ) async {
    const server = GetOptions(source: Source.server);
    final found = await Future.wait([
      userDoc.collection('investments').doc(investmentId).get(server),
      userDoc.collection('archivedInvestments').doc(investmentId).get(server),
    ]);
    return found.any((snapshot) => snapshot.exists);
  }
}
