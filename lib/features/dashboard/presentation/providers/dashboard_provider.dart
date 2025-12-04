import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/portfolio/domain/entities/portfolio_entity.dart';
import 'package:inv_tracker/core/calculations/financial_calculator.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/portfolio/presentation/providers/portfolio_provider.dart';

  // Calculate Allocation
  final Map<String, double> allocation = {};
  for (final investment in allTransactions.map((e) => e.investmentId).toSet()) {
    // We need investment details (type) which we don't have easily here without fetching again or restructuring.
    // Optimization: We fetched investments earlier. We should map them.
  }
  
  // Re-fetching or restructuring for allocation
  // Let's do a simpler approach: iterate portfolios -> investments again or store them.
  // Better: Create a map of investmentId -> InvestmentEntity during the first loop.
  
  final Map<String, InvestmentEntity> investmentMap = {};
  
  // Refactored loop to populate investmentMap
  // We need to restart the logic slightly to be efficient.
  
  // Let's rewrite the provider body to be cleaner.
  return _calculateMetrics(ref, portfolios);
});

import 'package:flutter/foundation.dart';

// ...

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
        // Sort only if needed, but here we need latest price.
        // Optimization: If transactions are already sorted or we just find max date.
        // Let's assume we need to sort.
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
  // Optimization: Sort all transactions by date once
  final sortedTransactions = List<TransactionEntity>.from(data.transactions);
  sortedTransactions.sort((a, b) => a.date.compareTo(b.date));

  for (int i = 30; i >= 0; i--) {
    final date = now.subtract(Duration(days: i));
    
    // Calculate cumulative invested amount up to this date
    // Since transactions are sorted, we can optimize this loop if we want, 
    // but for 30 points and 10k transactions, O(30*N) is acceptable in isolate.
    // Better: Iterate transactions once and fill buckets.
    
    double investedAtDate = 0;
    for (final t in sortedTransactions) {
      if (t.date.isAfter(date)) break; // Optimization since sorted
      
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
    dayChange: profitLoss, 
    dayChangePercent: profitLossPercent,
    allocation: allocation,
    historicalData: historicalData,
  );
}

class DashboardMetrics {
  final double totalValue;
  final double dayChange;
  final double dayChangePercent;
  final Map<String, double> allocation;
  final Map<DateTime, double> historicalData;

  const DashboardMetrics({
    required this.totalValue,
    required this.dayChange,
    required this.dayChangePercent,
    this.allocation = const {},
    this.historicalData = const {},
  });
}
