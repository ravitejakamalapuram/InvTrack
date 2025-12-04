import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
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
