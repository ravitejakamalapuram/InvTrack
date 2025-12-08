import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/calculations/financial_calculator.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/portfolio/presentation/providers/portfolio_provider.dart';

/// Time period for insights analysis
enum InsightsPeriod { oneMonth, threeMonths, sixMonths, oneYear, all }

/// Metrics for a single investment
class InvestmentInsight {
  final InvestmentEntity investment;
  final double currentValue;
  final double totalInvested;
  final double profitLoss;
  final double profitLossPercent;
  final double xirr;
  final double moic;
  final double allocationPercent;

  const InvestmentInsight({
    required this.investment,
    required this.currentValue,
    required this.totalInvested,
    required this.profitLoss,
    required this.profitLossPercent,
    required this.xirr,
    required this.moic,
    required this.allocationPercent,
  });
}

/// Overall insights data
class InsightsData {
  final double totalValue;
  final double totalInvested;
  final double totalProfitLoss;
  final double totalProfitLossPercent;
  final double portfolioXirr;
  final double portfolioMoic;
  final Map<String, double> allocationByType;
  final List<InvestmentInsight> investments;
  final Map<DateTime, double> valueHistory;
  final Map<DateTime, double> investedHistory;

  const InsightsData({
    required this.totalValue,
    required this.totalInvested,
    required this.totalProfitLoss,
    required this.totalProfitLossPercent,
    required this.portfolioXirr,
    required this.portfolioMoic,
    required this.allocationByType,
    required this.investments,
    required this.valueHistory,
    required this.investedHistory,
  });

  static const empty = InsightsData(
    totalValue: 0,
    totalInvested: 0,
    totalProfitLoss: 0,
    totalProfitLossPercent: 0,
    portfolioXirr: 0,
    portfolioMoic: 0,
    allocationByType: {},
    investments: [],
    valueHistory: {},
    investedHistory: {},
  );
}

/// Selected period state
final insightsPeriodProvider = StateProvider<InsightsPeriod>((ref) => InsightsPeriod.all);

/// Main insights data provider
final insightsDataProvider = FutureProvider<InsightsData>((ref) async {
  final portfolios = await ref.watch(allPortfoliosProvider.future);
  if (portfolios.isEmpty) return InsightsData.empty;

  final investments = await ref.read(investmentRepositoryProvider).getAllInvestments();
  final transactions = await ref.read(investmentRepositoryProvider).getAllTransactions();

  return compute(_calculateInsights, _InsightsInput(investments, transactions));
});

class _InsightsInput {
  final List<InvestmentEntity> investments;
  final List<TransactionEntity> transactions;
  _InsightsInput(this.investments, this.transactions);
}

Future<InsightsData> _calculateInsights(_InsightsInput input) async {
  if (input.investments.isEmpty) return InsightsData.empty;

  final transactionsByInvestment = <String, List<TransactionEntity>>{};
  for (final t in input.transactions) {
    transactionsByInvestment.putIfAbsent(t.investmentId, () => []).add(t);
  }

  double totalValue = 0;
  double totalInvested = 0;
  final allocationByType = <String, double>{};
  final investmentInsights = <InvestmentInsight>[];
  final allTransactionsForXirr = <TransactionEntity>[];

  for (final inv in input.investments) {
    final txns = transactionsByInvestment[inv.id] ?? [];
    if (txns.isEmpty) continue;

    allTransactionsForXirr.addAll(txns);

    // Calculate quantity and current value from transactions
    double quantity = 0;
    double lastPrice = 0;
    final sortedTxns = List<TransactionEntity>.from(txns)
      ..sort((a, b) => b.date.compareTo(a.date));

    for (final t in txns) {
      if (t.type == 'BUY') {
        quantity += t.quantity;
      } else if (t.type == 'SELL') {
        quantity -= t.quantity;
      }
    }

    // Use the most recent transaction's price as current price
    if (sortedTxns.isNotEmpty) {
      lastPrice = sortedTxns.first.pricePerUnit;
    }

    final currentVal = quantity * lastPrice;
    final invested = FinancialCalculator.calculateTotalInvested(txns);
    final pnl = FinancialCalculator.calculateProfitLoss(invested, currentVal);
    final pnlPercent = invested > 0 ? (pnl / invested) * 100 : 0.0;
    final xirr = FinancialCalculator.calculateXirr(txns, currentVal);
    final moic = FinancialCalculator.calculateMOIC(invested, currentVal);

    totalValue += currentVal;
    totalInvested += invested > 0 ? invested : 0;
    allocationByType[inv.type] = (allocationByType[inv.type] ?? 0) + currentVal;

    investmentInsights.add(InvestmentInsight(
      investment: inv,
      currentValue: currentVal,
      totalInvested: invested,
      profitLoss: pnl,
      profitLossPercent: pnlPercent,
      xirr: xirr * 100,
      moic: moic,
      allocationPercent: 0, // Will calculate after totals
    ));
  }

  // Calculate allocation percentages
  final insightsWithAllocation = investmentInsights.map((i) => InvestmentInsight(
    investment: i.investment,
    currentValue: i.currentValue,
    totalInvested: i.totalInvested,
    profitLoss: i.profitLoss,
    profitLossPercent: i.profitLossPercent,
    xirr: i.xirr,
    moic: i.moic,
    allocationPercent: totalValue > 0 ? (i.currentValue / totalValue) * 100 : 0,
  )).toList();

  // Sort by current value descending
  insightsWithAllocation.sort((a, b) => b.currentValue.compareTo(a.currentValue));

  final totalPnl = FinancialCalculator.calculateProfitLoss(totalInvested, totalValue);
  final totalPnlPercent = totalInvested > 0 ? (totalPnl / totalInvested) * 100 : 0.0;
  final portfolioXirr = FinancialCalculator.calculateXirr(allTransactionsForXirr, totalValue);
  final portfolioMoic = FinancialCalculator.calculateMOIC(totalInvested, totalValue);

  return InsightsData(
    totalValue: totalValue,
    totalInvested: totalInvested,
    totalProfitLoss: totalPnl,
    totalProfitLossPercent: totalPnlPercent,
    portfolioXirr: portfolioXirr * 100,
    portfolioMoic: portfolioMoic,
    allocationByType: allocationByType,
    investments: insightsWithAllocation,
    valueHistory: {},
    investedHistory: {},
  );
}

