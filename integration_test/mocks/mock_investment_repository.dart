import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';
import 'package:mocktail/mocktail.dart';

/// Mock implementation of InvestmentRepository for testing.
class MockInvestmentRepository extends Mock implements InvestmentRepository {}

/// Fake implementation of InvestmentRepository for testing.
/// Maintains in-memory state for integration-style tests.
class FakeInvestmentRepository implements InvestmentRepository {
  final List<InvestmentEntity> _investments = [];
  final List<CashFlowEntity> _cashFlows = [];

  /// Access investments for test assertions
  List<InvestmentEntity> get investments => List.unmodifiable(_investments);

  /// Access cash flows for test assertions
  List<CashFlowEntity> get cashFlows => List.unmodifiable(_cashFlows);

  /// Reset state between tests
  void reset() {
    _investments.clear();
    _cashFlows.clear();
  }

  /// Seed with test data
  void seed({
    List<InvestmentEntity>? investments,
    List<CashFlowEntity>? cashFlows,
  }) {
    if (investments != null) _investments.addAll(investments);
    if (cashFlows != null) _cashFlows.addAll(cashFlows);
  }

  // ============ INVESTMENTS ============

  @override
  Stream<List<InvestmentEntity>> watchAllInvestments() {
    return Stream.value(List.from(_investments));
  }

  @override
  Stream<List<InvestmentEntity>> watchInvestmentsByStatus(InvestmentStatus status) {
    return Stream.value(
      _investments.where((i) => i.status == status).toList(),
    );
  }

  @override
  Future<List<InvestmentEntity>> getAllInvestments() async {
    return List.from(_investments);
  }

  @override
  Future<InvestmentEntity?> getInvestmentById(String id) async {
    return _investments.cast<InvestmentEntity?>().firstWhere(
          (i) => i?.id == id,
          orElse: () => null,
        );
  }

  @override
  Future<void> createInvestment(InvestmentEntity investment) async {
    _investments.add(investment);
  }

  @override
  Future<void> updateInvestment(InvestmentEntity investment) async {
    final index = _investments.indexWhere((i) => i.id == investment.id);
    if (index >= 0) {
      _investments[index] = investment;
    }
  }

  @override
  Future<void> closeInvestment(String id) async {
    final index = _investments.indexWhere((i) => i.id == id);
    if (index >= 0) {
      final inv = _investments[index];
      _investments[index] = inv.copyWith(
        status: InvestmentStatus.closed,
        closedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> reopenInvestment(String id) async {
    final index = _investments.indexWhere((i) => i.id == id);
    if (index >= 0) {
      final inv = _investments[index];
      // Create new entity without closedAt since copyWith can't set it to null
      _investments[index] = InvestmentEntity(
        id: inv.id,
        name: inv.name,
        type: inv.type,
        status: InvestmentStatus.open,
        notes: inv.notes,
        createdAt: inv.createdAt,
        closedAt: null,
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> archiveInvestment(String id) async {
    final index = _investments.indexWhere((i) => i.id == id);
    if (index >= 0) {
      final inv = _investments[index];
      _investments[index] = inv.copyWith(isArchived: true);
    }
  }

  @override
  Future<void> unarchiveInvestment(String id) async {
    final index = _investments.indexWhere((i) => i.id == id);
    if (index >= 0) {
      final inv = _investments[index];
      _investments[index] = inv.copyWith(isArchived: false);
    }
  }

  @override
  Future<void> deleteInvestment(String id) async {
    _investments.removeWhere((i) => i.id == id);
    _cashFlows.removeWhere((cf) => cf.investmentId == id);
  }

  // ============ CASH FLOWS ============

  @override
  Stream<List<CashFlowEntity>> watchAllCashFlows() {
    return Stream.value(List.from(_cashFlows));
  }

  @override
  Stream<List<CashFlowEntity>> watchCashFlowsByInvestment(String investmentId) {
    return Stream.value(
      _cashFlows.where((cf) => cf.investmentId == investmentId).toList(),
    );
  }

  @override
  Future<List<CashFlowEntity>> getCashFlowsByInvestment(String investmentId) async {
    return _cashFlows.where((cf) => cf.investmentId == investmentId).toList();
  }

  @override
  Future<List<CashFlowEntity>> getAllCashFlows() async {
    return List.from(_cashFlows);
  }

  @override
  Future<void> addCashFlow(CashFlowEntity cashFlow) async {
    _cashFlows.add(cashFlow);
  }

  @override
  Future<void> updateCashFlow(CashFlowEntity cashFlow) async {
    final index = _cashFlows.indexWhere((cf) => cf.id == cashFlow.id);
    if (index >= 0) {
      _cashFlows[index] = cashFlow;
    }
  }

  @override
  Future<void> deleteCashFlow(String id) async {
    _cashFlows.removeWhere((cf) => cf.id == id);
  }

  // ============ BULK OPERATIONS ============

  @override
  Future<({int investments, int cashFlows})> bulkImport({
    required List<InvestmentEntity> investments,
    required List<CashFlowEntity> cashFlows,
  }) async {
    _investments.addAll(investments);
    _cashFlows.addAll(cashFlows);
    return (investments: investments.length, cashFlows: cashFlows.length);
  }

  @override
  Future<int> bulkDelete(List<String> investmentIds) async {
    final count = investmentIds.length;
    for (final id in investmentIds) {
      _investments.removeWhere((i) => i.id == id);
      _cashFlows.removeWhere((cf) => cf.investmentId == id);
    }
    return count;
  }
}

