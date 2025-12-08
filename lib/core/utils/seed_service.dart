import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/portfolio/domain/entities/portfolio_entity.dart';
import 'package:uuid/uuid.dart';

final seedServiceProvider = Provider<SeedService>((ref) {
  return SeedService(ref);
});

class SeedService {
  final Ref _ref;
  final _random = Random();

  SeedService(this._ref);

  Future<void> seedData({int transactionCount = 10000}) async {
    final portfolioRepo = _ref.read(portfolioRepositoryProvider);
    final investmentRepo = _ref.read(investmentRepositoryProvider);

    // 1. Create a Test Portfolio
    final portfolioId = const Uuid().v4();
    final portfolio = PortfolioEntity(
      id: portfolioId,
      name: 'Performance Test Portfolio',
      currency: 'USD',
      createdAt: DateTime.now(),
    );
    await portfolioRepo.createPortfolio(portfolio);

    // 2. Create some Investments
    final investments = <InvestmentEntity>[];
    final symbols = ['AAPL', 'GOOGL', 'MSFT', 'AMZN', 'TSLA', 'BTC', 'ETH', 'NVDA', 'META', 'NFLX'];
    
    for (final symbol in symbols) {
      final investment = InvestmentEntity(
        id: const Uuid().v4(),
        portfolioId: portfolioId,
        name: symbol,
        symbol: symbol,
        type: _random.nextBool() ? 'Stock' : 'Crypto',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await investmentRepo.createInvestment(investment);
      investments.add(investment);
    }

    // 3. Generate Transactions
    final transactions = <TransactionEntity>[];
    final startDate = DateTime.now().subtract(const Duration(days: 365 * 5)); // 5 years history

    for (int i = 0; i < transactionCount; i++) {
      final investment = investments[_random.nextInt(investments.length)];
      final date = startDate.add(Duration(days: _random.nextInt(365 * 5)));
      final type = _random.nextDouble() > 0.3 ? 'BUY' : 'SELL'; // 70% Buys
      final quantity = _random.nextDouble() * 10 + 1; // 1 to 11 units
      final price = _random.nextDouble() * 1000 + 100; // 100 to 1100 price

      transactions.add(TransactionEntity(
        id: const Uuid().v4(),
        investmentId: investment.id,
        date: date,
        type: type,
        quantity: quantity,
        pricePerUnit: price,
        fees: _random.nextDouble() * 10,
        totalAmount: quantity * price,
        createdAt: DateTime.now(),
      ));
    }

    // Batch insert would be ideal, but our repo might not support it yet.
    // For now, we loop. If it's too slow, we'll add batch insert to repo.
    // Actually, let's check if we can add batch insert to repo first, otherwise 10k inserts will take forever.
    // For this test, let's just do it sequentially and see. It simulates "heavy usage" creation too.
    // Optimization: We can use Future.wait with chunks.
    
    const chunkSize = 100;
    for (var i = 0; i < transactions.length; i += chunkSize) {
      final end = (i + chunkSize < transactions.length) ? i + chunkSize : transactions.length;
      final chunk = transactions.sublist(i, end);
      await Future.wait(chunk.map((t) => investmentRepo.addTransaction(t)));
    }
  }
}
