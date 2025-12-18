import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';

/// Firestore-based implementation of InvestmentRepository
/// Provides offline persistence and real-time sync across devices
class FirestoreInvestmentRepository implements InvestmentRepository {
  final FirebaseFirestore _firestore;
  final String _userId;

  FirestoreInvestmentRepository({
    required FirebaseFirestore firestore,
    required String userId,
  })  : _firestore = firestore,
        _userId = userId;

  // Collection references
  CollectionReference<Map<String, dynamic>> get _investmentsRef =>
      _firestore.collection('users').doc(_userId).collection('investments');

  CollectionReference<Map<String, dynamic>> get _cashFlowsRef =>
      _firestore.collection('users').doc(_userId).collection('cashflows');

  // ============ INVESTMENTS ============

  @override
  Stream<List<InvestmentEntity>> watchAllInvestments() {
    return _investmentsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _investmentFromFirestore(doc.data(), doc.id))
            .toList());
  }

  @override
  Stream<List<InvestmentEntity>> watchInvestmentsByStatus(InvestmentStatus status) {
    return _investmentsRef
        .where('status', isEqualTo: status.name.toUpperCase())
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _investmentFromFirestore(doc.data(), doc.id))
            .toList());
  }

  @override
  Future<List<InvestmentEntity>> getAllInvestments() async {
    final snapshot = await _investmentsRef.orderBy('createdAt', descending: true).get();
    return snapshot.docs
        .map((doc) => _investmentFromFirestore(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<InvestmentEntity?> getInvestmentById(String id) async {
    final doc = await _investmentsRef.doc(id).get();
    if (!doc.exists) return null;
    return _investmentFromFirestore(doc.data()!, doc.id);
  }

  @override
  Future<void> createInvestment(InvestmentEntity investment) async {
    await _investmentsRef.doc(investment.id).set(_investmentToFirestore(investment));
  }

  @override
  Future<void> updateInvestment(InvestmentEntity investment) async {
    await _investmentsRef.doc(investment.id).update(_investmentToFirestore(investment));
  }

  @override
  Future<void> closeInvestment(String id) async {
    await _investmentsRef.doc(id).update({
      'status': 'CLOSED',
      'closedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> reopenInvestment(String id) async {
    await _investmentsRef.doc(id).update({
      'status': 'OPEN',
      'closedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteInvestment(String id) async {
    // Delete all cash flows for this investment first
    final cashFlows = await _cashFlowsRef.where('investmentId', isEqualTo: id).get();
    final batch = _firestore.batch();
    for (final doc in cashFlows.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_investmentsRef.doc(id));
    await batch.commit();
  }

  // ============ CASH FLOWS ============

  @override
  Stream<List<CashFlowEntity>> watchCashFlowsByInvestment(String investmentId) {
    return _cashFlowsRef
        .where('investmentId', isEqualTo: investmentId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _cashFlowFromFirestore(doc.data(), doc.id))
            .toList());
  }

  @override
  Future<List<CashFlowEntity>> getCashFlowsByInvestment(String investmentId) async {
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
    final snapshot = await _cashFlowsRef.orderBy('date', descending: true).get();
    return snapshot.docs
        .map((doc) => _cashFlowFromFirestore(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<void> addCashFlow(CashFlowEntity cashFlow) async {
    await _cashFlowsRef.doc(cashFlow.id).set(_cashFlowToFirestore(cashFlow));
  }

  @override
  Future<void> updateCashFlow(CashFlowEntity cashFlow) async {
    await _cashFlowsRef.doc(cashFlow.id).update(_cashFlowToFirestore(cashFlow));
  }

  @override
  Future<void> deleteCashFlow(String id) async {
    await _cashFlowsRef.doc(id).delete();
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
    };
  }

  InvestmentEntity _investmentFromFirestore(Map<String, dynamic> data, String id) {
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

