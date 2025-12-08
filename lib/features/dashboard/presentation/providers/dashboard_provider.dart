import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/calculations/financial_calculator.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/portfolio/domain/entities/portfolio_entity.dart';
import 'package:inv_tracker/features/portfolio/presentation/providers/portfolio_provider.dart';

final dashboardMetricsProvider = FutureProvider<DashboardMetrics>((ref) async {
  final portfolios = await ref.watch(allPortfoliosProvider.future);
  if (portfolios.isEmpty) {
    return const DashboardMetrics(
      totalValue: 0,
      dayChange: 0,
      dayChangePercent: 0,
    );
  }

  // Batch fetch all data
  final investments = await ref.read(investmentRepositoryProvider).getAllInvestments();
  final transactions = await ref.read(investmentRepositoryProvider).getAllTransactions();

  // Use compute for heavy calculation
  return compute(_calculateMetricsIsolated, _CalculationData(portfolios, investments, transactions));
});

// Data class for passing data to isolate
class _CalculationData {
  final List<PortfolioEntity> portfolios;
  final List<InvestmentEntity> investments;
  final List<TransactionEntity> transactions;

  _CalculationData(this.portfolios, this.investments, this.transactions);
}

Future<DashboardMetrics> _calculateMetricsIsolated(_CalculationData data) async {
  double totalValue = 0;
  double totalInvested = 0;
  final Map<String, double> allocation = {};
  final Map<DateTime, double> historicalData = {};

  // Create maps for faster lookup
  final investmentsByPortfolio = <String, List<InvestmentEntity>>{};
  for (final inv in data.investments) {
    investmentsByPortfolio.putIfAbsent(inv.portfolioId, () => []).add(inv);
  }

  final transactionsByInvestment = <String, List<TransactionEntity>>{};
  for (final t in data.transactions) {
    transactionsByInvestment.putIfAbsent(t.investmentId, () => []).add(t);
  }

  for (final portfolio in data.portfolios) {
    final portfolioInvestments = investmentsByPortfolio[portfolio.id] ?? [];
    
    for (final investment in portfolioInvestments) {
      final investmentTransactions = transactionsByInvestment[investment.id] ?? [];
      
      double quantity = 0;
      for (final t in investmentTransactions) {
        if (t.type == 'BUY') {
          quantity += t.quantity;
        } else if (t.type == 'SELL') {
          quantity -= t.quantity;
        }
      }
      
      double currentPrice = 0;
      if (investmentTransactions.isNotEmpty) {
        investmentTransactions.sort((a, b) => b.date.compareTo(a.date));
        currentPrice = investmentTransactions.first.pricePerUnit;
      }
      
      double investmentValue = quantity * currentPrice;
      totalValue += investmentValue;
      
      // Allocation
      final type = investment.type;
      allocation[type] = (allocation[type] ?? 0) + investmentValue;
    }
  }
  
  totalInvested = FinancialCalculator.calculateTotalInvested(data.transactions);
  
  // Calculate P&L
  final profitLoss = FinancialCalculator.calculateProfitLoss(totalInvested, totalValue);
  final profitLossPercent = totalInvested > 0 ? (profitLoss / totalInvested) * 100 : 0.0;

  // Historical Data (Invested Capital Over Time)
  final now = DateTime.now();
  final sortedTransactions = List<TransactionEntity>.from(data.transactions);
  sortedTransactions.sort((a, b) => a.date.compareTo(b.date));

  for (int i = 30; i >= 0; i--) {
    final date = now.subtract(Duration(days: i));
    
    double investedAtDate = 0;
    for (final t in sortedTransactions) {
      if (t.date.isAfter(date)) break;
      
      if (t.type == 'BUY') {
        investedAtDate += t.totalAmount;
      } else if (t.type == 'SELL') {
        investedAtDate -= t.totalAmount;
      }
    }
    historicalData[date] = investedAtDate;
  }

  return DashboardMetrics(
    totalValue: totalValue,
    totalInvested: totalInvested,
    totalReturnPercent: profitLossPercent,
    dayChange: profitLoss,
    dayChangePercent: profitLossPercent,
    allocation: allocation,
    historicalData: historicalData,
  );
}

class DashboardMetrics {
  final double totalValue;
  final double totalInvested;
  final double totalReturnPercent;
  final double dayChange;
  final double dayChangePercent;
  final Map<String, double> allocation;
  final Map<DateTime, double> historicalData;

  const DashboardMetrics({
    required this.totalValue,
    this.totalInvested = 0,
    this.totalReturnPercent = 0,
    required this.dayChange,
    required this.dayChangePercent,
    this.allocation = const {},
    this.historicalData = const {},
  });
}

/// Recent transaction with investment name for display
class RecentTransaction {
  final TransactionEntity transaction;
  final String investmentName;

  const RecentTransaction({
    required this.transaction,
    required this.investmentName,
  });
}

/// Provider for recent transactions (last 5)
final recentTransactionsProvider = FutureProvider<List<RecentTransaction>>((ref) async {
  final investments = await ref.read(investmentRepositoryProvider).getAllInvestments();
  final transactions = await ref.read(investmentRepositoryProvider).getAllTransactions();

  if (transactions.isEmpty) return [];

  // Create investment name lookup
  final investmentNames = <String, String>{};
  for (final inv in investments) {
    investmentNames[inv.id] = inv.name;
  }

  // Sort by date descending and take last 5
  final sorted = List<TransactionEntity>.from(transactions);
  sorted.sort((a, b) => b.date.compareTo(a.date));
  final recent = sorted.take(5).toList();

  return recent.map((t) => RecentTransaction(
    transaction: t,
    investmentName: investmentNames[t.investmentId] ?? 'Unknown',
  )).toList();
});
