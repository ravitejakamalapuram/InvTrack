import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';
import 'package:inv_tracker/features/investment/domain/repositories/valuation_repository.dart';

/// Removes, at most once per session, the valuation snapshots
/// (`users/{uid}/valuations`) of investments that no longer exist (#964).
///
/// An investment deleted while offline deletes the snapshots this device has
/// cached; any it never cached (the flag was off, or the values came from a
/// restored backup) stay on the server. They are harmless residue, but this
/// sweep removes them.
///
/// A snapshot is judged only on the server's word. The sweep waits until both
/// the investments and the valuations are server-confirmed (no cache answer,
/// no pending write of this device), so a partially loaded list never makes a
/// valid snapshot look orphaned. The two answers can still arrive at
/// different times (another device may have created an investment after the
/// investments answer), so each candidate's investment is read once more from
/// the server, in `investments` and `archivedInvestments`, before anything is
/// deleted. Snapshots of archived investments are kept, and cleared
/// (soft-deleted) snapshots of a missing investment are removed with the rest.
/// A snapshot with no investment id is left alone: there is nothing to check
/// it against.
///
/// Nothing is deleted when any step fails, and a failed run does not count:
/// the next call tries again. [cancel] (sign-out, account switch) ends a run
/// that is waiting on the server and closes its listeners; a cancelled
/// service never runs again.
class OrphanedValuationCleanupService {
  OrphanedValuationCleanupService({
    required FirebaseFirestore firestore,
    required String userId,
    required InvestmentRepository investmentRepository,
    required ValuationRepository valuationRepository,
    Duration readTimeout = const Duration(seconds: 20),
    Duration writeTimeout = const Duration(seconds: 3),
  }) : _firestore = firestore,
       _userId = userId,
       _investmentRepository = investmentRepository,
       _valuationRepository = valuationRepository,
       _readTimeout = readTimeout,
       _writeTimeout = writeTimeout;

  /// Deletes per batch (the Firestore limit is 500).
  static const int _batchSize = 450;

  /// Investments checked on the server at the same time. Each one is two
  /// reads.
  static const int _checkChunkSize = 50;

  final FirebaseFirestore _firestore;
  final String _userId;
  final InvestmentRepository _investmentRepository;
  final ValuationRepository _valuationRepository;
  final Duration _readTimeout;
  final Duration _writeTimeout;
  bool _done = false;
  bool _cancelled = false;
  final Completer<void> _cancelSignal = Completer<void>();
  Future<bool>? _running;

  /// Stops this service for good: a run that is waiting for the server ends
  /// without deleting anything, and later calls to [runOnce] return false.
  void cancel() {
    _cancelled = true;
    if (!_cancelSignal.isCompleted) _cancelSignal.complete();
  }

  void _throwIfCancelled() {
    if (_cancelled) throw const _SweepCancelled();
  }

  /// Runs [cleanup] unless it already finished in this session. Returns true
  /// when it is finished, false when it failed (the next call runs again).
  /// Calls made while a run is going share it. Never throws.
  Future<bool> runOnce() {
    if (_cancelled) return Future.value(false);
    if (_done) return Future.value(true);
    return _running ??= _runGuarded().whenComplete(() {
      _running = null;
    });
  }

  Future<bool> _runGuarded() async {
    try {
      await cleanup();
      return true;
    } on _SweepCancelled {
      return false;
    } catch (e) {
      LoggerService.warn(
        'Valuation snapshot cleanup did not finish; will retry',
        metadata: {'errorType': e.runtimeType.toString()},
      );
      return false;
    }
  }

  /// Waits for the server-confirmed investments and valuations, deletes the
  /// orphaned snapshots and returns how many. Throws if a read or a delete
  /// fails or is not confirmed by the server in time; batches that already
  /// went through stay deleted, which is safe, because orphans are found
  /// afresh on the next run.
  Future<int> cleanup() async {
    final subscriptions = <StreamSubscription<Object?>>[];
    Future<T> firstOf<T>(Stream<T> stream) {
      final completer = Completer<T>();
      subscriptions.add(
        stream.listen(
          (value) {
            if (!completer.isCompleted) completer.complete(value);
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!completer.isCompleted) {
              completer.completeError(error, stackTrace);
            }
          },
        ),
      );
      return completer.future;
    }

    final Set<String> investmentIds;
    final List<InvestmentValuationSnapshot> snapshots;
    try {
      final ids = firstOf(
        _investmentRepository.watchServerConfirmedInvestmentIds(),
      );
      final valuations = firstOf(_valuationRepository.watchServerConfirmed());
      await Future.any<void>([
        Future.wait<Object>([ids, valuations], eagerError: true),
        _cancelSignal.future,
      ]);
      _throwIfCancelled();
      investmentIds = await ids;
      snapshots = await valuations;
    } finally {
      for (final subscription in subscriptions) {
        unawaited(subscription.cancel());
      }
    }

    _throwIfCancelled();
    final candidates = <String, List<String>>{};
    for (final snapshot in snapshots) {
      final investmentId = snapshot.investmentId;
      if (investmentId.trim().isEmpty || investmentIds.contains(investmentId)) {
        continue;
      }
      (candidates[investmentId] ??= []).add(snapshot.id);
    }

    final userDoc = _firestore.collection('users').doc(_userId);
    final ids = candidates.keys.toList();
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

    _throwIfCancelled();
    final orphans = <DocumentReference>[];
    final valuations = userDoc.collection('valuations');
    var index = 0;
    for (final snapshotIds in candidates.values) {
      if (!exists[index++]) {
        orphans.addAll(snapshotIds.map(valuations.doc));
      }
    }

    for (var i = 0; i < orphans.length; i += _batchSize) {
      _throwIfCancelled();
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

    _done = true;
    // Counts only: never ids, names or amounts (CLAUDE.md rule 7).
    LoggerService.info(
      'Valuation snapshot cleanup finished',
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

class _SweepCancelled implements Exception {
  const _SweepCancelled();
}
