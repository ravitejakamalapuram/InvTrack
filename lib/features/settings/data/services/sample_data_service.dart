/// Service for creating and managing sample data for new users.
/// This creates a simplified set of investments focused on demonstrating
/// the XIRR "Aha moment" - showing the difference between advertised and real returns.
library;

import 'package:uuid/uuid.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/repositories/goal_repository.dart';
import 'package:inv_tracker/features/goals/presentation/ui_extensions/goal_type_ui.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';

/// Result of creating sample data
typedef SampleDataResult = ({List<String> investmentIds, List<String> goalIds});

/// Service to create simplified sample data for new user exploration.
/// Creates 4-5 investments that clearly demonstrate XIRR value proposition.
class SampleDataService {
  final InvestmentRepository _investmentRepository;
  final GoalRepository _goalRepository;
  static const _uuid = Uuid();

  SampleDataService(this._investmentRepository, this._goalRepository);

  /// Creates a focused sample portfolio demonstrating the "Aha moment".
  /// Returns IDs of created items for later cleanup.
  ///
  /// **Multi-Currency (Rule 21.6):** Uses user's base currency for goals
  /// to ensure percentage calculations are accurate across currency switches.
  Future<SampleDataResult> createSampleData({
    required String baseCurrency,
    DateTime? asOf,
  }) async {
    final now = asOf ?? DateTime.now();
    // Cash-flow and valuation dates are date-only (money rule 5).
    final today = DateTime(now.year, now.month, now.day);
    DateTime daysAgo(int days) =>
        DateTime(today.year, today.month, today.day - days);
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
      required String currency, // Multi-currency support (Rule 21.5)
      DateTime? maturityDate,
      IncomeFrequency? incomeFrequency,
      String? notes,
      double? expectedRate,
      int? tenureMonths,
      String? platform,
      DateTime? closedAt,
      double? currentValue,
    }) {
      final id = _uuid.v4();
      investmentIds.add(id);
      final inv = InvestmentEntity(
        id: id,
        name: name,
        type: type,
        status: status,
        currency: currency, // Multi-currency support (Rule 21.5)
        createdAt: createdAt,
        updatedAt: now,
        maturityDate: maturityDate,
        incomeFrequency: incomeFrequency,
        notes: notes,
        expectedRate: expectedRate,
        tenureMonths: tenureMonths,
        platform: platform,
        closedAt: closedAt,
        currentValue: currentValue,
        currentValueDate: currentValue != null ? today : null,
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
      String currency, // Multi-currency support (Rule 21.5)
    ) {
      cashFlows.add(
        CashFlowEntity(
          id: _uuid.v4(),
          investmentId: investmentId,
          date: date,
          type: type,
          amount: amount,
          currency: currency, // Multi-currency support (Rule 21.5)
          createdAt: now,
        ),
      );
    }

    // ============================================================
    // SAMPLE INVESTMENTS - Multi-currency portfolio (Rule 21.5)
    // Every sample is closed or has a current value (A10), so each one
    // shows a real XIRR between 0% and 20% (A20; pinned by
    // sample_data_service_test.dart).
    // ============================================================

    // 1. P2P lending (INR, closed) - leads the "advertised vs real" story,
    // like the empty-state demo: 1,00,000 lent at an advertised 12%, twelve
    // monthly interest payouts of 1,000, a 1% platform fee and one defaulted
    // 5,000 loan. Real XIRR: 6.345%.
    final p2p = createInvestment(
      name: 'Sample P2P Lending',
      type: InvestmentType.p2pLending,
      status: InvestmentStatus.closed,
      currency: 'INR', // Indian Rupees (Rule 21.5)
      createdAt: daysAgo(365),
      closedAt: today,
      incomeFrequency: IncomeFrequency.monthly,
      notes:
          '📌 SAMPLE: Advertised 12% a year. After the platform fee and one '
          'defaulted loan, the real XIRR is about 6.3%.',
      expectedRate: 12.0,
      tenureMonths: 12,
      platform: 'P2P platform',
    );
    addCashFlow(p2p.id, daysAgo(365), CashFlowType.invest, 100000, 'INR');
    for (var month = 1; month <= 12; month++) {
      addCashFlow(
        p2p.id,
        daysAgo(365 - (month * 365 / 12).round()),
        CashFlowType.income,
        1000,
        'INR',
      );
    }
    addCashFlow(p2p.id, today, CashFlowType.fee, 1000, 'INR'); // 1% fee
    // Principal back, less the one 5,000 loan that defaulted.
    addCashFlow(p2p.id, today, CashFlowType.returnFlow, 95000, 'INR');

    // 2. Fixed Deposit (INR, open) - 7.25% paid out quarterly. Payouts arrive
    // before the year ends, so the XIRR (7.45%) is a little above the
    // advertised rate, before tax. Valued at its outstanding principal (A10).
    final fd = createInvestment(
      name: 'Sample FD - HDFC Bank',
      type: InvestmentType.fixedDeposit,
      status: InvestmentStatus.open,
      currency: 'INR', // Indian Rupees (Rule 21.5)
      createdAt: daysAgo(365),
      maturityDate: daysAgo(-365),
      incomeFrequency: IncomeFrequency.quarterly,
      notes:
          '📌 SAMPLE: 7.25% a year, paid quarterly. Early payouts lift the '
          'XIRR to about 7.4% before tax; tax at your slab lowers what you keep.',
      expectedRate: 7.25,
      tenureMonths: 24,
      platform: 'HDFC Bank',
    );
    addCashFlow(fd.id, daysAgo(365), CashFlowType.invest, 100000, 'INR');
    for (var quarter = 1; quarter <= 4; quarter++) {
      addCashFlow(
        fd.id,
        daysAgo(365 - (quarter * 365 / 4).round()),
        CashFlowType.income,
        1812.50, // 1,00,000 × 7.25% / 4
        'INR',
      );
    }

    // 3. US Stocks (USD, open) - Shows currency conversion in action. Stocks
    // need the user's own current value.
    final usStocks = createInvestment(
      name: 'Sample US Tech Stocks',
      type: InvestmentType.stocks,
      status: InvestmentStatus.open,
      currency: 'USD', // US Dollars (Rule 21.5)
      createdAt: daysAgo(180),
      notes:
          '📌 SAMPLE: USD investment shows exchange rate transparency in UI! '
          'Stocks use the current value you enter.',
      platform: 'Interactive Brokers',
      currentValue: 1550,
    );
    addCashFlow(usStocks.id, daysAgo(180), CashFlowType.invest, 1000, 'USD');
    addCashFlow(usStocks.id, daysAgo(90), CashFlowType.invest, 500, 'USD');
    addCashFlow(
      usStocks.id,
      daysAgo(30),
      CashFlowType.income,
      25,
      'USD',
    ); // Dividend

    // 4. European Bonds (EUR, open) - Shows multi-currency diversity. Both
    // 3.5% semi-annual coupons of the year are paid; valued at its
    // outstanding principal (A10).
    final eurBonds = createInvestment(
      name: 'Sample European Bonds',
      type: InvestmentType.bonds,
      status: InvestmentStatus.open,
      currency: 'EUR', // Euros (Rule 21.5)
      createdAt: daysAgo(360),
      incomeFrequency: IncomeFrequency.semiAnnual,
      notes: '📌 SAMPLE: EUR investment demonstrates multi-currency portfolio!',
      expectedRate: 3.5,
      platform: 'DEGIRO',
    );
    addCashFlow(eurBonds.id, daysAgo(360), CashFlowType.invest, 800, 'EUR');
    for (final days in [180, 0]) {
      addCashFlow(
        eurBonds.id,
        daysAgo(days),
        CashFlowType.income,
        14,
        'EUR',
      ); // Semi-annual interest
    }

    // 5. Gold/SGB (INR, open) - 2.5% interest plus the gold price. Gold
    // needs the user's own current value.
    final sgb = createInvestment(
      name: 'Sample SGB - 2024 Series',
      type: InvestmentType.gold,
      status: InvestmentStatus.open,
      currency: 'INR', // Indian Rupees (Rule 21.5)
      createdAt: daysAgo(200),
      maturityDate: daysAgo(-2720), // 8 year lock-in
      incomeFrequency: IncomeFrequency.semiAnnual,
      notes:
          '📌 SAMPLE: 2.5% interest + gold appreciation. Tax-free on maturity! '
          'Gold uses the current value you enter.',
      expectedRate: 2.5,
      tenureMonths: 96,
      platform: 'RBI',
      currentValue: 65000, // 10 grams at the sample's gold price
    );
    addCashFlow(
      sgb.id,
      daysAgo(200),
      CashFlowType.invest,
      62630,
      'INR',
    ); // 10 grams
    addCashFlow(
      sgb.id,
      daysAgo(17),
      CashFlowType.income,
      783,
      'INR',
    ); // Semi-annual interest

    // Bulk import investments
    await _investmentRepository.bulkImport(
      investments: investments,
      cashFlows: cashFlows,
    );

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
      currency: baseCurrency, // Dynamic currency from user settings (Rule 21.6)
      createdAt: daysAgo(365),
      updatedAt: now,
    );
    await _goalRepository.createGoal(emergencyFund);

    return (investmentIds: investmentIds, goalIds: goalIds);
  }

  /// Creates income projection demo data showcasing ML features.
  ///
  /// Creates 3 P2P investments with:
  /// - 12 months of historical income (for WMA training)
  /// - Platform-specific delay patterns (LenDenClub +2 days, Grip -1 day)
  /// - Variance patterns (5-15% variance for tolerance testing)
  /// - Seasonal patterns (Q4 bonus in December)
  ///
  /// **Multi-Currency (Rule 21.6):** Uses user's base currency
  Future<SampleDataResult> createIncomeProjectionData({required String baseCurrency}) async {
    final now = DateTime.now();
    final investments = <InvestmentEntity>[];
    final cashFlows = <CashFlowEntity>[];
    final investmentIds = <String>[];

    // Helper to create investment
    InvestmentEntity createInvestment({
      required String name,
      required InvestmentType type,
      required String currency,
      required DateTime createdAt,
      required IncomeFrequency incomeFrequency,
      required String platform,
      String? notes,
      double? expectedRate,
    }) {
      final id = _uuid.v4();
      investmentIds.add(id);
      final inv = InvestmentEntity(
        id: id,
        name: name,
        type: type,
        status: InvestmentStatus.open,
        currency: currency,
        createdAt: createdAt,
        updatedAt: now,
        incomeFrequency: incomeFrequency,
        notes: notes,
        expectedRate: expectedRate,
        platform: platform,
      );
      investments.add(inv);
      return inv;
    }

    // Helper to add cash flow with optional delay
    void addCashFlow(
      String investmentId,
      DateTime date,
      CashFlowType type,
      double amount,
      String currency, {
      int delayDays = 0,
    }) {
      cashFlows.add(
        CashFlowEntity(
          id: _uuid.v4(),
          investmentId: investmentId,
          date: date.add(Duration(days: delayDays)),
          type: type,
          amount: amount,
          currency: currency,
          createdAt: now,
        ),
      );
    }

    // ============================================================
    // INVESTMENT 1: LenDenClub (Consistent +2 day delay pattern)
    // ============================================================
    final lendenClub = createInvestment(
      name: 'LenDenClub Portfolio',
      type: InvestmentType.p2pLending,
      currency: baseCurrency,
      createdAt: now.subtract(const Duration(days: 365)),
      incomeFrequency: IncomeFrequency.monthly,
      platform: 'LenDenClub',
      notes: '📊 SAMPLE: Notice the consistent +2 day delay pattern!',
      expectedRate: 12.0,
    );

    // Initial investment
    addCashFlow(
      lendenClub.id,
      now.subtract(const Duration(days: 365)),
      CashFlowType.invest,
      100000,
      baseCurrency,
    );

    // 12 months of income with +2 day delay + 5-10% variance
    final baseAmount = 1000.0; // ~12% annual
    for (int i = 11; i >= 0; i--) {
      final variance = (i % 2 == 0) ? 1.05 : 0.95; // 5% variance
      final amount = baseAmount * variance;
      final expectedDate = DateTime(now.year, now.month - i, 5); // 5th of month
      addCashFlow(
        lendenClub.id,
        expectedDate,
        CashFlowType.income,
        amount,
        baseCurrency,
        delayDays: 2, // Consistent +2 day delay
      );
    }

    // ============================================================
    // INVESTMENT 2: Grip (Early payer: -1 day)
    // ============================================================
    final grip = createInvestment(
      name: 'Grip Invest - Asset Leasing',
      type: InvestmentType.p2pLending,
      currency: baseCurrency,
      createdAt: now.subtract(const Duration(days: 270)),
      incomeFrequency: IncomeFrequency.monthly,
      platform: 'Grip',
      notes: '📊 SAMPLE: Grip pays 1 day early! Trust score: High',
      expectedRate: 15.0,
    );

    // Initial investment
    addCashFlow(
      grip.id,
      now.subtract(const Duration(days: 270)),
      CashFlowType.invest,
      50000,
      baseCurrency,
    );

    // 9 months of income with -1 day (early) + 10-15% variance
    for (int i = 8; i >= 0; i--) {
      final variance = 1.0 + ((i % 3) * 0.05); // 0%, 5%, 10% variance
      final amount = 625.0 * variance; // ~15% annual
      final expectedDate = DateTime(now.year, now.month - i, 10); // 10th of month
      addCashFlow(
        grip.id,
        expectedDate,
        CashFlowType.income,
        amount,
        baseCurrency,
        delayDays: -1, // Pays 1 day early
      );
    }

    // ============================================================
    // INVESTMENT 3: Alt Graaf (Seasonal bonus in Q4)
    // ============================================================
    final altGraaf = createInvestment(
      name: 'AltGraaf - Corporate Bonds',
      type: InvestmentType.bonds,
      currency: baseCurrency,
      createdAt: now.subtract(const Duration(days: 730)), // 2 years
      incomeFrequency: IncomeFrequency.monthly,
      platform: 'AltGraaf',
      notes: '📊 SAMPLE: Notice the Q4 seasonal bonus pattern!',
      expectedRate: 10.5,
    );

    // Initial investment
    addCashFlow(
      altGraaf.id,
      now.subtract(const Duration(days: 730)),
      CashFlowType.invest,
      75000,
      baseCurrency,
    );

    // 24 months of income with Q4 seasonal bonus (Dec has 150% payout)
    for (int i = 23; i >= 0; i--) {
      final month = now.month - i;
      final year = now.year - (month <= 0 ? 1 : 0);
      final adjustedMonth = month <= 0 ? month + 12 : month;

      // Q4 bonus: December gets 150% payout
      final seasonalMultiplier = (adjustedMonth == 12) ? 1.5 : 1.0;
      final amount = 656.25 * seasonalMultiplier; // ~10.5% annual

      final date = DateTime(year, adjustedMonth, 15); // 15th of month
      addCashFlow(
        altGraaf.id,
        date,
        CashFlowType.income,
        amount,
        baseCurrency,
      );
    }

    // Bulk import investments
    await _investmentRepository.bulkImport(
      investments: investments,
      cashFlows: cashFlows,
    );

    return (investmentIds: investmentIds, goalIds: <String>[]);
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
