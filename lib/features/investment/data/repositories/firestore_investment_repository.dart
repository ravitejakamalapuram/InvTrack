import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:inv_tracker/core/calculations/current_value_calculator.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/utils/custom_type_label.dart';
import 'package:inv_tracker/core/utils/stored_date.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';
import 'package:rxdart/rxdart.dart';

/// Firestore-based implementation of InvestmentRepository
/// Provides offline persistence and real-time sync across devices
class FirestoreInvestmentRepository implements InvestmentRepository {
  final FirebaseFirestore _firestore;
  final String _userId;

  /// The user's base currency, for documents with no `currency` field.
  final String Function() _baseCurrency;

  /// Asked for when an investment is deleted while the server gave no answer
  /// about its expected payments, so that the one-off orphan sweep runs again
  /// at the next Income Guardian start (#917). Best effort: a failure here
  /// never stops the delete.
  final Future<void> Function()? _onExpectedPaymentsUnverified;

  /// Told when the server rejects a write that was already reported as saved
  /// (see [_executeLocalWrite]). Never given the record.
  final void Function(Object error)? _onWriteRejected;

  /// Timeout for write operations - allows offline writes to complete quickly
  static const Duration _writeTimeout = Duration(seconds: 3);

  /// Timeout for a read that must come from the server.
  static const Duration _serverReadTimeout = Duration(seconds: 10);

  /// Deletes per batch when an investment and what belongs to it are removed
  /// (the Firestore limit is 500).
  static const int _deleteBatchSize = 450;

  FirestoreInvestmentRepository({
    required FirebaseFirestore firestore,
    required String userId,
    required String Function() baseCurrency,
    Future<void> Function()? onExpectedPaymentsUnverified,
    void Function(Object error)? onWriteRejected,
  }) : _firestore = firestore,
       _userId = userId,
       _baseCurrency = baseCurrency,
       _onExpectedPaymentsUnverified = onExpectedPaymentsUnverified,
       _onWriteRejected = onWriteRejected;

  /// Execute a write operation with timeout
  /// If the operation times out (likely offline), we consider it successful
  /// since Firestore will sync when back online
  Future<void> _executeWrite(Future<void> Function() writeOperation) async {
    await _executeConfirmedWrite(writeOperation);
  }

  /// [_executeWrite] that says whether the server confirmed in time: true if
  /// it did, false if the write timed out and is pending in the local cache.
  /// A rejected write still throws.
  Future<bool> _executeConfirmedWrite(
    Future<void> Function() writeOperation,
  ) async {
    try {
      await writeOperation().timeout(_writeTimeout);
      return true;
    } on TimeoutException {
      // Write is cached locally, will sync when online
      // This is expected behavior for offline-first apps
      return false;
    }
  }

  /// A write that counts as saved once it is in the local cache, which
  /// Firestore does before the future completes: the caller does not wait for
  /// the server, so a save offline is as quick as one online. A write the
  /// server rejects later is logged by its type only and passed to
  /// [_onWriteRejected]; the local cache drops it and the lists follow.
  Future<void> _executeLocalWrite(
    Future<void> Function() writeOperation,
  ) async {
    final pending = writeOperation();
    unawaited(
      pending.then<void>(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {
          LoggerService.warn(
            'A saved write was rejected by the server',
            metadata: {'errorType': error.runtimeType.toString()},
            stackTrace: stackTrace,
          );
          try {
            _onWriteRejected?.call(error);
          } catch (_) {
            // Reporting must never throw into the zone.
          }
        },
      ),
    );
  }

  // Collection references for ACTIVE data
  CollectionReference<Map<String, dynamic>> get _investmentsRef =>
      _firestore.collection('users').doc(_userId).collection('investments');

  CollectionReference<Map<String, dynamic>> get _cashFlowsRef =>
      _firestore.collection('users').doc(_userId).collection('cashflows');

  // Dated valuation snapshots of active and archived investments alike (the
  // collection name is a literal for the account deletion coverage test).
  CollectionReference<Map<String, dynamic>> get _valuationsRef =>
      _firestore.collection('users').doc(_userId).collection('valuations');

  // Expected payments of active and archived investments alike (the collection
  // name is a literal for the account deletion coverage test).
  CollectionReference<Map<String, dynamic>> get _expectedCashFlowsRef =>
      _firestore
          .collection('users')
          .doc(_userId)
          .collection('expectedCashFlows');

  // Document records of active and archived investments alike (the collection
  // name is a literal for the account deletion coverage test).
  CollectionReference<Map<String, dynamic>> get _documentsRef =>
      _firestore.collection('users').doc(_userId).collection('documents');

  // Goals that can link investments by id, active and archived.
  CollectionReference<Map<String, dynamic>> get _goalsRef =>
      _firestore.collection('users').doc(_userId).collection('goals');

