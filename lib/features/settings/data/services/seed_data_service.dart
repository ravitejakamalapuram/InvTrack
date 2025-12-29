import 'package:uuid/uuid.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/repositories/goal_repository.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';

/// Result of seeding demo data
typedef SeedResult = ({int investments, int cashFlows, int goals});

/// Service to seed demo data for screenshots and testing.
/// Creates realistic Indian investment portfolio with goals.
class SeedDataService {
  final InvestmentRepository _investmentRepository;
  final GoalRepository _goalRepository;
  static const _uuid = Uuid();

  SeedDataService(this._investmentRepository, this._goalRepository);

  /// Seeds realistic demo data for app store screenshots.
  /// Creates a diversified Indian investment portfolio with goals.
  Future<SeedResult> seedDemoData() async {
    final now = DateTime.now();
    final investments = <InvestmentEntity>[];
    final cashFlows = <CashFlowEntity>[];

    // Helper to create investment entity
    InvestmentEntity addInvestment({
      required String name,
      required InvestmentType type,
      required InvestmentStatus status,
      required DateTime createdAt,
      DateTime? closedAt,
      DateTime? maturityDate,
      IncomeFrequency? incomeFrequency,
      String? notes,
    }) {
      final inv = InvestmentEntity(
        id: _uuid.v4(),
        name: name,
        type: type,
        status: status,
        createdAt: createdAt,
        closedAt: closedAt,
        updatedAt: now,
        maturityDate: maturityDate,
        incomeFrequency: incomeFrequency,
        notes: notes,
      );
      investments.add(inv);
      return inv;
    }

    // Helper to create cash flow entity
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
    // INVESTMENTS - Realistic Indian Portfolio (~₹32L total)
    // ============================================================

    // 1. HDFC Fixed Deposit - Safe & Steady (open)
    final hdfcFd = addInvestment(
      name: 'HDFC Bank FD',
      type: InvestmentType.fixedDeposit,
      status: InvestmentStatus.open,
      createdAt: now.subtract(const Duration(days: 400)),
      maturityDate: now.add(const Duration(days: 695)), // ~2 years remaining
      incomeFrequency: IncomeFrequency.quarterly,
      notes: '7.25% p.a. for 3 years. Senior citizen rate.',
    );
    addCashFlow(
      hdfcFd.id,
      now.subtract(const Duration(days: 400)),
      CashFlowType.invest,
      500000,
    );
    // Quarterly interest payments
    for (int i = 4; i >= 1; i--) {
      addCashFlow(
        hdfcFd.id,
        now.subtract(Duration(days: i * 90)),
        CashFlowType.income,
        9063, // ~7.25% quarterly on 5L
      );
    }

    // 2. LenDenClub P2P - High Yield (open)
    final lendenClub = addInvestment(
      name: 'LenDenClub P2P',
      type: InvestmentType.p2pLending,
      status: InvestmentStatus.open,
      createdAt: now.subtract(const Duration(days: 300)),
      incomeFrequency: IncomeFrequency.monthly,
      notes: 'Auto-invest enabled. 200+ borrowers. Expected 12% returns.',
    );
    addCashFlow(
      lendenClub.id,
      now.subtract(const Duration(days: 300)),
      CashFlowType.invest,
      150000,
    );
    // Monthly interest
    for (int i = 9; i >= 1; i--) {
      addCashFlow(
        lendenClub.id,
        now.subtract(Duration(days: i * 30)),
        CashFlowType.income,
        1500, // ~12% annual = 1% monthly
      );
    }

    // 3. Bangalore Rental Property - Real Estate (open)
    final bangaloreFlat = addInvestment(
      name: 'Whitefield 2BHK',
      type: InvestmentType.realEstate,
      status: InvestmentStatus.open,
      createdAt: now.subtract(const Duration(days: 730)),
      incomeFrequency: IncomeFrequency.monthly,
      notes: 'Prestige Lakeside. Tenant: Infosys employee. Lease till Dec 2025.',
    );
    addCashFlow(
      bangaloreFlat.id,
      now.subtract(const Duration(days: 730)),
      CashFlowType.invest,
      1500000, // Down payment + fees
    );
    addCashFlow(
      bangaloreFlat.id,
      now.subtract(const Duration(days: 725)),
      CashFlowType.fee,
      75000, // Registration & legal
    );
    // Monthly rent for 24 months
    for (int i = 23; i >= 0; i--) {
      addCashFlow(
        bangaloreFlat.id,
        now.subtract(Duration(days: i * 30)),
        CashFlowType.income,
        28000,
      );
    }

    // 4. Sovereign Gold Bonds - Gold (open)
    final sgb = addInvestment(
      name: 'SGB 2024-25 Series I',
      type: InvestmentType.gold,
      status: InvestmentStatus.open,
      createdAt: now.subtract(const Duration(days: 180)),
      maturityDate: now.add(const Duration(days: 2740)), // 8 years
      incomeFrequency: IncomeFrequency.semiAnnual,
      notes: 'Issue price ₹6,263/gm. 2.5% annual interest. Tax-free on maturity.',
    );
    addCashFlow(
      sgb.id,
      now.subtract(const Duration(days: 180)),
      CashFlowType.invest,
      125260, // 20 grams
    );

    // 5. Faircent P2P - Closed with profit
    final faircent = addInvestment(
      name: 'Faircent Portfolio',
      type: InvestmentType.p2pLending,
      status: InvestmentStatus.closed,
      createdAt: now.subtract(const Duration(days: 500)),
      closedAt: now.subtract(const Duration(days: 45)),
      incomeFrequency: IncomeFrequency.monthly,
      notes: 'Exited after 15 months. Final XIRR: 14.2%',
    );
    addCashFlow(
      faircent.id,
      now.subtract(const Duration(days: 500)),
      CashFlowType.invest,
      100000,
    );
    // Monthly returns for 15 months
    for (int i = 15; i >= 1; i--) {
      addCashFlow(
        faircent.id,
        now.subtract(Duration(days: 45 + i * 30)),
        CashFlowType.income,
        1180,
      );
    }
    addCashFlow(
      faircent.id,
      now.subtract(const Duration(days: 45)),
      CashFlowType.returnFlow,
      100000, // Principal returned
    );

    // 6. UTI Nifty 50 Index Fund - SIP (open)
    final niftyFund = addInvestment(
      name: 'UTI Nifty 50 Index',
      type: InvestmentType.mutualFunds,
      status: InvestmentStatus.open,
      createdAt: now.subtract(const Duration(days: 540)),
      notes: 'SIP ₹15,000/month. Direct plan. Long-term wealth creation.',
    );
    // 18 months of SIP
    for (int i = 18; i >= 1; i--) {
      addCashFlow(
        niftyFund.id,
        now.subtract(Duration(days: i * 30)),
        CashFlowType.invest,
        15000,
      );
    }

    // 7. ICICI Prudential Bluechip - Lumpsum (open)
    final bluechip = addInvestment(
      name: 'ICICI Bluechip Fund',
      type: InvestmentType.mutualFunds,
      status: InvestmentStatus.open,
      createdAt: now.subtract(const Duration(days: 365)),
      notes: 'Lumpsum investment. Direct growth. Large-cap focused.',
    );
    addCashFlow(
      bluechip.id,
      now.subtract(const Duration(days: 365)),
      CashFlowType.invest,
      200000,
    );

    // 8. Angel Investment - Startup (open)
    final startup = addInvestment(
      name: 'FinTech Startup',
      type: InvestmentType.angelInvesting,
      status: InvestmentStatus.open,
      createdAt: now.subtract(const Duration(days: 450)),
      notes: 'Pre-Series A. 2% equity. Payments platform for SMEs.',
    );
    addCashFlow(
      startup.id,
      now.subtract(const Duration(days: 450)),
      CashFlowType.invest,
      300000,
    );

    // 9. Corporate Bonds - NCD (closed)
    final ncd = addInvestment(
      name: 'Bajaj Finance NCD',
      type: InvestmentType.bonds,
      status: InvestmentStatus.closed,
      createdAt: now.subtract(const Duration(days: 400)),
      closedAt: now.subtract(const Duration(days: 35)),
      incomeFrequency: IncomeFrequency.annual,
      notes: 'AAA rated. 8.5% coupon. Redeemed at maturity.',
    );
    addCashFlow(
      ncd.id,
      now.subtract(const Duration(days: 400)),
      CashFlowType.invest,
      200000,
    );
    addCashFlow(
      ncd.id,
      now.subtract(const Duration(days: 35)),
      CashFlowType.income,
      17000, // Annual interest
    );
    addCashFlow(
      ncd.id,
      now.subtract(const Duration(days: 35)),
      CashFlowType.returnFlow,
      200000,
    );

    // 10. Chit Fund - Traditional (open)
    final chitFund = addInvestment(
      name: 'Shriram Chit Fund',
      type: InvestmentType.chitFunds,
      status: InvestmentStatus.open,
      createdAt: now.subtract(const Duration(days: 300)),
      incomeFrequency: IncomeFrequency.monthly,
      notes: '₹10,000/month for 20 months. Won auction in month 8.',
    );
    // Monthly contributions
    for (int i = 10; i >= 1; i--) {
      addCashFlow(
        chitFund.id,
        now.subtract(Duration(days: i * 30)),
        CashFlowType.invest,
        10000,
      );
    }
    // Won the auction - received lumpsum
    addCashFlow(
      chitFund.id,
      now.subtract(const Duration(days: 60)),
      CashFlowType.returnFlow,
      185000, // Chit value minus discount
    );

    // Bulk import investments
    final investmentResult = await _investmentRepository.bulkImport(
      investments: investments,
      cashFlows: cashFlows,
    );

    // ============================================================
    // GOALS - Different progress levels for screenshots
    // ============================================================

    var goalsCreated = 0;

    // Goal 1: Emergency Fund - 100% achieved! 🎉
    final emergencyFund = GoalEntity(
      id: _uuid.v4(),
      name: 'Emergency Fund',
      type: GoalType.targetAmount,
      targetAmount: 500000, // ₹5L target
      trackingMode: GoalTrackingMode.byType,
      linkedTypes: [InvestmentType.fixedDeposit],
      icon: '🛡️',
      colorValue: GoalColors.available[1].toARGB32(), // Emerald
      createdAt: now.subtract(const Duration(days: 365)),
      updatedAt: now,
    );
    await _goalRepository.createGoal(emergencyFund);
    goalsCreated++;

    // Goal 2: ₹1 Crore Portfolio - 75% progress (almost there!)
    final crorePortfolio = GoalEntity(
      id: _uuid.v4(),
      name: '₹1 Crore Portfolio',
      type: GoalType.targetAmount,
      targetAmount: 10000000, // ₹1 Cr target
      trackingMode: GoalTrackingMode.all,
      icon: '🎯',
      colorValue: GoalColors.available[0].toARGB32(), // Blue
      createdAt: now.subtract(const Duration(days: 730)),
      updatedAt: now,
    );
    await _goalRepository.createGoal(crorePortfolio);
    goalsCreated++;

    // Goal 3: Passive Income ₹50K/month - ~55% progress
    final passiveIncome = GoalEntity(
      id: _uuid.v4(),
      name: '₹50K Monthly Income',
      type: GoalType.incomeTarget,
      targetAmount: 600000, // ₹6L annual for display
      targetMonthlyIncome: 50000,
      trackingMode: GoalTrackingMode.byType,
      linkedTypes: [
        InvestmentType.realEstate,
        InvestmentType.fixedDeposit,
        InvestmentType.p2pLending,
      ],
      icon: '💰',
      colorValue: GoalColors.available[2].toARGB32(), // Amber
      createdAt: now.subtract(const Duration(days: 500)),
      updatedAt: now,
    );
    await _goalRepository.createGoal(passiveIncome);
    goalsCreated++;

    // Goal 4: House Down Payment - 30% progress with deadline
    final houseDownPayment = GoalEntity(
      id: _uuid.v4(),
      name: 'House Down Payment',
      type: GoalType.targetDate,
      targetAmount: 2500000, // ₹25L target
      targetDate: now.add(const Duration(days: 730)), // 2 years deadline
      trackingMode: GoalTrackingMode.selected,
      linkedInvestmentIds: [niftyFund.id, bluechip.id],
      icon: '🏠',
      colorValue: GoalColors.available[4].toARGB32(), // Purple
      createdAt: now.subtract(const Duration(days: 200)),
      updatedAt: now,
    );
    await _goalRepository.createGoal(houseDownPayment);
    goalsCreated++;

    // Goal 5: Child Education Fund - Just started ~5%
    final childEducation = GoalEntity(
      id: _uuid.v4(),
      name: 'Child Education',
      type: GoalType.targetDate,
      targetAmount: 5000000, // ₹50L target
      targetDate: now.add(const Duration(days: 5475)), // 15 years
      trackingMode: GoalTrackingMode.byType,
      linkedTypes: [InvestmentType.mutualFunds],
      icon: '🎓',
      colorValue: GoalColors.available[5].toARGB32(), // Cyan
      createdAt: now.subtract(const Duration(days: 100)),
      updatedAt: now,
    );
    await _goalRepository.createGoal(childEducation);
    goalsCreated++;

    return (
      investments: investmentResult.investments,
      cashFlows: investmentResult.cashFlows,
      goals: goalsCreated,
    );
  }
}
