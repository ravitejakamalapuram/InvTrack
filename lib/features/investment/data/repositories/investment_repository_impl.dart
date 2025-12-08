import 'package:drift/drift.dart';
import 'package:inv_tracker/core/database/app_database.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';

class InvestmentRepositoryImpl implements InvestmentRepository {
  final AppDatabase _db;

  InvestmentRepositoryImpl(this._db);

  // Investments

  @override
  Stream<List<InvestmentEntity>> watchInvestmentsByPortfolio(String portfolioId) {
    return (_db.select(_db.investments)..where((tbl) => tbl.portfolioId.equals(portfolioId)))
        .watch()
        .map((rows) => rows.map(_mapInvestmentRowToEntity).toList());
  }

  @override
  Future<List<InvestmentEntity>> getInvestmentsByPortfolio(String portfolioId) async {
    final rows = await (_db.select(_db.investments)..where((tbl) => tbl.portfolioId.equals(portfolioId))).get();
    return rows.map(_mapInvestmentRowToEntity).toList();
  }

  @override
  Future<List<InvestmentEntity>> getAllInvestments() async {
    final rows = await _db.select(_db.investments).get();
    return rows.map(_mapInvestmentRowToEntity).toList();
  }

  @override
  Future<InvestmentEntity?> getInvestmentById(String id) async {
    final row = await (_db.select(_db.investments)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    return row != null ? _mapInvestmentRowToEntity(row) : null;
  }

  @override
  Future<void> createInvestment(InvestmentEntity investment) async {
    await _db.into(_db.investments).insert(
          InvestmentsCompanion(
            id: Value(investment.id),
            portfolioId: Value(investment.portfolioId),
            name: Value(investment.name),
            symbol: Value(investment.symbol),
            type: Value(investment.type),
            isActive: Value(investment.isActive),
            createdAt: Value(investment.createdAt),
            updatedAt: Value(investment.updatedAt),
          ),
        );
  }

  @override
  Future<void> updateInvestment(InvestmentEntity investment) async {
    await (_db.update(_db.investments)..where((tbl) => tbl.id.equals(investment.id))).write(
      InvestmentsCompanion(
        name: Value(investment.name),
        symbol: Value(investment.symbol),
        type: Value(investment.type),
        isActive: Value(investment.isActive),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deleteInvestment(String id) async {
    await (_db.delete(_db.investments)..where((tbl) => tbl.id.equals(id))).go();
  }

  // Transactions

  @override
  Stream<List<TransactionEntity>> watchTransactionsByInvestment(String investmentId) {
    return (_db.select(_db.transactions)..where((tbl) => tbl.investmentId.equals(investmentId)))
        .watch()
        .map((rows) => rows.map(_mapTransactionRowToEntity).toList());
  }

  @override
  Future<List<TransactionEntity>> getTransactionsByInvestment(String investmentId) async {
    final rows = await (_db.select(_db.transactions)..where((tbl) => tbl.investmentId.equals(investmentId))).get();
    return rows.map(_mapTransactionRowToEntity).toList();
  }

  @override
  Future<List<TransactionEntity>> getAllTransactions() async {
    final rows = await _db.select(_db.transactions).get();
    return rows.map(_mapTransactionRowToEntity).toList();
  }

  @override
  Future<void> addTransaction(TransactionEntity transaction) async {
    await _db.into(_db.transactions).insert(
          TransactionsCompanion(
            id: Value(transaction.id),
            investmentId: Value(transaction.investmentId),
            date: Value(transaction.date),
            type: Value(transaction.type),
            quantity: Value(transaction.quantity),
            pricePerUnit: Value(transaction.pricePerUnit),
            fees: Value(transaction.fees),
            totalAmount: Value(transaction.totalAmount),
            notes: Value(transaction.notes),
            createdAt: Value(transaction.createdAt),
          ),
        );
  }

  @override
  Future<void> updateTransaction(TransactionEntity transaction) async {
    await (_db.update(_db.transactions)..where((tbl) => tbl.id.equals(transaction.id))).write(
      TransactionsCompanion(
        date: Value(transaction.date),
        type: Value(transaction.type),
        quantity: Value(transaction.quantity),
        pricePerUnit: Value(transaction.pricePerUnit),
        fees: Value(transaction.fees),
        totalAmount: Value(transaction.totalAmount),
        notes: Value(transaction.notes),
      ),
    );
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await (_db.delete(_db.transactions)..where((tbl) => tbl.id.equals(id))).go();
  }

  InvestmentEntity _mapInvestmentRowToEntity(Investment row) {
    return InvestmentEntity(
      id: row.id,
      portfolioId: row.portfolioId,
      name: row.name,
      symbol: row.symbol,
      type: row.type,
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  TransactionEntity _mapTransactionRowToEntity(Transaction row) {
    return TransactionEntity(
      id: row.id,
      investmentId: row.investmentId,
      date: row.date,
      type: row.type,
      quantity: row.quantity,
      pricePerUnit: row.pricePerUnit,
      fees: row.fees,
      totalAmount: row.totalAmount,
      notes: row.notes,
      createdAt: row.createdAt,
    );
  }
}
