import 'package:uuid/uuid.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';

/// Service to seed demo data for screenshots and testing
class SeedDataService {
  final InvestmentRepository _repository;
  final Uuid _uuid = const Uuid();

  SeedDataService(this._repository);

  /// Seeds realistic demo data for app store screenshots
  Future<void> seedDemoData() async {
    final now = DateTime.now();

    // 1. P2P Lending - High performer (closed with profit)
    final p2p = await _createInvestment(
      name: 'LendingClub Portfolio',
      type: InvestmentType.p2pLending,
      status: InvestmentStatus.closed,
      createdAt: now.subtract(const Duration(days: 540)),
      closedAt: now.subtract(const Duration(days: 30)),
    );
    await _addCashFlow(p2p.id, now.subtract(const Duration(days: 540)), CashFlowType.invest, 50000);
    await _addCashFlow(p2p.id, now.subtract(const Duration(days: 450)), CashFlowType.income, 1250);
    await _addCashFlow(p2p.id, now.subtract(const Duration(days: 360)), CashFlowType.income, 1500);
    await _addCashFlow(p2p.id, now.subtract(const Duration(days: 270)), CashFlowType.income, 1400);
    await _addCashFlow(p2p.id, now.subtract(const Duration(days: 180)), CashFlowType.income, 1600);
    await _addCashFlow(p2p.id, now.subtract(const Duration(days: 90)), CashFlowType.income, 1550);
    await _addCashFlow(p2p.id, now.subtract(const Duration(days: 30)), CashFlowType.returnFlow, 52000);

    // 2. Fixed Deposit - Steady returns (open)
    final fd = await _createInvestment(
      name: 'HDFC 3-Year FD',
      type: InvestmentType.fixedDeposit,
      status: InvestmentStatus.open,
      createdAt: now.subtract(const Duration(days: 365)),
    );
    await _addCashFlow(fd.id, now.subtract(const Duration(days: 365)), CashFlowType.invest, 200000);
    await _addCashFlow(fd.id, now.subtract(const Duration(days: 275)), CashFlowType.income, 3500);
    await _addCashFlow(fd.id, now.subtract(const Duration(days: 180)), CashFlowType.income, 3500);
    await _addCashFlow(fd.id, now.subtract(const Duration(days: 90)), CashFlowType.income, 3500);

    // 3. Real Estate - Long term (open)
    final realEstate = await _createInvestment(
      name: 'Bangalore Apartment',
      type: InvestmentType.realEstate,
      status: InvestmentStatus.open,
      createdAt: now.subtract(const Duration(days: 730)),
    );
    await _addCashFlow(realEstate.id, now.subtract(const Duration(days: 730)), CashFlowType.invest, 1500000);
    await _addCashFlow(realEstate.id, now.subtract(const Duration(days: 700)), CashFlowType.fee, 45000);
    for (int i = 23; i >= 0; i--) {
      await _addCashFlow(realEstate.id, now.subtract(Duration(days: i * 30)), CashFlowType.income, 25000);
    }

    // 4. Gold - Commodity (open)
    final gold = await _createInvestment(
      name: 'Sovereign Gold Bonds',
      type: InvestmentType.gold,
      status: InvestmentStatus.open,
      createdAt: now.subtract(const Duration(days: 400)),
    );
    await _addCashFlow(gold.id, now.subtract(const Duration(days: 400)), CashFlowType.invest, 100000);
    await _addCashFlow(gold.id, now.subtract(const Duration(days: 180)), CashFlowType.income, 1250);

    // 5. Angel Investment - High risk (open)
    final angel = await _createInvestment(
      name: 'TechStartup Series A',
      type: InvestmentType.angelInvesting,
      status: InvestmentStatus.open,
      createdAt: now.subtract(const Duration(days: 600)),
    );
    await _addCashFlow(angel.id, now.subtract(const Duration(days: 600)), CashFlowType.invest, 250000);
    await _addCashFlow(angel.id, now.subtract(const Duration(days: 300)), CashFlowType.invest, 100000);

    // 6. Bonds - Conservative (closed)
    final bonds = await _createInvestment(
      name: 'Corporate Bonds AAA',
      type: InvestmentType.bonds,
      status: InvestmentStatus.closed,
      createdAt: now.subtract(const Duration(days: 800)),
      closedAt: now.subtract(const Duration(days: 70)),
    );
    await _addCashFlow(bonds.id, now.subtract(const Duration(days: 800)), CashFlowType.invest, 300000);
    await _addCashFlow(bonds.id, now.subtract(const Duration(days: 620)), CashFlowType.income, 10500);
    await _addCashFlow(bonds.id, now.subtract(const Duration(days: 440)), CashFlowType.income, 10500);
    await _addCashFlow(bonds.id, now.subtract(const Duration(days: 260)), CashFlowType.income, 10500);
    await _addCashFlow(bonds.id, now.subtract(const Duration(days: 70)), CashFlowType.returnFlow, 310000);

    // 7. Crypto - Volatile (open)
    final crypto = await _createInvestment(
      name: 'Bitcoin Holdings',
      type: InvestmentType.crypto,
      status: InvestmentStatus.open,
      createdAt: now.subtract(const Duration(days: 200)),
    );
    await _addCashFlow(crypto.id, now.subtract(const Duration(days: 200)), CashFlowType.invest, 75000);
    await _addCashFlow(crypto.id, now.subtract(const Duration(days: 100)), CashFlowType.invest, 25000);

    // 8. Mutual Funds - SIP style (open)
    final mf = await _createInvestment(
      name: 'Nifty 50 Index Fund',
      type: InvestmentType.mutualFunds,
      status: InvestmentStatus.open,
      createdAt: now.subtract(const Duration(days: 360)),
    );
    for (int i = 12; i >= 1; i--) {
      await _addCashFlow(mf.id, now.subtract(Duration(days: i * 30)), CashFlowType.invest, 10000);
    }
  }

  Future<InvestmentEntity> _createInvestment({
    required String name,
    required InvestmentType type,
    required InvestmentStatus status,
    required DateTime createdAt,
    DateTime? closedAt,
  }) async {
    final investment = InvestmentEntity(
      id: _uuid.v4(),
      name: name,
      type: type,
      status: status,
      createdAt: createdAt,
      closedAt: closedAt,
      updatedAt: DateTime.now(),
    );
    await _repository.createInvestment(investment);
    return investment;
  }

  Future<void> _addCashFlow(String investmentId, DateTime date, CashFlowType type, double amount) async {
    final cashFlow = CashFlowEntity(
      id: _uuid.v4(),
      investmentId: investmentId,
      date: date,
      type: type,
      amount: amount,
      createdAt: DateTime.now(),
    );
    await _repository.addCashFlow(cashFlow);
  }
}

