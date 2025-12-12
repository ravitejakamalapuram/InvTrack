import 'package:drift/drift.dart';
import 'package:inv_tracker/core/database/app_database.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';

/// Repository implementation for Cash Flow Investment Tracker
class InvestmentRepositoryImpl implements InvestmentRepository {
  final AppDatabase _db;

  InvestmentRepositoryImpl(this._db);

  // ============ INVESTMENTS ============

  @override
  Stream<List<InvestmentEntity>> watchAllInvestments() {
    final query = _db.select(_db.investments)
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]);
    return query.watch().map((rows) => rows.map(_mapInvestmentRowToEntity).toList());
  }

  @override
  Stream<List<InvestmentEntity>> watchInvestmentsByStatus(InvestmentStatus status) {
    final query = _db.select(_db.investments)
      ..where((tbl) => tbl.status.equals(status.name.toUpperCase()))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]);
    return query.watch().map((rows) => rows.map(_mapInvestmentRowToEntity).toList());
  }

  @override
  Future<List<InvestmentEntity>> getAllInvestments() async {
    final query = _db.select(_db.investments)
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]);
    final rows = await query.get();
    return rows.map(_mapInvestmentRowToEntity).toList();
  }

  @override
  Future<InvestmentEntity?> getInvestmentById(String id) async {
    final row = await (_db.select(_db.investments)
          ..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
    return row != null ? _mapInvestmentRowToEntity(row) : null;
  }

  @override
  Future<void> createInvestment(InvestmentEntity investment) async {
    await _db.into(_db.investments).insert(
          InvestmentsCompanion(
            id: Value(investment.id),
            name: Value(investment.name),
            type: Value(investment.type.name),
            status: Value(investment.status.name.toUpperCase()),
            notes: Value(investment.notes),
            createdAt: Value(investment.createdAt),
            closedAt: Value(investment.closedAt),
            updatedAt: Value(investment.updatedAt),
          ),
        );
  }

  @override
  Future<void> updateInvestment(InvestmentEntity investment) async {
    await (_db.update(_db.investments)..where((tbl) => tbl.id.equals(investment.id))).write(
      InvestmentsCompanion(
        name: Value(investment.name),
        type: Value(investment.type.name),
        status: Value(investment.status.name.toUpperCase()),
        notes: Value(investment.notes),
        closedAt: Value(investment.closedAt),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> closeInvestment(String id) async {
    await (_db.update(_db.investments)..where((tbl) => tbl.id.equals(id))).write(
      InvestmentsCompanion(
        status: const Value('CLOSED'),
        closedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> reopenInvestment(String id) async {
    await (_db.update(_db.investments)..where((tbl) => tbl.id.equals(id))).write(
      InvestmentsCompanion(
        status: const Value('OPEN'),
        closedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deleteInvestment(String id) async {
    // Delete all cash flows first
    await (_db.delete(_db.cashFlows)..where((tbl) => tbl.investmentId.equals(id))).go();
    // Then delete the investment
    await (_db.delete(_db.investments)..where((tbl) => tbl.id.equals(id))).go();
  }

  // ============ CASH FLOWS ============

  @override
  Stream<List<CashFlowEntity>> watchCashFlowsByInvestment(String investmentId) {
    final query = _db.select(_db.cashFlows)
      ..where((tbl) => tbl.investmentId.equals(investmentId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.date)]);
    return query.watch().map((rows) => rows.map(_mapCashFlowRowToEntity).toList());
  }

  @override
  Future<List<CashFlowEntity>> getCashFlowsByInvestment(String investmentId) async {
    final query = _db.select(_db.cashFlows)
      ..where((tbl) => tbl.investmentId.equals(investmentId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.date)]);
    final rows = await query.get();
    return rows.map(_mapCashFlowRowToEntity).toList();
  }

  @override
  Future<List<CashFlowEntity>> getAllCashFlows() async {
    final query = _db.select(_db.cashFlows)
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.date)]);
    final rows = await query.get();
    return rows.map(_mapCashFlowRowToEntity).toList();
  }

  @override
  Future<void> addCashFlow(CashFlowEntity cashFlow) async {
    await _db.into(_db.cashFlows).insert(
          CashFlowsCompanion(
            id: Value(cashFlow.id),
            investmentId: Value(cashFlow.investmentId),
            date: Value(cashFlow.date),
            type: Value(cashFlow.type.toDbString()),
            amount: Value(cashFlow.amount),
            notes: Value(cashFlow.notes),
            createdAt: Value(cashFlow.createdAt),
          ),
        );
  }

  @override
  Future<void> updateCashFlow(CashFlowEntity cashFlow) async {
    await (_db.update(_db.cashFlows)..where((tbl) => tbl.id.equals(cashFlow.id))).write(
      CashFlowsCompanion(
        date: Value(cashFlow.date),
        type: Value(cashFlow.type.toDbString()),
        amount: Value(cashFlow.amount),
        notes: Value(cashFlow.notes),
      ),
    );
  }

  @override
  Future<void> deleteCashFlow(String id) async {
    await (_db.delete(_db.cashFlows)..where((tbl) => tbl.id.equals(id))).go();
  }

  // ============ BULK CACHE OPERATIONS ============

  @override
  Future<void> replaceAllData(
    List<InvestmentEntity> investments,
    List<CashFlowEntity> cashFlows,
  ) async {
    await _db.transaction(() async {
      // Clear existing data
      await _db.delete(_db.cashFlows).go();
      await _db.delete(_db.investments).go();

      // Insert new investments
      for (final investment in investments) {
        await _db.into(_db.investments).insert(
              InvestmentsCompanion(
                id: Value(investment.id),
                name: Value(investment.name),
                type: Value(investment.type.name),
                status: Value(investment.status.name.toUpperCase()),
                notes: Value(investment.notes),
                createdAt: Value(investment.createdAt),
                closedAt: Value(investment.closedAt),
                updatedAt: Value(investment.updatedAt),
              ),
            );
      }

      // Insert new cash flows
      for (final cashFlow in cashFlows) {
        await _db.into(_db.cashFlows).insert(
              CashFlowsCompanion(
                id: Value(cashFlow.id),
                investmentId: Value(cashFlow.investmentId),
                date: Value(cashFlow.date),
                type: Value(cashFlow.type.toDbString()),
                amount: Value(cashFlow.amount),
                notes: Value(cashFlow.notes),
                createdAt: Value(cashFlow.createdAt),
              ),
            );
      }
    });
  }

  @override
  Future<void> clearAllData() async {
    await _db.transaction(() async {
      await _db.delete(_db.cashFlows).go();
      await _db.delete(_db.investments).go();
    });
  }

  @override
  Future<bool> hasData() async {
    final count = await getInvestmentCount();
    return count > 0;
  }

  @override
  Future<int> getInvestmentCount() async {
    final query = _db.selectOnly(_db.investments)
      ..addColumns([_db.investments.id.count()]);
    final result = await query.getSingle();
    return result.read(_db.investments.id.count()) ?? 0;
  }

  // ============ MAPPERS ============

  InvestmentEntity _mapInvestmentRowToEntity(Investment row) {
    return InvestmentEntity(
      id: row.id,
      name: row.name,
      type: InvestmentType.fromString(row.type),
      status: InvestmentStatus.fromString(row.status),
      notes: row.notes,
      createdAt: row.createdAt,
      closedAt: row.closedAt,
      updatedAt: row.updatedAt,
    );
  }

  CashFlowEntity _mapCashFlowRowToEntity(CashFlow row) {
    return CashFlowEntity(
      id: row.id,
      investmentId: row.investmentId,
      date: row.date,
      type: CashFlowType.fromString(row.type),
      amount: row.amount,
      notes: row.notes,
      createdAt: row.createdAt,
    );
  }
}
