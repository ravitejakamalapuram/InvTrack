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

  /// Investments checked on the server at the same time. Each one is two
  /// reads.
  static const int _checkChunkSize = 50;

  final FirebaseFirestore _firestore;
  final String _userId;
  final SharedPreferences _prefs;
  final Duration _readTimeout;
  final Duration _writeTimeout;
  Future<bool>? _running;

  /// Every SharedPreferences key this service keeps for [userId]. Removed on
  /// account deletion.
  static List<String> prefsKeysFor(String userId) => [
    _requestedKeyFor(userId),
    _completedKeyFor(userId),
  ];

  // Two counters, so a sweep asked for during a run is not lost: a run
  // records the request number it started with, never a later one.
  static String _requestedKeyFor(String userId) =>
      'expected_payments_orphan_sweep_requested_$userId';

  static String _completedKeyFor(String userId) =>
      'expected_payments_orphan_sweep_completed_$userId';

  /// The first sweep is always owed: request 1, nothing completed yet.
  static int _requestedOf(SharedPreferences prefs, String userId) =>
      prefs.getInt(_requestedKeyFor(userId)) ?? 1;

  static int _completedOf(SharedPreferences prefs, String userId) =>
      prefs.getInt(_completedKeyFor(userId)) ?? 0;

  /// Makes [runOnce] of [userId] sweep again, even if one finished, or is
  /// running now.
  ///
  /// Asked for when an investment was deleted without the server saying which
  /// expected payments it had (offline with an empty cache): those payments
  /// stay on the server and only a new sweep can remove them.
  static Future<void> requestSweep(SharedPreferences prefs, String userId) =>
      prefs.setInt(_requestedKeyFor(userId), _requestedOf(prefs, userId) + 1);

  /// Whether the cleanup finished for this user, for the latest request.
  bool get isComplete =>
      _completedOf(_prefs, _userId) >= _requestedOf(_prefs, _userId);

  /// Runs [cleanup] once per user. Returns true when it is complete, false
  /// when it failed or a newer sweep was asked for meanwhile (the next call
  /// runs again). Never throws.
  Future<bool> runOnce() {
    if (isComplete) return Future.value(true);
    return _running ??= _runGuarded().whenComplete(() {
      _running = null;
    });
  }

  Future<bool> _runGuarded() async {
    try {
      await cleanup();
      return isComplete;
    } catch (e) {
      LoggerService.warn(
        'Expected payment cleanup did not finish; will retry',
        metadata: {'errorType': e.runtimeType.toString()},
      );
      return false;
    }
  }

  /// Deletes the orphaned payments and returns how many. Throws if a read or
  /// a delete fails or is not confirmed by the server in time, and then
  /// nothing is recorded, so the next call starts again; batches that already
  /// went through stay deleted, which is safe, because the orphans are found
  /// afresh. Completion is recorded only after every batch was confirmed, and
  /// only for the request that was current when this started.
  Future<int> cleanup() async {
    final requested = _requestedOf(_prefs, _userId);
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
    // still found. A chunk at a time, so many investments do not start
    // hundreds of reads at once under one timeout.
    final ids = byInvestment.keys.toList();
    final exists = <bool>[];
    for (var i = 0; i < ids.length; i += _checkChunkSize) {
      exists.addAll(
        await Future.wait([
          for (final id in ids.sublist(
            i,
            math.min(i + _checkChunkSize, ids.length),
          ))
            _investmentExists(userDoc, id),
        ]).timeout(_readTimeout),
      );
    }
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
      // A timeout is not swallowed: until the server confirms, the sweep is
      // not done. The write stays queued; deleting it again later is harmless.
      await batch.commit().timeout(_writeTimeout);
    }

    await _prefs.setInt(
      _completedKeyFor(_userId),
      math.max(_completedOf(_prefs, _userId), requested),
    );
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
