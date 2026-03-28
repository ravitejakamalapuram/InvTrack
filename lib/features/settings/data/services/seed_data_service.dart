import 'package:uuid/uuid.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/repositories/goal_repository.dart';
import 'package:inv_tracker/features/goals/presentation/ui_extensions/goal_type_ui.dart';
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
      notes:
          'Prestige Lakeside. Tenant: Infosys employee. Lease till Dec 2025.',
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
      notes:
          'Issue price ₹6,263/gm. 2.5% annual interest. Tax-free on maturity.',
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

    // ============================================================
    // ADDITIONAL INVESTMENTS - Cover all remaining types & edge cases
    // ============================================================

    // 11. Private Equity Fund (open) - privateEquity type
    final peFund = addInvestment(
      name: 'Blume Ventures Fund IV',
      type: InvestmentType.privateEquity,
      status: InvestmentStatus.open,
      createdAt: now.subtract(const Duration(days: 600)),
      notes: 'Committed ₹10L. 40% capital called. 10-year fund life.',
    );
    addCashFlow(
      peFund.id,
      now.subtract(const Duration(days: 600)),
      CashFlowType.invest,
      200000, // First capital call
    );
    addCashFlow(
      peFund.id,
      now.subtract(const Duration(days: 300)),
      CashFlowType.invest,
      200000, // Second capital call
    );

    // 12. Crypto Portfolio (open) - crypto type with volatility
    final crypto = addInvestment(
      name: 'Bitcoin & Ethereum',
      type: InvestmentType.crypto,
      status: InvestmentStatus.open,
      createdAt: now.subtract(const Duration(days: 400)),
      notes: 'BTC 0.05, ETH 1.5. Held on Ledger cold wallet.',
    );
    addCashFlow(
      crypto.id,
      now.subtract(const Duration(days: 400)),
      CashFlowType.invest,
      150000,
    );
    addCashFlow(
      crypto.id,
      now.subtract(const Duration(days: 200)),
      CashFlowType.invest,
      50000, // DCA purchase
    );

    // 13. Direct Stocks (open) - stocks type
    final stocks = addInvestment(
      name: 'HDFC Bank + Reliance',
      type: InvestmentType.stocks,
      status: InvestmentStatus.open,
      createdAt: now.subtract(const Duration(days: 365)),
      notes: 'HDFC 50 shares, RIL 30 shares. Zerodha demat.',
    );
    addCashFlow(
      stocks.id,
      now.subtract(const Duration(days: 365)),
      CashFlowType.invest,
      180000,
    );
    // Dividend income
    addCashFlow(
      stocks.id,
      now.subtract(const Duration(days: 90)),
      CashFlowType.income,
      2500, // HDFC dividend
    );

    // 14. NSC (open) - other type
    final nsc = addInvestment(
      name: 'National Savings Certificate',
      type: InvestmentType.other,
      status: InvestmentStatus.open,
      createdAt: now.subtract(const Duration(days: 180)),
      maturityDate: now.add(const Duration(days: 1645)), // 5 years total
      notes: 'Post office NSC. 7.7% compounding. 80C eligible.',
    );
    addCashFlow(
      nsc.id,
      now.subtract(const Duration(days: 180)),
      CashFlowType.invest,
      100000,
    );

    // 15. Just Created Investment - NO CASH FLOWS (edge case)
    addInvestment(
      name: 'New PPF Account',
      type: InvestmentType.other,
      status: InvestmentStatus.open,
      createdAt: now.subtract(const Duration(days: 2)),
      maturityDate: now.add(const Duration(days: 5475)), // 15 years
      notes: 'Just opened. First deposit pending.',
    );

    // 16. Loss-Making Investment (closed with loss)
    final lossInvestment = addInvestment(
      name: 'Failed Crypto Token',
      type: InvestmentType.crypto,
      status: InvestmentStatus.closed,
      createdAt: now.subtract(const Duration(days: 300)),
      closedAt: now.subtract(const Duration(days: 60)),
      notes: 'Altcoin investment. Lost 70% value. Lesson learned.',
    );
    addCashFlow(
      lossInvestment.id,
      now.subtract(const Duration(days: 300)),
      CashFlowType.invest,
      50000,
    );
    addCashFlow(
      lossInvestment.id,
      now.subtract(const Duration(days: 60)),
      CashFlowType.returnFlow,
      15000, // Only recovered 30%
    );

    // 17. Investment with ONLY fees (expense tracking)
    final pendingInvestment = addInvestment(
      name: 'Plot in Hyderabad',
      type: InvestmentType.realEstate,
      status: InvestmentStatus.open,
      createdAt: now.subtract(const Duration(days: 90)),
      notes: 'Under registration. Only fees paid so far.',
    );
    addCashFlow(
      pendingInvestment.id,
      now.subtract(const Duration(days: 90)),
      CashFlowType.fee,
      25000, // Legal fees
    );
    addCashFlow(
      pendingInvestment.id,
      now.subtract(const Duration(days: 60)),
      CashFlowType.fee,
      15000, // Survey & documentation
    );

    // 18. Matured but NOT closed (overdue maturity)
    final maturedFd = addInvestment(
      name: 'SBI FD (Matured)',
      type: InvestmentType.fixedDeposit,
      status: InvestmentStatus.open, // Still open despite maturity passed
      createdAt: now.subtract(const Duration(days: 400)),
      maturityDate: now.subtract(
        const Duration(days: 35),
      ), // Matured 35 days ago!
      incomeFrequency: IncomeFrequency.quarterly,
      notes: 'Matured on 25th Nov. Pending renewal decision.',
    );
    addCashFlow(
      maturedFd.id,
      now.subtract(const Duration(days: 400)),
      CashFlowType.invest,
      300000,
    );
    // Interest payments during term
    for (int i = 4; i >= 1; i--) {
      addCashFlow(
        maturedFd.id,
        now.subtract(Duration(days: 35 + i * 90)),
        CashFlowType.income,
        5438, // ~7.25% quarterly
      );
    }

    // 19. Partial Exit Investment (stocks with partial sell)
    final partialExit = addInvestment(
      name: 'Tata Motors Shares',
      type: InvestmentType.stocks,
      status: InvestmentStatus.open,
      createdAt: now.subtract(const Duration(days: 500)),
      notes: 'Original 100 shares. Sold 40 at profit. Holding 60.',
    );
    addCashFlow(
      partialExit.id,
      now.subtract(const Duration(days: 500)),
      CashFlowType.invest,
      80000, // Bought 100 shares at ₹800
    );
    addCashFlow(
      partialExit.id,
      now.subtract(const Duration(days: 100)),
      CashFlowType.returnFlow,
      48000, // Sold 40 shares at ₹1200
    );
    addCashFlow(
      partialExit.id,
      now.subtract(const Duration(days: 180)),
      CashFlowType.income,
      500, // Dividend
    );

    // 20. High-frequency trading scenario (many transactions)
    final activeTrading = addInvestment(
      name: 'Intraday Trading Account',
      type: InvestmentType.stocks,
      status: InvestmentStatus.open,
      createdAt: now.subtract(const Duration(days: 60)),
      notes: 'Active F&O trading. High volume.',
    );
    addCashFlow(
      activeTrading.id,
      now.subtract(const Duration(days: 60)),
      CashFlowType.invest,
      200000, // Initial margin
    );
    // Simulate trading activity
    for (int i = 1; i <= 15; i++) {
      // Some wins
      if (i % 3 != 0) {
        addCashFlow(
          activeTrading.id,
          now.subtract(Duration(days: 60 - i * 3)),
          CashFlowType.income,
          (2000 + i * 100).toDouble(),
        );
      } else {
        // Some losses (as fees)
        addCashFlow(
          activeTrading.id,
          now.subtract(Duration(days: 60 - i * 3)),
          CashFlowType.fee,
          (1500 + i * 50).toDouble(),
        );
      }
    }

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

    // ============================================================
    // ADDITIONAL GOALS - Edge cases for comprehensive testing
    // ============================================================

    // Goal 6: Zero Progress - Just created, no linked investments yet
    final vacationGoal = GoalEntity(
      id: _uuid.v4(),
      name: 'Europe Vacation 2026',
      type: GoalType.targetDate,
      targetAmount: 300000, // ₹3L target
      targetDate: now.add(const Duration(days: 365)), // 1 year deadline
      trackingMode: GoalTrackingMode.selected,
      linkedInvestmentIds: [], // No investments linked = 0%
      icon: '✈️',
      colorValue: GoalColors.available[3].toARGB32(), // Rose
      createdAt: now.subtract(const Duration(days: 7)),
      updatedAt: now,
    );
    await _goalRepository.createGoal(vacationGoal);
    goalsCreated++;

    // Goal 7: Over 100% - Exceeded target (success celebration!)
    final carGoal = GoalEntity(
      id: _uuid.v4(),
      name: 'Car Down Payment',
      type: GoalType.targetAmount,
      targetAmount: 300000, // ₹3L target - but we have more!
      trackingMode: GoalTrackingMode.byType,
      linkedTypes: [InvestmentType.p2pLending], // LenDenClub has ₹1.5L + income
      icon: '🚗',
      colorValue: GoalColors.available[6].toARGB32(), // Teal
      createdAt: now.subtract(const Duration(days: 200)),
      updatedAt: now,
    );
    await _goalRepository.createGoal(carGoal);
    goalsCreated++;

    // Goal 8: Past deadline goal (overdue)
    final laptopGoal = GoalEntity(
      id: _uuid.v4(),
      name: 'MacBook Pro Fund',
      type: GoalType.targetDate,
      targetAmount: 200000, // ₹2L target
      targetDate: now.subtract(const Duration(days: 30)), // Deadline passed!
      trackingMode: GoalTrackingMode.byType,
      linkedTypes: [InvestmentType.crypto], // Has some crypto
      icon: '💻',
      colorValue: GoalColors.available[7].toARGB32(), // Orange
      createdAt: now.subtract(const Duration(days: 180)),
      updatedAt: now,
    );
    await _goalRepository.createGoal(laptopGoal);
    goalsCreated++;

    // Goal 9: Income goal with no income-generating investments
    final dividendGoal = GoalEntity(
      id: _uuid.v4(),
      name: 'Dividend Portfolio',
      type: GoalType.incomeTarget,
      targetAmount: 120000, // ₹1L annual for display
      targetMonthlyIncome: 10000,
      trackingMode: GoalTrackingMode.byType,
      linkedTypes: [
        InvestmentType.stocks,
      ], // Only stocks, not much dividend yet
      icon: '📈',
      colorValue: GoalColors.available[0].toARGB32(), // Blue
      createdAt: now.subtract(const Duration(days: 60)),
      updatedAt: now,
    );
    await _goalRepository.createGoal(dividendGoal);
    goalsCreated++;

    // Goal 10: All investments tracking (should show full portfolio)
    final wealthGoal = GoalEntity(
      id: _uuid.v4(),
      name: 'Net Worth ₹50L',
      type: GoalType.targetAmount,
      targetAmount: 5000000, // ₹50L target
      trackingMode: GoalTrackingMode.all, // Track everything
      icon: '💎',
      colorValue: GoalColors.available[1].toARGB32(), // Emerald
      createdAt: now.subtract(const Duration(days: 400)),
      updatedAt: now,
    );
    await _goalRepository.createGoal(wealthGoal);
    goalsCreated++;

    return (
      investments: investmentResult.investments,
      cashFlows: investmentResult.cashFlows,
      goals: goalsCreated,
    );
  }
}
