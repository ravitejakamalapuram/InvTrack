import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

abstract class InvestmentRepository {
  // Investments
  Stream<List<InvestmentEntity>> watchInvestmentsByPortfolio(String portfolioId);
  Future<List<InvestmentEntity>> getInvestmentsByPortfolio(String portfolioId);
  Future<List<InvestmentEntity>> getAllInvestments();
  Future<InvestmentEntity?> getInvestmentById(String id);
  Future<void> createInvestment(InvestmentEntity investment);
  Future<void> updateInvestment(InvestmentEntity investment);
  Future<void> deleteInvestment(String id);

  // Transactions
  Stream<List<TransactionEntity>> watchTransactionsByInvestment(String investmentId);
  Future<List<TransactionEntity>> getTransactionsByInvestment(String investmentId);
  Future<List<TransactionEntity>> getAllTransactions();
  Future<void> addTransaction(TransactionEntity transaction);
  Future<void> updateTransaction(TransactionEntity transaction);
  Future<void> deleteTransaction(String id);
}