  CollectionReference<Map<String, dynamic>> get _archivedGoalsRef =>
      _firestore.collection('users').doc(_userId).collection('archivedGoals');

  // Collection references for ARCHIVED data (complete isolation)
  CollectionReference<Map<String, dynamic>> get _archivedInvestmentsRef =>
      _firestore
          .collection('users')
          .doc(_userId)
          .collection('archivedInvestments');

  CollectionReference<Map<String, dynamic>> get _archivedCashFlowsRef =>
      _firestore
          .collection('users')
          .doc(_userId)
          .collection('archivedCashflows');

  // ============ ACTIVE INVESTMENTS ============

  @override
  Stream<List<InvestmentEntity>> watchAllInvestments() {
    return _investmentsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _investmentFromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  @override
  Stream<List<InvestmentEntity>> watchInvestmentsByStatus(
    InvestmentStatus status,
  ) {
    return _investmentsRef
        .where('status', isEqualTo: status.name.toUpperCase())
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _investmentFromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  @override
  Stream<List<InvestmentEntity>> watchInvestmentsPaginated({
    required int limit,
    String? startAfterInvestmentId,
  }) async* {
    // Clamp limit to prevent excessive data transfer
    final effectiveLimit = limit.clamp(1, 100);

    Query<Map<String, dynamic>> query = _investmentsRef
        .orderBy('createdAt', descending: true)
        .limit(effectiveLimit);

    // If pagination cursor provided, start after that document
    if (startAfterInvestmentId != null) {
      final startAfterDoc = await _investmentsRef
          .doc(startAfterInvestmentId)
          .get();
      if (startAfterDoc.exists) {
        query = query.startAfterDocument(startAfterDoc);
      }
    }

    // Stream paginated results
    await for (final snapshot in query.snapshots()) {
      yield snapshot.docs
          .map((doc) => _investmentFromFirestore(doc.data(), doc.id))
          .toList();
    }
  }

  @override
  Future<List<InvestmentEntity>> getAllInvestments() async {
    final snapshot = await _investmentsRef
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => _investmentFromFirestore(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<InvestmentEntity?> getInvestmentById(String id) async {
    // Search active first
    final doc = await _investmentsRef.doc(id).get();
    if (doc.exists) {
      return _investmentFromFirestore(doc.data()!, doc.id);
    }
    // Fall back to archived
    final archivedDoc = await _archivedInvestmentsRef.doc(id).get();
    if (archivedDoc.exists) {
      return _investmentFromFirestore(archivedDoc.data()!, archivedDoc.id);
    }
    return null;
  }

  @override
  Future<void> createInvestment(InvestmentEntity investment) async {
    await _executeWrite(
      () => _investmentsRef
          .doc(investment.id)
          .set(_investmentToFirestore(investment)),
    );
  }

  @override
  Future<void> updateInvestment(
    InvestmentEntity investment, {
    bool preserveCurrentValue = false,
  }) async {
    await _executeWrite(
      () => _investmentsRef
          .doc(investment.id)
          .update(
            _investmentToFirestore(
              investment,
              preserveCurrentValue: preserveCurrentValue,
            ),
          ),
    );
  }

  @override
  Future<void> closeInvestment(String id) async {
    await _executeWrite(
      () => _investmentsRef.doc(id).update({
        'status': 'CLOSED',
        'closedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  @override
  Future<void> reopenInvestment(String id) async {
    await _executeWrite(
      () => _investmentsRef.doc(id).update({
        'status': 'OPEN',
        'closedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  @override
  Future<void> archiveInvestment(String id) async {
    // Move investment from active to archived collection
    try {
      final doc = await _investmentsRef.doc(id).get();
      if (!doc.exists) return;

      final investmentData = doc.data()!;
      investmentData['isArchived'] = true;
      investmentData['updatedAt'] = FieldValue.serverTimestamp();

      final cashFlows = await _cashFlowsRef
          .where('investmentId', isEqualTo: id)
          .get();

      await _moveInvestment(
        investment: _investmentsRef.doc(id),
        investmentData: investmentData,
        target: _archivedInvestmentsRef.doc(id),
        cashFlows: cashFlows.docs,
        cashFlowsTarget: _archivedCashFlowsRef,
      );
    } on TimeoutException {
      // Offline - data will sync when back online
    }
  }

  @override
  Future<void> unarchiveInvestment(String id) async {
    // Move investment from archived back to active collection
    try {
      final doc = await _archivedInvestmentsRef.doc(id).get();
      if (!doc.exists) return;

      final investmentData = doc.data()!;
      investmentData['isArchived'] = false;
      investmentData['updatedAt'] = FieldValue.serverTimestamp();

      final cashFlows = await _archivedCashFlowsRef
          .where('investmentId', isEqualTo: id)
          .get();

      await _moveInvestment(
        investment: _archivedInvestmentsRef.doc(id),
        investmentData: investmentData,
        target: _investmentsRef.doc(id),
        cashFlows: cashFlows.docs,
        cashFlowsTarget: _cashFlowsRef,
      );
    } on TimeoutException {
      // Offline - data will sync when back online
    }
  }

  /// Moves an investment and its cash flows to the other collection pair in
  /// batches of at most [_deleteBatchSize] operations (Firestore allows 500).
  ///
  /// All copies are written first, then the source investment is deleted, then
  /// its cash flows. A failed batch therefore never leaves the source
  /// investment with part of its cash flows missing: either the move has not
  /// reached the deletes (the source is whole, and running it again overwrites
  /// the copies by id), or the copy is complete and any source cash flows
  /// left behind have no investment, so they are filtered out like those of
  /// [bulkDelete].
  Future<void> _moveInvestment({
    required DocumentReference<Map<String, dynamic>> investment,
    required Map<String, dynamic> investmentData,
    required DocumentReference<Map<String, dynamic>> target,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> cashFlows,
    required CollectionReference<Map<String, dynamic>> cashFlowsTarget,
  }) async {
    final writes = <void Function(WriteBatch)>[
      for (final cf in cashFlows)
        (batch) => batch.set(cashFlowsTarget.doc(cf.id), cf.data()),
      (batch) => batch.set(target, investmentData),
      (batch) => batch.delete(investment),
      for (final cf in cashFlows) (batch) => batch.delete(cf.reference),
    ];
    for (var i = 0; i < writes.length; i += _deleteBatchSize) {
      final batch = _firestore.batch();
      for (final write in writes.skip(i).take(_deleteBatchSize)) {
        write(batch);
      }
      await _executeWrite(() => batch.commit());
    }
  }

  @override
  Future<void> deleteInvestment(String id) => _deleteWithDependents(
    investment: _investmentsRef.doc(id),
    cashFlowsRef: _cashFlowsRef,
    investmentId: id,
  );

  /// Deletes [investment], its cash flows in [cashFlowsRef], its valuation
  /// snapshots (tombstones included), its expected payments and its document
  /// records, and takes it out of the goals that link it, so that none is left
  /// behind.
  ///
  /// Everything that has to go is found first, so that a failure to find it
  /// deletes nothing. The investment is removed last, in the final batch: if
  /// an earlier batch fails, the investment is still there to retry from.
  Future<void> _deleteWithDependents({
    required DocumentReference<Map<String, dynamic>> investment,
    required CollectionReference<Map<String, dynamic>> cashFlowsRef,
    required String investmentId,
  }) async {
    final cashFlows = await _getDocsForDeletion(cashFlowsRef, investmentId);
    final snapshots = await _refsForDeletion(_valuationsRef, investmentId);
    final expected = await _refsForDeletion(
      _expectedCashFlowsRef,
      investmentId,
      onUnanswered: _onExpectedPaymentsUnverified,
    );
    final documents = await _refsForDeletion(_documentsRef, investmentId);
    final goals = await _goalRefsLinkedTo(investmentId);
    final writes = <void Function(WriteBatch)>[
      for (final doc in cashFlows.docs) (batch) => batch.delete(doc.reference),
      for (final ref in [...snapshots, ...expected, ...documents])
        (batch) => batch.delete(ref),
      for (final goal in goals)
        (batch) => _unlinkFromGoal(batch, goal, [investmentId]),
      (batch) => batch.delete(investment),
    ];
    await _commitInBatches(writes);
  }

  /// Commits [writes] in batches of at most [_deleteBatchSize], in order.
  Future<void> _commitInBatches(List<void Function(WriteBatch)> writes) async {
    for (var i = 0; i < writes.length; i += _deleteBatchSize) {
      final end = (i + _deleteBatchSize < writes.length)
          ? i + _deleteBatchSize
          : writes.length;
      final batch = _firestore.batch();
      for (final write in writes.sublist(i, end)) {
        write(batch);
      }
      await _executeWrite(() => batch.commit());
    }
  }

  void _unlinkFromGoal(
    WriteBatch batch,
    DocumentReference goal,
    List<String> investmentIds,
  ) => batch.update(goal, {
    'linkedInvestmentIds': FieldValue.arrayRemove(investmentIds),
  });

  /// The active and archived goals that link [investmentId]: the server's
  /// answer plus whatever the cache holds. Best effort: a goal that cannot be
  /// listed keeps a dead id, which the goal progress calculation ignores, and
  /// must never stop the delete.
  Future<Set<DocumentReference>> _goalRefsLinkedTo(String investmentId) async {
    final refs = <DocumentReference>{};
    for (final goals in [_goalsRef, _archivedGoalsRef]) {
      final query = goals.where(
        'linkedInvestmentIds',
        arrayContains: investmentId,
      );
      for (final options in const [
        GetOptions(source: Source.server),
        GetOptions(source: Source.cache),
      ]) {
        try {
          final snapshot = await query.get(options).timeout(_serverReadTimeout);
          refs.addAll(snapshot.docs.map((doc) => doc.reference));
        } catch (_) {
          // Offline or too slow: use what the other source gave.
        }
      }
    }
    return refs;
  }

  /// Finds every document of [ref] for [investmentId] in the local cache (cash
  /// flows) so it can be deleted alongside the investment.
  ///
  /// Cache-first: the local Firestore cache is unlimited in size (see
  /// `database_module.dart`), so it holds every cash flow this device has
  /// ever synced, and reading it never needs the network. We only fall back
  /// to a server query if the cache read itself fails.
  ///
  /// IMPORTANT: if we cannot determine which cash flows exist (cache
  /// unusable and the device is offline), we deliberately throw instead of
  /// proceeding to delete the investment anyway. Deleting the investment
  /// without knowing which cash flows to remove would silently orphan them
  /// forever - a real data-deletion bug, not an acceptable offline
  /// fallback. Throwing here surfaces a clear error so the user can retry
  /// once they're back online, rather than the app reporting success while
  /// leaving data behind.
  Future<QuerySnapshot<Map<String, dynamic>>> _getDocsForDeletion(
    CollectionReference<Map<String, dynamic>> ref,
    String investmentId,
  ) async {
    try {
      return await ref
          .where('investmentId', isEqualTo: investmentId)
          .get(const GetOptions(source: Source.cache));
    } catch (_) {
      try {
        return await ref
            .where('investmentId', isEqualTo: investmentId)
            .get()
            .timeout(_writeTimeout);
      } on TimeoutException catch (e, st) {
        throw NetworkException.noConnection(cause: e, stackTrace: st);
      }
    }
  }

  /// Every document of [ref] for [investmentId]: its valuation snapshots,
  /// tombstones included, or its expected payments.
  ///
  /// Unlike cash flows, these are not kept in the local cache by a listener:
  /// none runs with the feature flag off, on a fresh install or after an
  /// account switch, and an empty cache answers with no documents rather than
  /// an error. So the server is asked as well, and the cache adds what it
  /// holds that the server has not seen yet (writes made offline).
  ///
  /// Throws [NetworkException], like [_getDocsForDeletion], when neither can
  /// answer: nothing is deleted then, rather than orphaning them.
  ///
  /// Known limit: offline with an empty cache, the cache answers with no
  /// documents and the delete goes ahead, exactly as it does for cash flows.
  /// Requiring a server answer would fail every offline delete. Documents the
  /// server holds but this device never saw then stay behind. [onUnanswered]
  /// is called in that case (the server gave no answer) so the caller can
  /// arrange for them to be found later; it is best effort and never stops
  /// the delete.
  Future<Set<DocumentReference>> _refsForDeletion(
    CollectionReference<Map<String, dynamic>> ref,
    String investmentId, {
    Future<void> Function()? onUnanswered,
  }) async {
    final refs = <DocumentReference>{};
    var serverAnswered = false;
    try {
      final server = await ref
          .where('investmentId', isEqualTo: investmentId)
          .get(const GetOptions(source: Source.server))
          .timeout(_serverReadTimeout);
      refs.addAll(server.docs.map((doc) => doc.reference));
      serverAnswered = true;
    } catch (_) {
      // Offline or too slow: the cache is all there is.
    }
    try {
      final cached = await _getDocsForDeletion(ref, investmentId);
      refs.addAll(cached.docs.map((doc) => doc.reference));
    } catch (_) {
      if (!serverAnswered) rethrow;
    }
    if (!serverAnswered && onUnanswered != null) {
      try {
        await onUnanswered();
      } catch (_) {
        // Only a hint for a later sweep: the delete must still happen.
      }
    }
    return refs;
  }

  // ============ ARCHIVED INVESTMENTS ============

  @override
  Stream<List<InvestmentEntity>> watchArchivedInvestments() {
    return _archivedInvestmentsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _investmentFromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  @override
  Stream<bool> watchHasNoInvestments() {
    return Rx.combineLatest2(
      _watchIsEmpty(_investmentsRef.orderBy('createdAt', descending: true)),
      _watchIsEmpty(
        _archivedInvestmentsRef.orderBy('createdAt', descending: true),
      ),
      (bool? active, bool? archived) {
        if (active == false || archived == false) return false;
        if (active == true && archived == true) return true;
        return null;
      },
    ).where((isEmpty) => isEmpty != null).cast<bool>().distinct();
  }

  /// Whether [query] has no documents, or null while that is unknown because
  /// only an empty cache has answered.
  ///
  /// Listens to metadata changes, so that an empty server answer arrives
  /// after an empty cache answer. The query is the one the lists use, so
  /// Firestore serves both from one listener.
  Stream<bool?> _watchIsEmpty(Query<Map<String, dynamic>> query) {
    return query
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => snapshot.docs.isNotEmpty
              ? false
              : snapshot.metadata.isFromCache
              ? null
              : true,
        );
  }

  @override
  Stream<Set<String>> watchServerConfirmedInvestmentIds() {
    return Rx.combineLatest2(
      _watchServerConfirmedIds(
        _investmentsRef.orderBy('createdAt', descending: true),
      ),
      _watchServerConfirmedIds(
        _archivedInvestmentsRef.orderBy('createdAt', descending: true),
      ),
      (Set<String> active, Set<String> archived) => {...active, ...archived},
    );
  }

  /// The document ids of [query] each time the server confirms them: cache
  /// answers and answers with a write of this device pending are dropped.
  ///
  /// Listens to metadata changes, so that the server confirming what the cache
  /// already showed (no document changed) still arrives. The query is the one
  /// the lists use, so Firestore serves both from one listener.
  Stream<Set<String>> _watchServerConfirmedIds(
    Query<Map<String, dynamic>> query,
  ) {
    return query
        .snapshots(includeMetadataChanges: true)
        .where(
          (snapshot) =>
              !snapshot.metadata.isFromCache &&
              !snapshot.metadata.hasPendingWrites,
        )
        .map((snapshot) => {for (final doc in snapshot.docs) doc.id});
  }

  @override
  Future<bool> hasAnyInvestmentOnServer() async {
    const serverOnly = GetOptions(source: Source.server);
    final snapshots = await Future.wait([
      _investmentsRef.limit(1).get(serverOnly),
      _archivedInvestmentsRef.limit(1).get(serverOnly),
    ]).timeout(_serverReadTimeout);
    return snapshots.any((snapshot) => snapshot.docs.isNotEmpty);
  }

  @override
  Future<InvestmentEntity?> getArchivedInvestmentById(String id) async {
    final doc = await _archivedInvestmentsRef.doc(id).get();
    if (!doc.exists) return null;
    return _investmentFromFirestore(doc.data()!, doc.id);
  }

  @override
  Future<void> updateArchivedInvestment(
    InvestmentEntity investment, {
    bool preserveCurrentValue = false,
  }) async {
    await _executeWrite(
      () => _archivedInvestmentsRef
          .doc(investment.id)
          .update(
            _investmentToFirestore(
              investment,
              preserveCurrentValue: preserveCurrentValue,
            ),
          ),
    );
  }

  @override
  Future<void> deleteArchivedInvestment(String id) => _deleteWithDependents(
    investment: _archivedInvestmentsRef.doc(id),
    cashFlowsRef: _archivedCashFlowsRef,
    investmentId: id,
  );

  // ============ ACTIVE CASH FLOWS ============

  @override
  Stream<List<CashFlowEntity>> watchAllCashFlows() {
    return _cashFlowsRef
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _cashFlowFromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  @override
  Stream<List<CashFlowEntity>> watchCashFlowsByInvestment(String investmentId) {
    return _cashFlowsRef
        .where('investmentId', isEqualTo: investmentId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _cashFlowFromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  @override
  Stream<List<CashFlowEntity>> watchCashFlowsInDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return _cashFlowsInDaysQuery(startDate, endDate).snapshots().map(
      (snapshot) => _cashFlowsWithinDays(snapshot, startDate, endDate),
    );
  }

  @override
  Future<List<CashFlowEntity>> getCashFlowsByInvestment(
    String investmentId,
  ) async {
    final snapshot = await _cashFlowsRef
        .where('investmentId', isEqualTo: investmentId)
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => _cashFlowFromFirestore(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<List<CashFlowEntity>> getAllCashFlows() async {
    final snapshot = await _cashFlowsRef
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => _cashFlowFromFirestore(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<List<CashFlowEntity>> getCashFlowsInDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final snapshot = await _cashFlowsInDaysQuery(startDate, endDate).get();
    return _cashFlowsWithinDays(snapshot, startDate, endDate);
  }

  /// Cash flows dated from [firstDay] to [lastDay], both included, compared
  /// by calendar day. The stored window is wider than the days, so that
  /// documents saved by older builds (the writer's local midnight) are not
  /// missed; [_cashFlowsWithinDays] then keeps only the requested days.
  Query<Map<String, dynamic>> _cashFlowsInDaysQuery(
    DateTime firstDay,
    DateTime lastDay,
  ) {
    final window = StoredDate.queryWindow(firstDay, lastDay);
    return _cashFlowsRef
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(window.from))
        .where('date', isLessThan: Timestamp.fromDate(window.until))
        .orderBy('date', descending: true);
  }

  List<CashFlowEntity> _cashFlowsWithinDays(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    DateTime firstDay,
    DateTime lastDay,
  ) => [
    for (final doc in snapshot.docs) _cashFlowFromFirestore(doc.data(), doc.id),
  ].where((cf) => StoredDate.isWithinDays(cf.date, firstDay, lastDay)).toList();

  /// Refuses a cash flow built for a calculation only (its current value, the
  /// start of a tracking period): a valuation is never a cash flow.
  static void _requireStorable(CashFlowEntity cashFlow) {
    if (TerminalValues.isEphemeralId(cashFlow.id)) {
      throw ArgumentError.value(
        'id',
        'cashFlow.id',
        'Is the id of a flow built for a calculation',
      );
    }
  }

  @override
  Future<void> addCashFlow(CashFlowEntity cashFlow) async {
    _requireStorable(cashFlow);
    await _executeLocalWrite(
      () => _cashFlowsRef.doc(cashFlow.id).set(_cashFlowToFirestore(cashFlow)),
    );
  }

  @override
  Future<void> updateCashFlow(CashFlowEntity cashFlow) async {
    _requireStorable(cashFlow);
    await _executeWrite(
      () =>
          _cashFlowsRef.doc(cashFlow.id).update(_cashFlowToFirestore(cashFlow)),
    );
  }

  @override
  Future<void> deleteCashFlow(String id) async {
    await _executeWrite(() => _cashFlowsRef.doc(id).delete());
  }

  // ============ ARCHIVED CASH FLOWS ============

  @override
  Stream<List<CashFlowEntity>> watchArchivedCashFlowsByInvestment(
    String investmentId,
  ) {
    return _archivedCashFlowsRef
        .where('investmentId', isEqualTo: investmentId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _cashFlowFromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  @override
  Future<List<CashFlowEntity>> getArchivedCashFlowsByInvestment(
    String investmentId,
  ) async {
    final snapshot = await _archivedCashFlowsRef
        .where('investmentId', isEqualTo: investmentId)
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => _cashFlowFromFirestore(doc.data(), doc.id))
        .toList();
  }

  // ============ BULK OPERATIONS ============

  @override
  Future<({int investments, int cashFlows})> bulkImport({
    required List<InvestmentEntity> investments,
    required List<CashFlowEntity> cashFlows,
  }) async {
    // Firestore batch has a limit of 500 operations per batch
    const batchLimit = 500;
    var investmentCount = 0;
    var cashFlowCount = 0;
    cashFlows.forEach(_requireStorable);

    // Process investments in batches
    for (var i = 0; i < investments.length; i += batchLimit) {
      final batch = _firestore.batch();
      final end = (i + batchLimit < investments.length)
          ? i + batchLimit
          : investments.length;

      for (var j = i; j < end; j++) {
        final inv = investments[j];
        batch.set(_investmentsRef.doc(inv.id), _investmentToFirestore(inv));
        investmentCount++;
      }

      await _executeWrite(() => batch.commit());
    }

    // Process cash flows in batches
    for (var i = 0; i < cashFlows.length; i += batchLimit) {
      final batch = _firestore.batch();
      final end = (i + batchLimit < cashFlows.length)
          ? i + batchLimit
          : cashFlows.length;

      for (var j = i; j < end; j++) {
        final cf = cashFlows[j];
        batch.set(_cashFlowsRef.doc(cf.id), _cashFlowToFirestore(cf));
        cashFlowCount++;
      }

      await _executeWrite(() => batch.commit());
    }

    return (investments: investmentCount, cashFlows: cashFlowCount);
  }

  @override
  Future<bool> createInvestmentWithFirstCashFlow(
    InvestmentEntity investment,
    CashFlowEntity? firstFlow,
  ) async {
    if (firstFlow != null) {
      _requireStorable(firstFlow);
      if (firstFlow.investmentId != investment.id) {
        // It would be saved without its investment.
        throw ArgumentError(
          'The first cash flow belongs to another investment',
        );
      }
    }
    // One batch: the investment and its flow land together or not at all.
    // Dates and currency go through the same mappers as every other write.
    final batch = _firestore.batch()
      ..set(
        _investmentsRef.doc(investment.id),
        _investmentToFirestore(investment),
      );
    if (firstFlow != null) {
      batch.set(
        _cashFlowsRef.doc(firstFlow.id),
        _cashFlowToFirestore(firstFlow),
      );
    }
    return _executeConfirmedWrite(batch.commit);
  }

  @override
  Future<int> bulkDelete(List<String> investmentIds) async {
    if (investmentIds.isEmpty) return 0;

    const batchLimit = 500;
    var deletedCount = 0;

    // First, collect all cash flows to delete
    final cashFlowDocsToDelete = <DocumentReference>[];
    final goalLinks = <DocumentReference, List<String>>{};
    for (final investmentId in investmentIds) {
      try {
        final cashFlows = await _cashFlowsRef
            .where('investmentId', isEqualTo: investmentId)
            .get(const GetOptions(source: Source.cache))
            .timeout(
              _writeTimeout,
              onTimeout: () async {
                return await _cashFlowsRef
                    .where('investmentId', isEqualTo: investmentId)
                    .get()
                    .timeout(_writeTimeout);
              },
            );
        for (final doc in cashFlows.docs) {
          cashFlowDocsToDelete.add(doc.reference);
        }
      } on TimeoutException {
        // Continue without cash flows - they'll be orphaned but filtered out
      }
      // Valuation snapshots and expected payments are not best-effort: when
      // they cannot be listed this throws before anything is deleted, so none
      // is orphaned.
      cashFlowDocsToDelete.addAll(
        await _refsForDeletion(_valuationsRef, investmentId),
      );
      cashFlowDocsToDelete.addAll(
        await _refsForDeletion(
          _expectedCashFlowsRef,
          investmentId,
          onUnanswered: _onExpectedPaymentsUnverified,
        ),
      );
      cashFlowDocsToDelete.addAll(
        await _refsForDeletion(_documentsRef, investmentId),
      );
      for (final goal in await _goalRefsLinkedTo(investmentId)) {
        goalLinks.putIfAbsent(goal, () => []).add(investmentId);
      }
    }

    // Delete cash flows (and valuation snapshots, expected payments) in batches
    for (var i = 0; i < cashFlowDocsToDelete.length; i += batchLimit) {
      final batch = _firestore.batch();
      final end = (i + batchLimit < cashFlowDocsToDelete.length)
          ? i + batchLimit
          : cashFlowDocsToDelete.length;

      for (var j = i; j < end; j++) {
        batch.delete(cashFlowDocsToDelete[j]);
      }
      await _executeWrite(() => batch.commit());
    }

    // Take the investments out of the goals that link them
    await _commitInBatches([
      for (final link in goalLinks.entries)
        (batch) => _unlinkFromGoal(batch, link.key, link.value),
    ]);

    // Delete investments in batches
    for (var i = 0; i < investmentIds.length; i += batchLimit) {
      final batch = _firestore.batch();
      final end = (i + batchLimit < investmentIds.length)
          ? i + batchLimit
          : investmentIds.length;

      for (var j = i; j < end; j++) {
        batch.delete(_investmentsRef.doc(investmentIds[j]));
        deletedCount++;
      }
      await _executeWrite(() => batch.commit());
    }

    return deletedCount;
  }

  // ============ FIRESTORE MAPPERS ============

  /// Stores a date-only field (cash-flow date, start or maturity date) as
  /// UTC midnight of its calendar day. See [StoredDate].
  static Timestamp? _dateToFirestore(DateTime? date) =>
      date == null ? null : Timestamp.fromDate(StoredDate.toStorage(date));

  /// Reads a date-only field as a local date-only value with the same
  /// calendar day in every time zone, including documents saved by older
  /// builds. [offsetAt] is the reading device's zone (tests inject one).
  static DateTime? _dateFromFirestore(Object? value, UtcOffsetAt? offsetAt) =>
      value == null
      ? null
      : StoredDate.fromStorage(
          (value as Timestamp).toDate(),
          offsetAt: offsetAt,
        );

  /// With [preserveCurrentValue] the current value pair is left out, so an
  /// update keeps whatever is stored: the pair mirrors the latest valuation
  /// snapshot and a stale copy must not overwrite it.
  Map<String, dynamic> _investmentToFirestore(
    InvestmentEntity investment, {
    bool preserveCurrentValue = false,
  }) {
    final data = {
      'name': investment.name,
      'type': investment.type.name,
      'status': investment.status.name.toUpperCase(),
      'notes': investment.notes,
      'createdAt': Timestamp.fromDate(investment.createdAt),
      'closedAt': investment.closedAt != null
          ? Timestamp.fromDate(investment.closedAt!)
          : null,
      'updatedAt': FieldValue.serverTimestamp(),
      'maturityDate': _dateToFirestore(investment.maturityDate),
      'incomeFrequency': investment.incomeFrequency?.name,
      'isArchived': investment.isArchived,
      // New enhanced data capture fields
      'startDate': _dateToFirestore(investment.startDate),
      'expectedRate': investment.expectedRate,
      'tenureMonths': investment.tenureMonths,
      'platform': investment.platform,
      'interestPayoutMode': investment.interestPayoutMode?.name,
      'autoRenewal': investment.autoRenewal,
      'riskLevel': investment.riskLevel?.name,
      'compoundingFrequency': investment.compoundingFrequency?.name,
      // Multi-currency support
      'currency': investment.currency,
      // The user's current value; written as null when cleared.
      'currentValue': investment.currentValue,
      'currentValueDate': investment.currentValueDate != null
          ? Timestamp.fromDate(investment.currentValueDate!)
          : null,
      // Custom type (#936); null when none, so an edit clears a stored one.
      // Only an investment of type Other has one.
      'customTypeId': investment.type == InvestmentType.other
          ? investment.customTypeId
          : null,
      'customTypeLabel': investment.type == InvestmentType.other
          ? investment.customTypeLabel
          : null,
    };
    if (preserveCurrentValue) {
      data.remove('currentValue');
      data.remove('currentValueDate');
    }
    return data;
  }

  InvestmentEntity _investmentFromFirestore(
    Map<String, dynamic> data,
    String id,
  ) => investmentFromFirestore(data, id, baseCurrency: _baseCurrency());

  /// Maps an investment document. Documents written before multi-currency
  /// support have no `currency` and take [baseCurrency], never USD.
  /// Date-only fields keep their calendar day in the zone [offsetAt]
  /// describes, which defaults to this device's.
  @visibleForTesting
  static InvestmentEntity investmentFromFirestore(
    Map<String, dynamic> data,
    String id, {
    required String baseCurrency,
    UtcOffsetAt? offsetAt,
  }) {
    final type = InvestmentType.fromString(data['type'] as String);
    // Only an investment of type Other has a custom type (#936); an older
    // build can leave a stale one behind after the type is changed, and a
    // label of another build is cleaned and cut like one typed here.
    final isOther = type == InvestmentType.other;
    final customTypeLabel = isOther
        ? CustomTypeLabel.fromStorage(data['customTypeLabel'])
        : '';
    return InvestmentEntity(
      id: id,
      name: data['name'] as String,
      type: type,
      status: InvestmentStatus.fromString(data['status'] as String),
      notes: data['notes'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      closedAt: data['closedAt'] != null
          ? (data['closedAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      maturityDate: _dateFromFirestore(data['maturityDate'], offsetAt),
      incomeFrequency: IncomeFrequency.fromString(
        data['incomeFrequency'] as String?,
      ),
      isArchived: data['isArchived'] as bool? ?? false,
      // New enhanced data capture fields
      startDate: _dateFromFirestore(data['startDate'], offsetAt),
      expectedRate: (data['expectedRate'] as num?)?.toDouble(),
      tenureMonths: data['tenureMonths'] as int?,
      platform: data['platform'] as String?,
      interestPayoutMode: InterestPayoutMode.fromString(
        data['interestPayoutMode'] as String?,
      ),
      autoRenewal: data['autoRenewal'] as bool?,
      riskLevel: RiskLevel.fromString(data['riskLevel'] as String?),
      compoundingFrequency: CompoundingFrequency.fromString(
        data['compoundingFrequency'] as String?,
      ),
      // Multi-currency support; legacy documents use the base currency
      currency: data['currency'] as String? ?? baseCurrency,
      currencyAssumed: data['currency'] == null,
      // A value without its date is ignored rather than dated today.
      currentValue: data['currentValueDate'] != null
          ? (data['currentValue'] as num?)?.toDouble()
          : null,
      currentValueDate: data['currentValue'] != null
          ? (data['currentValueDate'] as Timestamp?)?.toDate()
          : null,
      // Documents saved before custom types (#936) have neither field.
      customTypeId: isOther ? _nonBlank(data['customTypeId']) : null,
      customTypeLabel: customTypeLabel.isEmpty ? null : customTypeLabel,
    );
  }

  /// [value] as text, or null when it is missing or blank.
  static String? _nonBlank(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value;
  }

  Map<String, dynamic> _cashFlowToFirestore(CashFlowEntity cashFlow) {
    return {
      'investmentId': cashFlow.investmentId,
      'date': _dateToFirestore(cashFlow.date),
      'type': cashFlow.type.toDbString(),
      'amount': cashFlow.amount,
      'notes': cashFlow.notes,
      'createdAt': Timestamp.fromDate(cashFlow.createdAt),
      // Multi-currency support
      'currency': cashFlow.currency,
    };
  }

  CashFlowEntity _cashFlowFromFirestore(Map<String, dynamic> data, String id) =>
      cashFlowFromFirestore(data, id, baseCurrency: _baseCurrency());

  /// Maps a cash flow document. Documents written before multi-currency
  /// support have no `currency` and take [baseCurrency], never USD.
  /// Date-only fields keep their calendar day in the zone [offsetAt]
  /// describes, which defaults to this device's.
  @visibleForTesting
  static CashFlowEntity cashFlowFromFirestore(
    Map<String, dynamic> data,
    String id, {
    required String baseCurrency,
    UtcOffsetAt? offsetAt,
  }) {
    return CashFlowEntity(
      id: id,
      investmentId: data['investmentId'] as String,
      date: _dateFromFirestore(data['date'], offsetAt)!,
      type: CashFlowType.fromString(data['type'] as String),
      amount: (data['amount'] as num).toDouble(),
      notes: data['notes'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      // Multi-currency support; legacy documents use the base currency
      currency: data['currency'] as String? ?? baseCurrency,
      currencyAssumed: data['currency'] == null,
    );
  }
}
