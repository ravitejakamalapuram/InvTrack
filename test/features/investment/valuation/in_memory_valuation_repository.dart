// In-memory ValuationRepository for the dated-valuation tests (#941).
import 'dart:async';

import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';
import 'package:inv_tracker/features/investment/domain/repositories/valuation_repository.dart';

/// In-memory [ValuationRepository] that applies a [CompatMirror] to a mirror
/// map, so tests can assert that snapshot and compat change together.
class InMemoryValuationRepository implements ValuationRepository {
  final Map<String, InvestmentValuationSnapshot> docs = {};

  /// investmentId -> (value, date) as the investment document would read.
  final Map<String, ({double? value, DateTime? date})> mirrors = {};

  /// Writes (save, softDelete, restore) and imports, in order.
  final List<String> log = [];

  final _controller =
      StreamController<List<InvestmentValuationSnapshot>>.broadcast();
  var watchCount = 0;

  /// Makes the next write throw, applying nothing (an atomic batch).
  Object? failNextWrite;

  /// When set, save, softDelete and restore store the document with this
  /// update time, as Firestore's server timestamp does, and the next write is
  /// stamped a second later: writes reach the server in order. Left null, a
  /// write stores the snapshot as given.
  DateTime? serverTime;

  InvestmentValuationSnapshot _stamped(InvestmentValuationSnapshot s) {
    final at = serverTime;
    if (at == null) return s;
    serverTime = at.add(const Duration(seconds: 1));
    return s.copyWith(updatedAt: at);
  }

  void _applyMirror(CompatMirror mirror) {
    mirrors[mirror.investmentId] = (value: mirror.value, date: mirror.date);
  }

  void _emit() => _controller.add(docs.values.toList());

  void _checkFailure() {
    final failure = failNextWrite;
    if (failure != null) {
      failNextWrite = null;
      throw failure;
    }
  }

  @override
  Stream<List<InvestmentValuationSnapshot>> watchAll() {
    watchCount++;
    return Stream.multi((c) {
      c.add(docs.values.toList());
      final sub = _controller.stream.listen(c.add);
      c.onCancel = sub.cancel;
    });
  }

  /// Whole-collection reads, and the investments read one at a time, so a
  /// test can see what an action reads.
  var getAllCount = 0;
  final List<String> readByInvestment = [];

  @override
  Future<List<InvestmentValuationSnapshot>> getAll() async {
    getAllCount++;
    return docs.values.toList();
  }

  @override
  Future<List<InvestmentValuationSnapshot>> getByInvestment(
    String investmentId,
  ) async {
    readByInvestment.add(investmentId);
    // Cleared ones included, as a query on the collection returns them.
    return [
      for (final s in docs.values)
        if (s.investmentId == investmentId) s,
    ];
  }

  final _server =
      StreamController<List<InvestmentValuationSnapshot>>.broadcast();

  /// What the server confirms, as a test says it.
  void emitServer(List<InvestmentValuationSnapshot> snapshots) =>
      _server.add(snapshots);

  @override
  Stream<List<InvestmentValuationSnapshot>> watchServerConfirmed() =>
      _server.stream;

  @override
  Future<void> save(
    InvestmentValuationSnapshot snapshot, {
    required CompatMirror mirror,
  }) async {
    _checkFailure();
    docs[snapshot.id] = _stamped(snapshot);
    _applyMirror(mirror);
    log.add('save:${snapshot.id}');
    _emit();
  }

  @override
  Future<void> softDelete(
    InvestmentValuationSnapshot snapshot, {
    required CompatMirror mirror,
  }) async {
    _checkFailure();
    docs[snapshot.id] = _stamped(snapshot.copyWith(deletedAt: DateTime.now()));
    _applyMirror(mirror);
    log.add('softDelete:${snapshot.id}');
    _emit();
  }

  @override
  Future<void> restore(
    InvestmentValuationSnapshot snapshot, {
    required CompatMirror mirror,
  }) async {
    _checkFailure();
    docs[snapshot.id] = _stamped(snapshot.copyWith(clearDeletedAt: true));
    _applyMirror(mirror);
    log.add('restore:${snapshot.id}');
    _emit();
  }

  @override
  Future<int> importAll(List<InvestmentValuationSnapshot> snapshots) async {
    _checkFailure();
    for (final s in snapshots) {
      docs[s.id] = s;
    }
    log.add('importAll:${snapshots.length}');
    _emit();
    return snapshots.length;
  }

  void dispose() {
    _controller.close();
    _server.close();
  }
}
