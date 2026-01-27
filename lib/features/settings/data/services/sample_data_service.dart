/// Service for creating and managing sample data for new users.
/// This creates a simplified set of investments focused on demonstrating
/// the XIRR "Aha moment" - showing the difference between advertised and real returns.
library;

import 'package:uuid/uuid.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/repositories/goal_repository.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';

/// Result of creating sample data
typedef SampleDataResult = ({
  List<String> investmentIds,
  List<String> goalIds,
});

/// Service to create simplified sample data for new user exploration.
/// Creates 4-5 investments that clearly demonstrate XIRR value proposition.
class SampleDataService {
  final InvestmentRepository _investmentRepository;
  final GoalRepository _goalRepository;
  static const _uuid = Uuid();

  SampleDataService(this._investmentRepository, this._goalRepository);

  /// Creates a focused sample portfolio demonstrating the "Aha moment".
  /// Returns IDs of created items for later cleanup.
  Future<SampleDataResult> createSampleData() async {
    final now = DateTime.now();
    final investments = <InvestmentEntity>[];
    final cashFlows = <CashFlowEntity>[];
    final investmentIds = <String>[];
    final goalIds = <String>[];

    // Helper to create investment
    InvestmentEntity createInvestment({
      required String name,
      required InvestmentType type,
      required InvestmentStatus status,
      required DateTime createdAt,
      DateTime? maturityDate,
      IncomeFrequency? incomeFrequency,
      String? notes,
      double? expectedRate,
      int? tenureMonths,
      String? platform,
    }) {
      final id = _uuid.v4();
      investmentIds.add(id);
      final inv = InvestmentEntity(
        id: id,
        name: name,
        type: type,
        status: status,
        createdAt: createdAt,
        updatedAt: now,
        maturityDate: maturityDate,
        incomeFrequency: incomeFrequency,
        notes: notes,
        expectedRate: expectedRate,
        tenureMonths: tenureMonths,
        platform: platform,
      );
      investments.add(inv);
      return inv;
    }

    // Helper to add cash flow
    void addCashFlow(
      String investmentId,
      DateTime date,
      CashFlowType type,
      double amount,
    ) {
      cashFlows.add(
        CashFlowEntity(
          id: _uuid.v4(),
          investmentId: investmentId,
          date: date,
          type: type,
          amount: amount,
          createdAt: now,
        ),
      );
    }

    // ============================================================
    // SAMPLE INVESTMENTS - Focused on demonstrating XIRR value
    // ============================================================

    // 1. Fixed Deposit - Shows advertised vs real XIRR difference
    // Advertised: 7.25% | Real XIRR: ~6.2% (due to quarterly compounding timing)
    final fd = createInvestment(
      name: 'Sample FD - HDFC Bank',
      type: InvestmentType.fixedDeposit,
      status: InvestmentStatus.open,
      createdAt: now.subtract(const Duration(days: 365)),
      maturityDate: now.add(const Duration(days: 365)),
      incomeFrequency: IncomeFrequency.quarterly,
      notes: '📌 SAMPLE: Notice how the real XIRR differs from the advertised 7.25% rate!',
      expectedRate: 7.25,
      tenureMonths: 24,
      platform: 'HDFC Bank',
    );
    addCashFlow(fd.id, now.subtract(const Duration(days: 365)), CashFlowType.invest, 100000);
    // Quarterly interest (7.25% annual = ~1.77% quarterly on reducing balance)
    addCashFlow(fd.id, now.subtract(const Duration(days: 275)), CashFlowType.income, 1813);
    addCashFlow(fd.id, now.subtract(const Duration(days: 183)), CashFlowType.income, 1813);
    addCashFlow(fd.id, now.subtract(const Duration(days: 91)), CashFlowType.income, 1813);
    addCashFlow(fd.id, now.subtract(const Duration(days: 1)), CashFlowType.income, 1813);

    // 2. P2P Lending - High advertised return, shows platform fees impact
    final p2p = createInvestment(
      name: 'Sample P2P - LenDenClub',
      type: InvestmentType.p2pLending,
      status: InvestmentStatus.open,
      createdAt: now.subtract(const Duration(days: 180)),
      incomeFrequency: IncomeFrequency.monthly,
      notes: '📌 SAMPLE: Advertised 12% but actual XIRR includes defaults and fees.',
      expectedRate: 12.0,
      platform: 'LenDenClub',
    );
    addCashFlow(p2p.id, now.subtract(const Duration(days: 180)), CashFlowType.invest, 50000);
    addCashFlow(p2p.id, now.subtract(const Duration(days: 180)), CashFlowType.fee, 500); // Platform fee
    // Monthly returns (varying due to defaults)
    for (int i = 5; i >= 0; i--) {
      addCashFlow(p2p.id, now.subtract(Duration(days: i * 30)), CashFlowType.income, 450 + (i % 2 == 0 ? 50 : -30));
    }

    // 3. Mutual Fund SIP - Shows power of consistent investing
    final sip = createInvestment(
      name: 'Sample SIP - Nifty 50 Index',
      type: InvestmentType.mutualFunds,
      status: InvestmentStatus.open,
      createdAt: now.subtract(const Duration(days: 360)),
      notes: '📌 SAMPLE: Monthly SIP shows true XIRR considering timing of each investment.',
      platform: 'UTI Direct',
    );
    // 12 months of SIP
    for (int i = 12; i >= 1; i--) {
      addCashFlow(sip.id, now.subtract(Duration(days: i * 30)), CashFlowType.invest, 5000);
    }

    // 4. Gold/SGB - Shows impact of lock-in on returns
    final sgb = createInvestment(
      name: 'Sample SGB - 2024 Series',
      type: InvestmentType.gold,
      status: InvestmentStatus.open,
      createdAt: now.subtract(const Duration(days: 200)),
      maturityDate: now.add(const Duration(days: 2720)), // 8 year lock-in
      incomeFrequency: IncomeFrequency.semiAnnual,
      notes: '📌 SAMPLE: 2.5% interest + gold appreciation. Tax-free on maturity!',
      expectedRate: 2.5,
      tenureMonths: 96,
      platform: 'RBI',
    );
    addCashFlow(sgb.id, now.subtract(const Duration(days: 200)), CashFlowType.invest, 62630); // 10 grams
    addCashFlow(sgb.id, now.subtract(const Duration(days: 17)), CashFlowType.income, 783); // Semi-annual interest
    
    // Bulk import investments
    await _investmentRepository.bulkImport(investments: investments, cashFlows: cashFlows);

    // ============================================================
    // SAMPLE GOAL - Shows goal tracking feature
    // ============================================================

    // Goal: Emergency Fund (tracks FD)
    final emergencyFundId = _uuid.v4();
    goalIds.add(emergencyFundId);
    final emergencyFund = GoalEntity(
      id: emergencyFundId,
      name: 'Sample: Emergency Fund',
      type: GoalType.targetAmount,
      targetAmount: 300000, // ₹3L target
      trackingMode: GoalTrackingMode.byType,
      linkedTypes: [InvestmentType.fixedDeposit],
      icon: '🛡️',
      colorValue: GoalColors.available[1].toARGB32(), // Emerald
      createdAt: now.subtract(const Duration(days: 365)),
      updatedAt: now,
    );
    await _goalRepository.createGoal(emergencyFund);

    return (investmentIds: investmentIds, goalIds: goalIds);
  }

  /// Clears sample data by deleting specified investments and goals
  Future<void> clearSampleData({
    required List<String> investmentIds,
    required List<String> goalIds,
  }) async {
    // Delete investments (also deletes their cash flows)
    if (investmentIds.isNotEmpty) {
      await _investmentRepository.bulkDelete(investmentIds);
    }

    // Delete goals
    for (final goalId in goalIds) {
      try {
        await _goalRepository.deleteGoal(goalId);
      } catch (_) {
        // Goal might already be deleted, ignore
      }
    }
  }
}

