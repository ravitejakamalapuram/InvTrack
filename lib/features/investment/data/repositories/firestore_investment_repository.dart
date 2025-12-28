import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';

/// Firestore-based implementation of InvestmentRepository
/// Provides offline persistence and real-time sync across devices
class FirestoreInvestmentRepository implements InvestmentRepository {
  final FirebaseFirestore _firestore;
  final String _userId;

  /// Timeout for write operations - allows offline writes to complete quickly
  static const Duration _writeTimeout = Duration(seconds: 3);

  FirestoreInvestmentRepository({
    required FirebaseFirestore firestore,
    required String userId,
  }) : _firestore = firestore,
       _userId = userId;

  /// Execute a write operation with timeout
  /// If the operation times out (likely offline), we consider it successful
  /// since Firestore will sync when back online
  Future<void> _executeWrite(Future<void> Function() writeOperation) async {
    try {
      await writeOperation().timeout(_writeTimeout);
    } on TimeoutException {
      // Write is cached locally, will sync when online
      // This is expected behavior for offline-first apps
    }
  }

  // Collection references for ACTIVE data
  CollectionReference<Map<String, dynamic>> get _investmentsRef =>
      _firestore.collection('users').doc(_userId).collection('investments');

  CollectionReference<Map<String, dynamic>> get _cashFlowsRef =>
      _firestore.collection('users').doc(_userId).collection('cashflows');

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
  Future<void> updateInvestment(InvestmentEntity investment) async {
    await _executeWrite(
      () => _investmentsRef
          .doc(investment.id)
          .update(_investmentToFirestore(investment)),
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

      // Move all cash flows for this investment to archived collection
      final cashFlows = await _cashFlowsRef
          .where('investmentId', isEqualTo: id)
          .get();

      final batch = _firestore.batch();

      // Add investment to archived collection
      batch.set(_archivedInvestmentsRef.doc(id), investmentData);
      // Delete from active collection
      batch.delete(_investmentsRef.doc(id));

      // Move each cash flow
      for (final cfDoc in cashFlows.docs) {
        batch.set(_archivedCashFlowsRef.doc(cfDoc.id), cfDoc.data());
        batch.delete(cfDoc.reference);
      }

      await _executeWrite(() => batch.commit());
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

      // Move all archived cash flows for this investment back to active
      final cashFlows = await _archivedCashFlowsRef
          .where('investmentId', isEqualTo: id)
          .get();

      final batch = _firestore.batch();

      // Add investment back to active collection
      batch.set(_investmentsRef.doc(id), investmentData);
      // Delete from archived collection
      batch.delete(_archivedInvestmentsRef.doc(id));

      // Move each cash flow back
      for (final cfDoc in cashFlows.docs) {
        batch.set(_cashFlowsRef.doc(cfDoc.id), cfDoc.data());
        batch.delete(cfDoc.reference);
      }

      await _executeWrite(() => batch.commit());
    } on TimeoutException {
      // Offline - data will sync when back online
    }
  }

  @override
  Future<void> deleteInvestment(String id) async {
    // Delete all cash flows for this investment first
    // Use timeout to handle offline scenario - Firestore will sync when back online
    try {
      final cashFlows = await _cashFlowsRef
          .where('investmentId', isEqualTo: id)
          .get(const GetOptions(source: Source.cache))
          .timeout(
            _writeTimeout,
            onTimeout: () async {
              // If cache query times out, try server with timeout
              return await _cashFlowsRef
                  .where('investmentId', isEqualTo: id)
                  .get()
                  .timeout(_writeTimeout);
            },
          );
      final batch = _firestore.batch();
      for (final doc in cashFlows.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_investmentsRef.doc(id));
      await _executeWrite(() => batch.commit());
    } on TimeoutException {
      // Offline - just delete the investment document, cash flows will be orphaned
      // but they're filtered out in the providers anyway
      await _executeWrite(() => _investmentsRef.doc(id).delete());
    }
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
  Future<InvestmentEntity?> getArchivedInvestmentById(String id) async {
    final doc = await _archivedInvestmentsRef.doc(id).get();
    if (!doc.exists) return null;
    return _investmentFromFirestore(doc.data()!, doc.id);
  }

  @override
  Future<void> deleteArchivedInvestment(String id) async {
    // Delete all archived cash flows for this investment first
    try {
      final cashFlows = await _archivedCashFlowsRef
          .where('investmentId', isEqualTo: id)
          .get();
      final batch = _firestore.batch();
      for (final doc in cashFlows.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_archivedInvestmentsRef.doc(id));
      await _executeWrite(() => batch.commit());
    } on TimeoutException {
      await _executeWrite(() => _archivedInvestmentsRef.doc(id).delete());
    }
  }

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
  Future<void> addCashFlow(CashFlowEntity cashFlow) async {
    await _executeWrite(
      () => _cashFlowsRef.doc(cashFlow.id).set(_cashFlowToFirestore(cashFlow)),
    );
  }

  @override
  Future<void> updateCashFlow(CashFlowEntity cashFlow) async {
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
  Future<int> bulkDelete(List<String> investmentIds) async {
    if (investmentIds.isEmpty) return 0;

    const batchLimit = 500;
    var deletedCount = 0;

    // First, collect all cash flows to delete
    final cashFlowDocsToDelete = <DocumentReference>[];
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
    }

    // Delete cash flows in batches
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

  Map<String, dynamic> _investmentToFirestore(InvestmentEntity investment) {
    return {
      'name': investment.name,
      'type': investment.type.name,
      'status': investment.status.name.toUpperCase(),
      'notes': investment.notes,
      'createdAt': Timestamp.fromDate(investment.createdAt),
      'closedAt': investment.closedAt != null
          ? Timestamp.fromDate(investment.closedAt!)
          : null,
      'updatedAt': FieldValue.serverTimestamp(),
      'maturityDate': investment.maturityDate != null
          ? Timestamp.fromDate(investment.maturityDate!)
          : null,
      'incomeFrequency': investment.incomeFrequency?.name,
      'isArchived': investment.isArchived,
    };
  }

  InvestmentEntity _investmentFromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    return InvestmentEntity(
      id: id,
      name: data['name'] as String,
      type: InvestmentType.fromString(data['type'] as String),
      status: InvestmentStatus.fromString(data['status'] as String),
      notes: data['notes'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      closedAt: data['closedAt'] != null
          ? (data['closedAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      maturityDate: data['maturityDate'] != null
          ? (data['maturityDate'] as Timestamp).toDate()
          : null,
      incomeFrequency: IncomeFrequency.fromString(
        data['incomeFrequency'] as String?,
      ),
      isArchived: data['isArchived'] as bool? ?? false,
    );
  }

  Map<String, dynamic> _cashFlowToFirestore(CashFlowEntity cashFlow) {
    return {
      'investmentId': cashFlow.investmentId,
      'date': Timestamp.fromDate(cashFlow.date),
      'type': cashFlow.type.toDbString(),
      'amount': cashFlow.amount,
      'notes': cashFlow.notes,
      'createdAt': Timestamp.fromDate(cashFlow.createdAt),
    };
  }

  CashFlowEntity _cashFlowFromFirestore(Map<String, dynamic> data, String id) {
    return CashFlowEntity(
      id: id,
      investmentId: data['investmentId'] as String,
      date: (data['date'] as Timestamp).toDate(),
      type: CashFlowType.fromString(data['type'] as String),
      amount: (data['amount'] as num).toDouble(),
      notes: data['notes'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}
