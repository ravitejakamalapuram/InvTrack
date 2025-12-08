import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/database/app_database.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/portfolio/domain/entities/portfolio_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

void main() {
  group('App Flow Integration Tests', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );
    });

    tearDown(() async {
      await db.close();
      container.dispose();
    });

    test('Create Portfolio -> Add Investment -> Add Transaction -> Verify Totals', () async {
      // 1. Create Portfolio
      final portfolioRepo = container.read(portfolioRepositoryProvider);
      final portfolio = PortfolioEntity(
        id: 'test-portfolio-1',
        name: 'My Portfolio',
        currency: 'USD',
        createdAt: DateTime.now(),
      );
      await portfolioRepo.createPortfolio(portfolio);

      // Verify portfolio created
      final portfolios = await portfolioRepo.getAllPortfolios();
      expect(portfolios.length, 1);
      expect(portfolios.first.name, 'My Portfolio');

      // 2. Add Investment
      final investmentRepo = container.read(investmentRepositoryProvider);
      final investment = InvestmentEntity(
        id: 'test-investment-1',
        portfolioId: portfolio.id,
        name: 'Apple Inc.',
        symbol: 'AAPL',
        type: 'stock',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await investmentRepo.createInvestment(investment);

      // Verify investment created
      final investments = await investmentRepo.getInvestmentsByPortfolio(portfolio.id);
      expect(investments.length, 1);
      expect(investments.first.name, 'Apple Inc.');

      // 3. Add Transaction (Buy 10 shares at $150)
      final transaction = TransactionEntity(
        id: 'test-transaction-1',
        investmentId: investment.id,
        type: 'buy',
        quantity: 10,
        pricePerUnit: 150.0,
        fees: 0.0,
        totalAmount: 1500.0,
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await investmentRepo.addTransaction(transaction);

      // Verify transaction created
      final transactions = await investmentRepo.getTransactionsByInvestment(investment.id);
      expect(transactions.length, 1);
      expect(transactions.first.quantity, 10);
      expect(transactions.first.pricePerUnit, 150.0);

      // 4. Verify total value (10 * 150 = 1500)
      final totalValue = transactions.fold<double>(
        0,
        (sum, t) => sum + t.totalAmount,
      );
      expect(totalValue, 1500.0);
    });

    test('Multiple transactions calculate correct totals', () async {
      // Create portfolio and investment
      final portfolioRepo = container.read(portfolioRepositoryProvider);
      final investmentRepo = container.read(investmentRepositoryProvider);

      final portfolio = PortfolioEntity(
        id: 'test-portfolio-2',
        name: 'Test Portfolio',
        currency: 'USD',
        createdAt: DateTime.now(),
      );
      await portfolioRepo.createPortfolio(portfolio);

      final investment = InvestmentEntity(
        id: 'test-investment-2',
        portfolioId: portfolio.id,
        name: 'Google',
        symbol: 'GOOGL',
        type: 'stock',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await investmentRepo.createInvestment(investment);

      // Add multiple transactions
      await investmentRepo.addTransaction(TransactionEntity(
        id: 'tx-1',
        investmentId: investment.id,
        type: 'buy',
        quantity: 5,
        pricePerUnit: 100.0,
        fees: 0.0,
        totalAmount: 500.0,
        date: DateTime.now(),
        createdAt: DateTime.now(),
      ));

      await investmentRepo.addTransaction(TransactionEntity(
        id: 'tx-2',
        investmentId: investment.id,
        type: 'buy',
        quantity: 10,
        pricePerUnit: 120.0,
        fees: 0.0,
        totalAmount: 1200.0,
        date: DateTime.now(),
        createdAt: DateTime.now(),
      ));

      // Verify transactions
      final transactions = await investmentRepo.getTransactionsByInvestment(investment.id);
      expect(transactions.length, 2);

      // Calculate total invested: 500 + 1200 = 1700
      final totalInvested = transactions.fold<double>(
        0,
        (sum, t) => sum + t.totalAmount,
      );
      expect(totalInvested, 1700.0);

      // Calculate total quantity: 5 + 10 = 15
      final totalQuantity = transactions.fold<double>(
        0,
        (sum, t) => sum + t.quantity,
      );
      expect(totalQuantity, 15.0);
    });
  });
}
