/// Curated demo data for the Play Store screenshots (POR-98).
///
/// Shared by the on-device capture (`integration_test/flows/store_screenshots_test.dart`)
/// and the emulator-free generator (`test/store_screenshots/`), so both render
/// the same portfolio. Everything here is made up: no real names, accounts or
/// amounts.
library;

import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/ui_extensions/goal_type_ui.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

/// The portfolio, goals and FIRE setup that the store screenshots show.
class StoreDemoData {
  const StoreDemoData({
    required this.investments,
    required this.cashFlows,
    required this.goals,
    required this.fireSettings,
  });

  final List<InvestmentEntity> investments;
  final List<CashFlowEntity> cashFlows;
  final List<GoalEntity> goals;
  final FireSettingsEntity fireSettings;

  /// Name of the investment shown on the detail screenshot.
  static const detailInvestmentName = 'Whitefield 2BHK';

  /// Builds the demo data relative to the day of [asOf]. Every date is
  /// date-only (money rule 5) and counted back from that day.
  factory StoreDemoData.build(DateTime asOf) {
    final now = DateTime(asOf.year, asOf.month, asOf.day);
    DateTime daysAgo(int days) => DateTime(now.year, now.month, now.day - days);

    // ============ CURATED POSITIVE / NEUTRAL PORTFOLIO ============
    // All entries are open-and-growing or closed-with-profit. Deliberately
    // excludes the loss/edge-case entries in SeedDataService so nothing
    // resembling a loss ever appears on a store screenshot.
    final investments = <InvestmentEntity>[];
    final cashFlows = <CashFlowEntity>[];
    var seq = 0;
    String nextId() => 'seed-${seq++}';

    InvestmentEntity addInvestment({
      required String name,
      required InvestmentType type,
      required InvestmentStatus status,
      required DateTime createdAt,
      DateTime? closedAt,
      DateTime? maturityDate,
      IncomeFrequency? incomeFrequency,
      String? notes,
      double? currentValue,
    }) {
      final inv = InvestmentEntity(
        id: nextId(),
        name: name,
        type: type,
        status: status,
        createdAt: createdAt,
        closedAt: closedAt,
        updatedAt: now,
        maturityDate: maturityDate,
        incomeFrequency: incomeFrequency,
        notes: notes,
        currency: 'INR',
        currentValue: currentValue,
        currentValueDate: currentValue == null ? null : now,
      );
      investments.add(inv);
      return inv;
    }

    void addCashFlow(
      String investmentId,
      DateTime date,
      CashFlowType type,
      double amount,
    ) {
      cashFlows.add(
        CashFlowEntity(
          id: nextId(),
          investmentId: investmentId,
          date: date,
          type: type,
          amount: amount,
          createdAt: now,
          currency: 'INR',
        ),
      );
    }

    // Six closed, profitable positions (a completed "cash in, cash out"
    // story) come first, then three open holdings that carry a current value
    // (see "OPEN HOLDINGS" below).

    // 1. HDFC Bank FD - matured with full principal + interest returned
    final hdfcFd = addInvestment(
      name: 'HDFC Bank FD',
      type: InvestmentType.fixedDeposit,
      status: InvestmentStatus.closed,
      createdAt: daysAgo(400),
      closedAt: daysAgo(10),
      maturityDate: daysAgo(10),
      incomeFrequency: IncomeFrequency.quarterly,
      notes: '7.25% p.a. for 3 years. Matured and reinvested elsewhere.',
    );
    addCashFlow(hdfcFd.id, daysAgo(400), CashFlowType.invest, 500000);
    for (int i = 4; i >= 1; i--) {
      addCashFlow(hdfcFd.id, daysAgo(10 + i * 90), CashFlowType.income, 9063);
    }
    addCashFlow(hdfcFd.id, daysAgo(10), CashFlowType.returnFlow, 500000);

    // 2. LenDenClub P2P - high yield, exited after a year
    final lendenClub = addInvestment(
      name: 'LenDenClub P2P',
      type: InvestmentType.p2pLending,
      status: InvestmentStatus.closed,
      createdAt: daysAgo(400),
      closedAt: daysAgo(30),
      incomeFrequency: IncomeFrequency.monthly,
      notes:
          'Auto-invest, 200+ borrowers. Withdrew after 12 months at 12% p.a.',
    );
    addCashFlow(lendenClub.id, daysAgo(400), CashFlowType.invest, 150000);
    for (int i = 12; i >= 1; i--) {
      addCashFlow(
        lendenClub.id,
        daysAgo(30 + i * 30),
        CashFlowType.income,
        1500,
      );
    }
    addCashFlow(lendenClub.id, daysAgo(30), CashFlowType.returnFlow, 150000);

    // 3. Whitefield 2BHK - real estate, rented then sold at a gain
    final bangaloreFlat = addInvestment(
      name: detailInvestmentName,
      type: InvestmentType.realEstate,
      status: InvestmentStatus.closed,
      createdAt: daysAgo(730),
      closedAt: daysAgo(20),
      incomeFrequency: IncomeFrequency.monthly,
      notes: 'Prestige Lakeside. Rented 2 years, then sold at a premium.',
    );
    addCashFlow(bangaloreFlat.id, daysAgo(730), CashFlowType.invest, 1500000);
    addCashFlow(bangaloreFlat.id, daysAgo(725), CashFlowType.fee, 75000);
    for (int i = 23; i >= 1; i--) {
      addCashFlow(
        bangaloreFlat.id,
        daysAgo(20 + i * 30),
        CashFlowType.income,
        28000,
      );
    }
    addCashFlow(
      bangaloreFlat.id,
      daysAgo(20),
      CashFlowType.returnFlow,
      1700000,
    );

    // 4. Sovereign Gold Bonds - redeemed early as gold prices rallied
    final sgb = addInvestment(
      name: 'SGB 2024-25 Series I',
      type: InvestmentType.gold,
      status: InvestmentStatus.closed,
      createdAt: daysAgo(365),
      closedAt: daysAgo(15),
      incomeFrequency: IncomeFrequency.semiAnnual,
      notes: 'Issue price ₹6,263/gm. Redeemed early after a gold price rally.',
    );
    addCashFlow(sgb.id, daysAgo(365), CashFlowType.invest, 125260);
    addCashFlow(sgb.id, daysAgo(180), CashFlowType.income, 1566);
    addCashFlow(sgb.id, daysAgo(15), CashFlowType.returnFlow, 148000);

    // 5. Faircent P2P - closed with profit
    final faircent = addInvestment(
      name: 'Faircent Portfolio',
      type: InvestmentType.p2pLending,
      status: InvestmentStatus.closed,
      createdAt: daysAgo(500),
      closedAt: daysAgo(45),
      incomeFrequency: IncomeFrequency.monthly,
      notes: 'Exited after 15 months. Final XIRR: 14.2%',
    );
    addCashFlow(faircent.id, daysAgo(500), CashFlowType.invest, 100000);
    for (int i = 15; i >= 1; i--) {
      addCashFlow(faircent.id, daysAgo(45 + i * 30), CashFlowType.income, 1180);
    }
    addCashFlow(faircent.id, daysAgo(45), CashFlowType.returnFlow, 100000);

    // 6. UTI Nifty 50 Index Fund - SIP redeemed at a gain (mutual fund diversity)
    final niftyFund = addInvestment(
      name: 'UTI Nifty 50 Index',
      type: InvestmentType.mutualFunds,
      status: InvestmentStatus.closed,
      createdAt: daysAgo(540),
      closedAt: daysAgo(5),
      notes: 'SIP ₹15,000/month, direct plan. Redeemed after 18 months.',
    );
    for (int i = 18; i >= 1; i--) {
      addCashFlow(
        niftyFund.id,
        daysAgo(5 + i * 30),
        CashFlowType.invest,
        15000,
      );
    }
    addCashFlow(niftyFund.id, daysAgo(5), CashFlowType.returnFlow, 315000);

    // ============ OPEN HOLDINGS - what is held today ============
    // Since A11/A12 goals and FIRE count what is held today (open
    // investments at their dated current value), the closed positions above
    // add nothing to them. These three are still open, each with a current
    // value, so the goals and FIRE cards show progress. They are kept small
    // and their last activity is older than the closed positions' above, so
    // the Overview card (net cash flow, where money still invested counts as
    // paid out) stays positive and the first Investments cards stay green:
    // an open investment's card shows its net cash flow, which is negative.

    // 7. Bajaj Finance FD - open, interest paid out every quarter
    final bajajFd = addInvestment(
      name: 'Bajaj Finance FD',
      type: InvestmentType.fixedDeposit,
      status: InvestmentStatus.open,
      createdAt: daysAgo(300),
      maturityDate: daysAgo(-430),
      incomeFrequency: IncomeFrequency.quarterly,
      notes: '8.05% p.a., interest paid every quarter. Matures in 14 months.',
      currentValue: 500000,
    );
    addCashFlow(bajajFd.id, daysAgo(300), CashFlowType.invest, 500000);
    for (int i = 3; i >= 1; i--) {
      addCashFlow(bajajFd.id, daysAgo(i * 90 - 60), CashFlowType.income, 10060);
    }

    // 8. LiquiLoans P2P - open, monthly interest
    final liquiLoans = addInvestment(
      name: 'LiquiLoans P2P',
      type: InvestmentType.p2pLending,
      status: InvestmentStatus.open,
      createdAt: daysAgo(340),
      incomeFrequency: IncomeFrequency.monthly,
      notes: 'Lend-flexible plan at 12% p.a., interest paid every month.',
      currentValue: 200000,
    );
    addCashFlow(liquiLoans.id, daysAgo(340), CashFlowType.invest, 200000);
    for (int i = 10; i >= 0; i--) {
      addCashFlow(
        liquiLoans.id,
        daysAgo(24 + i * 30),
        CashFlowType.income,
        2000,
      );
    }

    // 9. Parag Parikh Flexi Cap - open SIP, up since the first instalment
    final flexiCap = addInvestment(
      name: 'Parag Parikh Flexi Cap',
      type: InvestmentType.mutualFunds,
      status: InvestmentStatus.open,
      createdAt: daysAgo(365),
      notes: 'SIP ₹12,500/month, direct plan, started a year ago.',
      currentValue: 172000,
    );
    for (int i = 12; i >= 1; i--) {
      addCashFlow(flexiCap.id, daysAgo(i * 30), CashFlowType.invest, 12500);
    }

    // ============ GOALS - same well-progressed set as the live set ============
    final goals = <GoalEntity>[
      GoalEntity(
        id: 'goal-emergency',
        name: 'Emergency Fund',
        type: GoalType.targetAmount,
        targetAmount: 500000,
        trackingMode: GoalTrackingMode.byType,
        linkedTypes: const [InvestmentType.fixedDeposit],
        icon: '🛡️',
        colorValue: GoalColors.available[1].toARGB32(),
        currency: 'INR',
        createdAt: daysAgo(365),
        updatedAt: now,
      ),
      GoalEntity(
        id: 'goal-crore',
        name: '₹1 Crore Portfolio',
        type: GoalType.targetAmount,
        targetAmount: 10000000,
        trackingMode: GoalTrackingMode.all,
        icon: '🎯',
        colorValue: GoalColors.available[0].toARGB32(),
        currency: 'INR',
        createdAt: daysAgo(730),
        updatedAt: now,
      ),
      GoalEntity(
        id: 'goal-income',
        name: '₹50K Monthly Income',
        type: GoalType.incomeTarget,
        targetAmount: 600000,
        targetMonthlyIncome: 50000,
        trackingMode: GoalTrackingMode.byType,
        linkedTypes: const [
          InvestmentType.realEstate,
          InvestmentType.fixedDeposit,
          InvestmentType.p2pLending,
        ],
        icon: '💰',
        colorValue: GoalColors.available[2].toARGB32(),
        currency: 'INR',
        createdAt: daysAgo(500),
        updatedAt: now,
      ),
      GoalEntity(
        id: 'goal-house',
        name: 'House Down Payment',
        type: GoalType.targetDate,
        targetAmount: 2500000,
        targetDate: daysAgo(-730),
        trackingMode: GoalTrackingMode.selected,
        linkedInvestmentIds: [flexiCap.id],
        icon: '🏠',
        colorValue: GoalColors.available[4].toARGB32(),
        currency: 'INR',
        createdAt: daysAgo(200),
        updatedAt: now,
      ),
      GoalEntity(
        id: 'goal-education',
        name: 'Child Education',
        type: GoalType.targetDate,
        targetAmount: 5000000,
        targetDate: daysAgo(-5475),
        trackingMode: GoalTrackingMode.byType,
        linkedTypes: const [InvestmentType.mutualFunds],
        icon: '🎓',
        colorValue: GoalColors.available[5].toARGB32(),
        currency: 'INR',
        createdAt: daysAgo(100),
        updatedAt: now,
      ),
    ];

    // ============ FIRE SETTINGS - completed setup, in-memory ============
    final fireSettings = FireSettingsEntity(
      id: 'fire-settings-demo',
      monthlyExpenses: 60000,
      birthYear: FireSettingsEntity.birthYearForAge(32, now),
      targetFireAge: 45,
      currency: 'INR',
      monthlyPassiveIncome: 15000,
      isSetupComplete: true,
      createdAt: daysAgo(200),
      updatedAt: now,
    );

    return StoreDemoData(
      investments: investments,
      cashFlows: cashFlows,
      goals: goals,
      fireSettings: fireSettings,
    );
  }
}
