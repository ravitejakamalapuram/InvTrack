/// Captures the Play Store screenshot set (POR-98) using curated,
/// all-positive demo data so no real/loss-showing data ever reaches
/// a screenshot. Screens: Overview, FIRE dashboard, Goals, Investments
/// list, Privacy Mode, Investment detail.
///
/// Run with `flutter drive --profile` (not the default debug build) - a
/// debug build always renders Flutter's red "DEBUG" ribbon over the UI,
/// which is not something we want on a real store listing.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:inv_tracker/core/widgets/privacy_toggle_button.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/presentation/providers/fire_providers.dart';
import 'package:inv_tracker/features/fire_number/presentation/widgets/fire_dashboard_card.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/ui_extensions/goal_type_ui.dart';
import 'package:inv_tracker/features/income_projection/presentation/providers/income_guardian_service_providers.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/firebase_options.dart';

import '../mocks/fake_fire_settings_repository.dart';
import '../robots/robots.dart';
import '../test_app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('capture store screenshot set', (tester) async {
    // Register the Firebase app locally (no network needed for this) so
    // provider chains that call FirebaseFirestore.instance / FirebaseAuth.instance
    // don't throw "No Firebase App" during widget build. Real Firestore/Auth
    // reads triggered by those providers fail gracefully in the background
    // (same as the shipped app when offline) since they're not overridden.
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (_) {
      // Already initialized or unavailable - the app tolerates this.
    }

    final testApp = await TestApp.create(tester);
    final now = DateTime.now();

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
        ),
      );
    }

    // Note on the numbers below: this app's XIRR/MOIC/Net Position are
    // purely cash-flow based (money out vs. money back in) - there is no
    // "current market value" cash flow type for open positions. That means
    // an open investment always nets negative until its gains are realized
    // as income or a return flow. To get honest, non-scary demo numbers
    // every investment here is a closed, profitable position (a completed
    // "cash in, cash out" story) rather than an artificially still-open one.

    // 1. HDFC Bank FD - matured with full principal + interest returned
    final hdfcFd = addInvestment(
      name: 'HDFC Bank FD',
      type: InvestmentType.fixedDeposit,
      status: InvestmentStatus.closed,
      createdAt: now.subtract(const Duration(days: 400)),
      closedAt: now.subtract(const Duration(days: 10)),
      maturityDate: now.subtract(const Duration(days: 10)),
      incomeFrequency: IncomeFrequency.quarterly,
      notes: '7.25% p.a. for 3 years. Matured and reinvested elsewhere.',
    );
    addCashFlow(hdfcFd.id, now.subtract(const Duration(days: 400)), CashFlowType.invest, 500000);
    for (int i = 4; i >= 1; i--) {
      addCashFlow(hdfcFd.id, now.subtract(Duration(days: 10 + i * 90)), CashFlowType.income, 9063);
    }
    addCashFlow(hdfcFd.id, now.subtract(const Duration(days: 10)), CashFlowType.returnFlow, 500000);

    // 2. LenDenClub P2P - high yield, exited after a year
    final lendenClub = addInvestment(
      name: 'LenDenClub P2P',
      type: InvestmentType.p2pLending,
      status: InvestmentStatus.closed,
      createdAt: now.subtract(const Duration(days: 400)),
      closedAt: now.subtract(const Duration(days: 30)),
      incomeFrequency: IncomeFrequency.monthly,
      notes: 'Auto-invest, 200+ borrowers. Withdrew after 12 months at 12% p.a.',
    );
    addCashFlow(lendenClub.id, now.subtract(const Duration(days: 400)), CashFlowType.invest, 150000);
    for (int i = 12; i >= 1; i--) {
      addCashFlow(lendenClub.id, now.subtract(Duration(days: 30 + i * 30)), CashFlowType.income, 1500);
    }
    addCashFlow(lendenClub.id, now.subtract(const Duration(days: 30)), CashFlowType.returnFlow, 150000);

    // 3. Whitefield 2BHK - real estate, rented then sold at a gain
    final bangaloreFlat = addInvestment(
      name: 'Whitefield 2BHK',
      type: InvestmentType.realEstate,
      status: InvestmentStatus.closed,
      createdAt: now.subtract(const Duration(days: 730)),
      closedAt: now.subtract(const Duration(days: 20)),
      incomeFrequency: IncomeFrequency.monthly,
      notes: 'Prestige Lakeside. Rented 2 years, then sold at a premium.',
    );
    addCashFlow(bangaloreFlat.id, now.subtract(const Duration(days: 730)), CashFlowType.invest, 1500000);
    addCashFlow(bangaloreFlat.id, now.subtract(const Duration(days: 725)), CashFlowType.fee, 75000);
    for (int i = 23; i >= 1; i--) {
      addCashFlow(bangaloreFlat.id, now.subtract(Duration(days: 20 + i * 30)), CashFlowType.income, 28000);
    }
    addCashFlow(bangaloreFlat.id, now.subtract(const Duration(days: 20)), CashFlowType.returnFlow, 1700000);

    // 4. Sovereign Gold Bonds - redeemed early as gold prices rallied
    final sgb = addInvestment(
      name: 'SGB 2024-25 Series I',
      type: InvestmentType.gold,
      status: InvestmentStatus.closed,
      createdAt: now.subtract(const Duration(days: 365)),
      closedAt: now.subtract(const Duration(days: 15)),
      incomeFrequency: IncomeFrequency.semiAnnual,
      notes: 'Issue price ₹6,263/gm. Redeemed early after a gold price rally.',
    );
    addCashFlow(sgb.id, now.subtract(const Duration(days: 365)), CashFlowType.invest, 125260);
    addCashFlow(sgb.id, now.subtract(const Duration(days: 180)), CashFlowType.income, 1566);
    addCashFlow(sgb.id, now.subtract(const Duration(days: 15)), CashFlowType.returnFlow, 148000);

    // 5. Faircent P2P - closed with profit
    final faircent = addInvestment(
      name: 'Faircent Portfolio',
      type: InvestmentType.p2pLending,
      status: InvestmentStatus.closed,
      createdAt: now.subtract(const Duration(days: 500)),
      closedAt: now.subtract(const Duration(days: 45)),
      incomeFrequency: IncomeFrequency.monthly,
      notes: 'Exited after 15 months. Final XIRR: 14.2%',
    );
    addCashFlow(faircent.id, now.subtract(const Duration(days: 500)), CashFlowType.invest, 100000);
    for (int i = 15; i >= 1; i--) {
      addCashFlow(faircent.id, now.subtract(Duration(days: 45 + i * 30)), CashFlowType.income, 1180);
    }
    addCashFlow(faircent.id, now.subtract(const Duration(days: 45)), CashFlowType.returnFlow, 100000);

    // 6. UTI Nifty 50 Index Fund - SIP redeemed at a gain (mutual fund diversity)
    final niftyFund = addInvestment(
      name: 'UTI Nifty 50 Index',
      type: InvestmentType.mutualFunds,
      status: InvestmentStatus.closed,
      createdAt: now.subtract(const Duration(days: 540)),
      closedAt: now.subtract(const Duration(days: 5)),
      notes: 'SIP ₹15,000/month, direct plan. Redeemed after 18 months.',
    );
    for (int i = 18; i >= 1; i--) {
      addCashFlow(niftyFund.id, now.subtract(Duration(days: 5 + i * 30)), CashFlowType.invest, 15000);
    }
    addCashFlow(niftyFund.id, now.subtract(const Duration(days: 5)), CashFlowType.returnFlow, 315000);

    testApp.seedInvestments(investments, cashFlows);

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
        createdAt: now.subtract(const Duration(days: 365)),
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
        createdAt: now.subtract(const Duration(days: 730)),
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
        createdAt: now.subtract(const Duration(days: 500)),
        updatedAt: now,
      ),
      GoalEntity(
        id: 'goal-house',
        name: 'House Down Payment',
        type: GoalType.targetDate,
        targetAmount: 2500000,
        targetDate: now.add(const Duration(days: 730)),
        trackingMode: GoalTrackingMode.selected,
        linkedInvestmentIds: [niftyFund.id],
        icon: '🏠',
        colorValue: GoalColors.available[4].toARGB32(),
        currency: 'INR',
        createdAt: now.subtract(const Duration(days: 200)),
        updatedAt: now,
      ),
      GoalEntity(
        id: 'goal-education',
        name: 'Child Education',
        type: GoalType.targetDate,
        targetAmount: 5000000,
        targetDate: now.add(const Duration(days: 5475)),
        trackingMode: GoalTrackingMode.byType,
        linkedTypes: const [InvestmentType.mutualFunds],
        icon: '🎓',
        colorValue: GoalColors.available[5].toARGB32(),
        currency: 'INR',
        createdAt: now.subtract(const Duration(days: 100)),
        updatedAt: now,
      ),
    ];
    testApp.seedGoals(goals);

    // ============ FIRE SETTINGS - completed setup, in-memory ============
    final fireSettings = FireSettingsEntity(
      id: 'fire-settings-demo',
      monthlyExpenses: 60000,
      currentAge: 32,
      targetFireAge: 45,
      monthlyPassiveIncome: 15000,
      isSetupComplete: true,
      createdAt: now.subtract(const Duration(days: 200)),
      updatedAt: now,
    );

    await testApp.pumpApp(
      extraOverrides: [
        fireSettingsRepositoryProvider.overrideWithValue(
          FakeFireSettingsRepository(initialSettings: fireSettings),
        ),
        flutterLocalNotificationsPluginProvider.overrideWithValue(
          FlutterLocalNotificationsPlugin(),
        ),
      ],
    );

    final nav = NavigationRobot(tester);
    final inv = InvestmentRobot(tester);
    final binding = IntegrationTestWidgetsFlutterBinding.instance;

    // Background currency-conversion calls fail/timeout in this offline test
    // environment (no live network), which can leave cards mid-loading-spinner
    // right after pumpApp. Give them time to settle into their final
    // (graceful, cached-rate) state before the very first screenshot.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.pumpAndSettle();

    // convertFlutterSurfaceToImage() is a one-time, irreversible switch - call
    // it once up front rather than per-screenshot (nav.takeScreenshot does
    // the latter and silently no-ops on every screenshot after the first).
    await binding.convertFlutterSurfaceToImage();
    Future<void> shot(String name) async {
      await tester.pumpAndSettle();
      await binding.takeScreenshot(name);
    }

    // 1. Overview dashboard
    nav.verifyOnOverview();
    await shot('store_01_overview');

    // 2. FIRE Number dashboard
    await nav.tap(find.byType(FireDashboardCard));
    await shot('store_02_fire_dashboard');
    await nav.goBack();

    // 3. Goals list
    await nav.goToGoals();
    nav.verifyOnGoals();
    await shot('store_03_goals');

    // 4. Investments list - shows the breadth of asset types at a glance
    await nav.goToInvestments();
    nav.verifyOnInvestments();
    await shot('store_04_investments_list');

    // 5. Privacy Mode - toggle on from Overview, mask amounts
    await nav.goToOverview();
    nav.verifyOnOverview();
    await nav.tap(find.byType(PrivacyToggleButton).first);
    await shot('store_05_privacy_mode');
    // Turn privacy mode back off so the detail screen below renders normally.
    await nav.tap(find.byType(PrivacyToggleButton).first);

    // 6. Investment detail - another strong feature screen (full cash flow
    // history for a closed, profitable real-estate investment).
    await nav.goToInvestments();
    nav.verifyOnInvestments();
    await inv.tapInvestment('Whitefield 2BHK');
    await shot('store_06_investment_detail');
  });
}
