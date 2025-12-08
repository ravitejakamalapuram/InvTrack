import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/insights/presentation/providers/insights_provider.dart'
    show insightsDataProvider;
import 'package:uuid/uuid.dart';

final investmentProvider = StateNotifierProvider<InvestmentNotifier, AsyncValue<void>>((ref) {
  return InvestmentNotifier(ref);
});

class InvestmentNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  InvestmentNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> addInvestment({
    required String name,
    String? symbol,
    required String type,
    required String portfolioId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final investment = InvestmentEntity(
        id: const Uuid().v4(),
        portfolioId: portfolioId,
        name: name,
        symbol: symbol,
        type: type,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _ref.read(investmentRepositoryProvider).createInvestment(investment);

      // Invalidate dashboard and insights providers to trigger refresh
      _ref.invalidate(dashboardMetricsProvider);
      _ref.invalidate(insightsDataProvider);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
  Future<void> addTransaction({
    required String investmentId,
    required String type,
    required DateTime date,
    required double quantity,
    required double pricePerUnit,
    required double fees,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final transaction = TransactionEntity(
        id: const Uuid().v4(),
        investmentId: investmentId,
        date: date,
        type: type,
        quantity: quantity,
        pricePerUnit: pricePerUnit,
        fees: fees,
        totalAmount: (quantity * pricePerUnit) + fees, // Simple calc for now
        notes: notes,
        createdAt: DateTime.now(),
      );
      await _ref.read(investmentRepositoryProvider).addTransaction(transaction);

      // Invalidate dashboard and insights providers to trigger refresh
      _ref.invalidate(dashboardMetricsProvider);
      _ref.invalidate(recentTransactionsProvider);
      _ref.invalidate(insightsDataProvider);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteTransaction(String id) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(investmentRepositoryProvider).deleteTransaction(id);

      // Invalidate dashboard and insights providers to trigger refresh
      _ref.invalidate(dashboardMetricsProvider);
      _ref.invalidate(recentTransactionsProvider);
      _ref.invalidate(insightsDataProvider);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteInvestment(String id) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(investmentRepositoryProvider).deleteInvestment(id);

      // Invalidate dashboard and insights providers to trigger refresh
      _ref.invalidate(dashboardMetricsProvider);
      _ref.invalidate(recentTransactionsProvider);
      _ref.invalidate(insightsDataProvider);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateInvestment({
    required String id,
    required String name,
    String? symbol,
    required String type,
    required String portfolioId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final existing = await _ref.read(investmentRepositoryProvider).getInvestmentById(id);
      if (existing == null) {
        throw Exception('Investment not found');
      }

      final updated = InvestmentEntity(
        id: id,
        portfolioId: portfolioId,
        name: name,
        symbol: symbol,
        type: type,
        isActive: existing.isActive,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
      );
      await _ref.read(investmentRepositoryProvider).updateInvestment(updated);

      // Invalidate dashboard and insights providers to trigger refresh
      _ref.invalidate(dashboardMetricsProvider);
      _ref.invalidate(insightsDataProvider);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final investmentsByPortfolioProvider = StreamProvider.family<List<InvestmentEntity>, String>((ref, portfolioId) {
  return ref.watch(investmentRepositoryProvider).watchInvestmentsByPortfolio(portfolioId);
});

final transactionsByInvestmentProvider = StreamProvider.family<List<TransactionEntity>, String>((ref, investmentId) {
  return ref.watch(investmentRepositoryProvider).watchTransactionsByInvestment(investmentId);
});

/// Calculates investment stats (current value, P/L, P/L%) for a single investment
class InvestmentStats {
  final double currentValue;
  final double investedAmount;
  final double profitLoss;
  final double profitLossPercent;
  final double quantity;

  InvestmentStats({
    required this.currentValue,
    required this.investedAmount,
    required this.profitLoss,
    required this.profitLossPercent,
    required this.quantity,
  });
}

final investmentStatsProvider = FutureProvider.family<InvestmentStats?, String>((ref, investmentId) async {
  final transactions = await ref.watch(investmentRepositoryProvider).getTransactionsByInvestment(investmentId);

  if (transactions.isEmpty) {
    return null;
  }

  double quantity = 0;
  double invested = 0;
  double lastPrice = 0;

  // Sort by date to get last price
  final sortedTx = List<TransactionEntity>.from(transactions)
    ..sort((a, b) => a.date.compareTo(b.date));

  for (final tx in sortedTx) {
    final type = tx.type.toUpperCase();
    if (type == 'BUY') {
      quantity += tx.quantity;
      invested += tx.totalAmount;
      lastPrice = tx.pricePerUnit;
    } else if (type == 'SELL') {
      quantity -= tx.quantity;
      // Don't reduce invested for P&L calculation
      lastPrice = tx.pricePerUnit;
    } else if (type == 'DIVIDEND') {
      // Dividends don't affect quantity or invested
      lastPrice = tx.pricePerUnit > 0 ? tx.pricePerUnit : lastPrice;
    }
  }

  final currentValue = quantity * lastPrice;
  final profitLoss = currentValue - invested;
  final profitLossPercent = invested > 0 ? (profitLoss / invested) * 100 : 0.0;

  return InvestmentStats(
    currentValue: currentValue,
    investedAmount: invested,
    profitLoss: profitLoss,
    profitLossPercent: profitLossPercent,
    quantity: quantity,
  );
});
