/// Firestore implementation of Expected Cash Flow Repository
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inv_tracker/features/income_projection/domain/entities/expected_cash_flow_entity.dart';
import 'package:inv_tracker/features/income_projection/domain/repositories/expected_cash_flow_repository.dart';

/// Firestore implementation of ExpectedCashFlowRepository
class FirestoreExpectedCashFlowRepository implements ExpectedCashFlowRepository {
  final FirebaseFirestore _firestore;
  final String _userId;

  FirestoreExpectedCashFlowRepository({
    required FirebaseFirestore firestore,
    required String userId,
  })  : _firestore = firestore,
        _userId = userId;

  // Collection reference
  CollectionReference<Map<String, dynamic>> get _expectedCashFlowsRef =>
      _firestore
          .collection('users')
          .doc(_userId)
          .collection('expectedCashFlows');

  // ============ STREAM PROVIDERS ============

  @override
  Stream<List<ExpectedCashFlowEntity>> watchAllExpectedCashFlows() {
    return _expectedCashFlowsRef
        .orderBy('expectedDate', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _expectedCashFlowFromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  @override
  Stream<List<ExpectedCashFlowEntity>> watchExpectedCashFlowsByInvestment(
    String investmentId,
  ) {
    return _expectedCashFlowsRef
        .where('investmentId', isEqualTo: investmentId)
        .orderBy('expectedDate', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _expectedCashFlowFromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  @override
  Stream<List<ExpectedCashFlowEntity>> watchPendingExpectedCashFlows() {
    // Pending = all statuses except received and dismissed
    return _expectedCashFlowsRef
        .where('status', whereIn: [
          'upcoming',
          'dueSoon',
          'gracePeriod',
          'overdue',
        ])
        .orderBy('expectedDate', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _expectedCashFlowFromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  @override
  Stream<List<ExpectedCashFlowEntity>> watchOverdueExpectedCashFlows() {
    final now = DateTime.now();
    final nowTimestamp = Timestamp.fromDate(now);

    return _expectedCashFlowsRef
        .where('status', whereIn: ['gracePeriod', 'overdue'])
        .where('expectedDate', isLessThan: nowTimestamp)
        .orderBy('expectedDate', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _expectedCashFlowFromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  @override
  Stream<List<ExpectedCashFlowEntity>> watchUpcomingExpectedCashFlows({
    int days = 7,
  }) {
    final now = DateTime.now();
    final futureDate = now.add(Duration(days: days));
    final nowTimestamp = Timestamp.fromDate(now);
    final futureTimestamp = Timestamp.fromDate(futureDate);

    return _expectedCashFlowsRef
        .where('status', whereIn: ['upcoming', 'dueSoon'])
        .where('expectedDate', isGreaterThanOrEqualTo: nowTimestamp)
        .where('expectedDate', isLessThanOrEqualTo: futureTimestamp)
        .orderBy('expectedDate', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _expectedCashFlowFromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  // ============ READ OPERATIONS ============

  @override
  Future<List<ExpectedCashFlowEntity>> getAllExpectedCashFlows() async {
    final snapshot =
        await _expectedCashFlowsRef.orderBy('expectedDate', descending: false).get();
    return snapshot.docs
        .map((doc) => _expectedCashFlowFromFirestore(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<List<ExpectedCashFlowEntity>> getExpectedCashFlowsByInvestment(
    String investmentId,
  ) async {
    final snapshot = await _expectedCashFlowsRef
        .where('investmentId', isEqualTo: investmentId)
        .orderBy('expectedDate', descending: false)
        .get();
    return snapshot.docs
        .map((doc) => _expectedCashFlowFromFirestore(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<ExpectedCashFlowEntity?> getExpectedCashFlowById(String id) async {
    final doc = await _expectedCashFlowsRef.doc(id).get();
    if (!doc.exists) return null;
    return _expectedCashFlowFromFirestore(doc.data()!, doc.id);
  }

  @override
  Future<List<ExpectedCashFlowEntity>> getPendingExpectedCashFlows() async {
    final snapshot = await _expectedCashFlowsRef
        .where('status', whereIn: [
          'upcoming',
          'dueSoon',
          'gracePeriod',
          'overdue',
        ])
        .orderBy('expectedDate', descending: false)
        .get();
    return snapshot.docs
        .map((doc) => _expectedCashFlowFromFirestore(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<List<ExpectedCashFlowEntity>> getOverdueExpectedCashFlows() async {
    final now = DateTime.now();
    final nowTimestamp = Timestamp.fromDate(now);

    final snapshot = await _expectedCashFlowsRef
        .where('status', whereIn: ['gracePeriod', 'overdue'])
        .where('expectedDate', isLessThan: nowTimestamp)
        .orderBy('expectedDate', descending: false)
        .get();
    return snapshot.docs
        .map((doc) => _expectedCashFlowFromFirestore(doc.data(), doc.id))
        .toList();
  }

  // ============ WRITE OPERATIONS ============

  @override
  Future<void> createExpectedCashFlow(
    ExpectedCashFlowEntity expectedCashFlow,
  ) async {
    await _executeWrite(
      () => _expectedCashFlowsRef
          .doc(expectedCashFlow.id)
          .set(_expectedCashFlowToFirestore(expectedCashFlow)),
    );
  }

  @override
  Future<void> updateExpectedCashFlow(
    ExpectedCashFlowEntity expectedCashFlow,
  ) async {
    await _executeWrite(
      () => _expectedCashFlowsRef
          .doc(expectedCashFlow.id)
          .update(_expectedCashFlowToFirestore(expectedCashFlow)),
    );
  }

  @override
  Future<void> deleteExpectedCashFlow(String id) async {
    await _executeWrite(() => _expectedCashFlowsRef.doc(id).delete());
  }

  @override
  Future<void> deleteExpectedCashFlowsByInvestment(String investmentId) async {
    final snapshot = await _expectedCashFlowsRef
        .where('investmentId', isEqualTo: investmentId)
        .get();

    // Delete in batch
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await _executeWrite(() => batch.commit());
  }

  // ============ STATUS UPDATE OPERATIONS ============

  @override
  Future<void> markAsReceived({
    required String id,
    required DateTime actualDate,
    required double actualAmount,
  }) async {
    await _executeWrite(
      () => _expectedCashFlowsRef.doc(id).update({
        'status': 'received',
        'actualDate': Timestamp.fromDate(actualDate),
        'actualAmount': actualAmount,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  @override
  Future<void> markAsMissed(String id) async {
    await _executeWrite(
      () => _expectedCashFlowsRef.doc(id).update({
        'status': 'dismissed',
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  // ============ BULK OPERATIONS ============

  @override
  Future<void> bulkCreateExpectedCashFlows(
    List<ExpectedCashFlowEntity> expectedCashFlows,
  ) async {
    // Firestore batch has a limit of 500 operations per batch
    const batchLimit = 500;

    for (var i = 0; i < expectedCashFlows.length; i += batchLimit) {
      final batch = _firestore.batch();
      final end = (i + batchLimit < expectedCashFlows.length)
          ? i + batchLimit
          : expectedCashFlows.length;

      for (var j = i; j < end; j++) {
        final ecf = expectedCashFlows[j];
        batch.set(
          _expectedCashFlowsRef.doc(ecf.id),
          _expectedCashFlowToFirestore(ecf),
        );
      }

      await _executeWrite(() => batch.commit());
    }
  }

  @override
  Future<void> bulkDeleteExpectedCashFlows(List<String> ids) async {
    // Firestore batch has a limit of 500 operations per batch
    const batchLimit = 500;

    for (var i = 0; i < ids.length; i += batchLimit) {
      final batch = _firestore.batch();
      final end = (i + batchLimit < ids.length) ? i + batchLimit : ids.length;

      for (var j = i; j < end; j++) {
        batch.delete(_expectedCashFlowsRef.doc(ids[j]));
      }

      await _executeWrite(() => batch.commit());
    }
  }

  @override
  Future<void> deleteAllExpectedCashFlows() async {
    final snapshot = await _expectedCashFlowsRef.get();
    final ids = snapshot.docs.map((doc) => doc.id).toList();
    await bulkDeleteExpectedCashFlows(ids);
  }

  // ============ PRIVATE HELPERS ============

  /// Offline-first write with timeout
  /// Writes are cached locally and sync when online (Firestore offline persistence)
  Future<void> _executeWrite(Future<void> Function() operation) async {
    try {
      await operation().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          // Timeout = cached locally, will sync when online
          // Don't throw - let Firestore handle sync
        },
      );
    } catch (e) {
      // Let errors propagate for proper error handling
      rethrow;
    }
  }

  /// Convert Firestore data to ExpectedCashFlowEntity
  ExpectedCashFlowEntity _expectedCashFlowFromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    return ExpectedCashFlowEntity(
      id: id,
      investmentId: data['investmentId'] as String,
      expectedDate: (data['expectedDate'] as Timestamp).toDate(),
      expectedAmount: (data['expectedAmount'] as num).toDouble(),
      currency: data['currency'] as String? ?? 'USD',
      predictionSource: PredictionSource.values.firstWhere(
        (s) => s.name == (data['predictionSource'] as String? ?? 'wma'),
        orElse: () => PredictionSource.wma,
      ),
      status: ExpectedCashFlowStatus.values.firstWhere(
        (s) => s.name == (data['status'] as String? ?? 'upcoming'),
        orElse: () => ExpectedCashFlowStatus.upcoming,
      ),
      matchedCashFlowId: data['matchedCashFlowId'] as String?,
      actualAmount: data['actualAmount'] != null
          ? (data['actualAmount'] as num).toDouble()
          : null,
      actualDate: data['actualDate'] != null
          ? (data['actualDate'] as Timestamp).toDate()
          : null,
      notes: data['notes'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : (data['createdAt'] as Timestamp).toDate(),
      platformDelayDays: data['platformDelayDays'] as int?,
      varianceFactor: data['varianceFactor'] != null
          ? (data['varianceFactor'] as num).toDouble()
          : null,
    );
  }

  /// Convert ExpectedCashFlowEntity to Firestore data
  Map<String, dynamic> _expectedCashFlowToFirestore(
    ExpectedCashFlowEntity expectedCashFlow,
  ) {
    return {
      'investmentId': expectedCashFlow.investmentId,
      'expectedDate': Timestamp.fromDate(expectedCashFlow.expectedDate),
      'expectedAmount': expectedCashFlow.expectedAmount,
      'currency': expectedCashFlow.currency,
      'predictionSource': expectedCashFlow.predictionSource.name,
      'status': expectedCashFlow.status.name,
      'matchedCashFlowId': expectedCashFlow.matchedCashFlowId,
      'actualAmount': expectedCashFlow.actualAmount,
      'actualDate': expectedCashFlow.actualDate != null
          ? Timestamp.fromDate(expectedCashFlow.actualDate!)
          : null,
      'notes': expectedCashFlow.notes,
      'createdAt': Timestamp.fromDate(expectedCashFlow.createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'platformDelayDays': expectedCashFlow.platformDelayDays,
      'varianceFactor': expectedCashFlow.varianceFactor,
    };
  }
}