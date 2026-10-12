// A gallery of the widgets the colour-contrast PRs change, in light and dark.
//
// The baseline images are committed with the guard. Each later PR
// regenerates only the scenes it changes, so the image diff on GitHub is the
// before and after.
//
// Tagged `golden`, so the pull-request run (release.yaml, `--exclude-tags=
// golden`) skips it. The nightly workflow does run it (`flutter test --tags
// golden test/golden`), so these images are compared every night. They
// depend on glyph rendering: Roboto stands in for Plus Jakarta Sans because
// the bundled font files are unusable (#973). When #973 restores them, the
// fallback stops applying and the nightly run fails until the images are
// regenerated in the same change. Regenerate locally with
//   flutter test --tags golden --update-goldens test/golden/contrast
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_theme.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/app_text_field.dart';
import 'package:inv_tracker/core/widgets/change_badge.dart';
import 'package:inv_tracker/core/widgets/currency_badge.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/metric_tile.dart';
import 'package:inv_tracker/core/widgets/type_selector.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_calculation_result.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/domain/services/fire_calculation_service.dart';
import 'package:inv_tracker/features/fire_number/presentation/providers/fire_providers.dart';
import 'package:inv_tracker/features/fire_number/presentation/widgets/fire_dashboard_card.dart';
import 'package:inv_tracker/features/fire_number/presentation/widgets/fire_load_error_card.dart';
import 'package:inv_tracker/features/fire_number/presentation/widgets/fire_stats_card.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goal_card.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goal_carousel_card.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goals_dashboard_card.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/ui_extensions/investment_ui.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/cash_flow_card_widget.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_card.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_detail_stats_section.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/hero_card.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/overview_analytics.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/overview_empty_state.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/overview_quick_stats.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/sample_data_banner.dart';
import 'package:inv_tracker/features/settings/presentation/providers/sample_data_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../mocks/mock_analytics_service.dart';
import '../../store_screenshots/store_screenshot_harness.dart'
    show loadStoreScreenshotFonts;
import '../golden_test_helper.dart';

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

class _SampleModeOn extends SampleDataModeNotifier {
  @override
  SampleDataState build() => const SampleDataState(isActive: true);
}

final _inr = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

// Demo figures only.
const _gain = InvestmentStats(
  totalInvested: 1000000,
  totalReturned: 1114000,
  netCashFlow: 114000,
  absoluteReturn: 11.4,
  moic: 1.114,
  xirr: 0.114,
  cashFlowCount: 2,
  cashOnlyCount: 1,
);

const _loss = InvestmentStats(
  totalInvested: 100000,
  totalReturned: 50000,
  netCashFlow: -50000,
  absoluteReturn: -50,
  moic: 0.5,
  xirr: -0.5258,
  cashFlowCount: 3,
);

Widget _fields() => Padding(
  padding: const EdgeInsets.all(16),
  child: Form(
    autovalidateMode: AutovalidateMode.always,
    child: Column(
      children: [
        const AppTextField(label: 'Idle', hint: 'Enter a name'),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Focused',
          hint: 'Enter a name',
          autofocus: true,
          controller: TextEditingController(text: 'Demo'),
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Error',
          hint: 'Enter a name',
          validator: (_) => 'Enter a name',
        ),
      ],
    ),
  ),
);

Widget _hero(
  InvestmentStats stats, {
  bool realizedOnly = false,
  int archived = 0,
}) => HeroCardContent(
  globalStats: stats,
  openStats: realizedOnly ? InvestmentStats.empty() : stats,
  closedStats: realizedOnly ? stats : InvestmentStats.empty(),
  currencyFormat: _inr,
  showRealizedOnly: realizedOnly,
  archivedCount: archived,
);

/// One picture: its content and the providers the content reads. Each scene
/// is as tall as its content, on the page colour of its theme.
class _Scene {
  const _Scene({
    required this.build,
    this.overrides = const [],
    this.height = 900,
  });
  final Widget Function() build;
  final List<Override> overrides;

  /// The room the scene may use; the image is as tall as the content.
  final double height;
}

// The investment card's maturity chips are relative to this day.
final _today = DateTime(2026, 10, 11);

InvestmentEntity _investment(
  String id,
  String name,
  InvestmentType type, {
  InvestmentStatus status = InvestmentStatus.open,
  DateTime? maturity,
}) => InvestmentEntity(
  id: id,
  name: name,
  type: type,
  status: status,
  createdAt: DateTime(2024, 10, 1),
  updatedAt: DateTime(2024, 10, 1),
  currency: 'INR',
  maturityDate: maturity,
);

// Demo figures only: a gain paid out, a realised loss and an investment that
// has had nothing back yet.
InvestmentStats _paidOut(double invested, double returned, double xirr) =>
    InvestmentStats(
      totalInvested: invested,
      totalReturned: returned,
      netCashFlow: returned - invested,
      absoluteReturn: (returned - invested) / invested * 100,
      moic: returned / invested,
      xirr: xirr,
      cashFlowCount: 2,
      firstCashFlowDate: DateTime(2024, 10, 1),
      lastCashFlowDate: DateTime(2026, 10, 1),
    );

final _awaitingPayout = InvestmentStats(
  totalInvested: 100000,
  totalReturned: 0,
  netCashFlow: -100000,
  absoluteReturn: -100,
  moic: 0,
  xirr: null,
  xirrMethod: XirrMethod.undefined,
  cashFlowCount: 1,
  firstCashFlowDate: DateTime(2026, 9, 1),
  lastCashFlowDate: DateTime(2026, 9, 1),
);

({InvestmentEntity investment, List<Override> overrides}) _card(
  InvestmentEntity investment,
  InvestmentStats stats,
  XirrResult xirr,
) => (
  investment: investment,
  overrides: [
    investmentBasicStatsProvider(
      investment.id,
    ).overrideWith((ref) => AsyncValue.data(stats)),
    investmentXirrProvider(
      investment.id,
    ).overrideWith((ref) => Future.value(xirr)),
  ],
);

// Five cards: MATURED, a chip due in 5 days, one due in 20 days, a closed
// investment with a loss, and one awaiting its first payout.
final _cards = [
  _card(
    _investment(
      'demo-1',
      'Demo fixed deposit',
      InvestmentType.fixedDeposit,
      maturity: DateTime(2026, 10, 1),
    ),
    _paidOut(1000000, 1114000, 0.114),
    const XirrResult.exact(0.114),
  ),
  _card(
    _investment(
      'demo-2',
      'Demo bonds',
      InvestmentType.bonds,
      maturity: DateTime(2026, 10, 16),
    ),
    _paidOut(500000, 540000, 0.082),
    const XirrResult.exact(0.082),
  ),
  _card(
    _investment(
      'demo-3',
      'Demo P2P loan',
      InvestmentType.p2pLending,
      maturity: DateTime(2026, 10, 31),
    ),
    _paidOut(200000, 221000, 0.105),
    const XirrResult.exact(0.105),
  ),
  _card(
    _investment(
      'demo-4',
      'Demo stocks',
      InvestmentType.stocks,
      status: InvestmentStatus.closed,
    ),
    _paidOut(100000, 50000, -0.5258),
    const XirrResult.exact(-0.5258),
  ),
  _card(
    _investment('demo-5', 'Demo gold', InvestmentType.gold),
    _awaitingPayout,
    const XirrResult.undefined(XirrUndefinedReason.insufficientFlows),
  ),
];

// An investment with no cash flow yet: its card shows the View Details link.
final _noCashFlows = _card(
  _investment('demo-6', 'Demo mutual fund', InvestmentType.mutualFunds),
  InvestmentStats.empty(),
  const XirrResult.undefined(XirrUndefinedReason.insufficientFlows),
);

// One card per investment type, each with a gain and no maturity chip, and a
// closed one, to show every type's chip and tile (demo figures only).
final _typeCards = [
  for (final type in InvestmentType.values)
    _card(
      _investment('type-${type.name}', 'Demo ${type.displayName}', type),
      _paidOut(100000, 112000, 0.08),
      const XirrResult.exact(0.08),
    ),
  _card(
    _investment(
      'type-closed',
      'Demo closed',
      InvestmentType.gold,
      status: InvestmentStatus.closed,
    ),
    _paidOut(100000, 112000, 0.08),
    const XirrResult.exact(0.08),
  ),
];

// Demo figures only: six months of money in and out.
final _trend = [
  for (final (i, (inflows, outflows)) in [
    (42000.0, 30000.0),
    (0.0, 65000.0),
    (88000.0, 12000.0),
    (25000.0, 54000.0),
    (61000.0, 20000.0),
    (35000.0, 47000.0),
  ].indexed)
    MonthlyCashFlowData(
      month: DateTime(2026, 5 + i, 1),
      inflows: inflows,
      outflows: outflows,
    ),
];

CashFlowEntity _cashFlow(String id, CashFlowType type, double amount) =>
    CashFlowEntity(
      id: id,
      investmentId: 'demo-1',
      date: DateTime(2026, 9, 15),
      type: type,
      amount: amount,
      currency: 'INR',
      createdAt: DateTime(2026, 9, 15),
    );

/// Scene name and content. The names are the file names.
final _scenes = <String, _Scene>{
  'investment_cards': _Scene(
    height: 1400,
    overrides: [for (final c in _cards) ...c.overrides],
    build: () => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (final c in _cards) ...[
            InvestmentCard(
              investment: c.investment,
              isSelectionMode: false,
              isSelected: false,
              onTap: () {},
              referenceDate: _today,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    ),
  ),
  'type_cards': _Scene(
    height: 2400,
    overrides: [for (final c in _typeCards) ...c.overrides],
    build: () => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (final c in _typeCards)
            InvestmentCard(
              investment: c.investment,
              isSelectionMode: false,
              isSelected: false,
              onTap: () {},
              referenceDate: _today,
            ),
        ],
      ),
    ),
  ),
  'change_badge': _Scene(
    build: () => const Padding(
      padding: EdgeInsets.all(16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          ChangeBadge(value: 12.5),
          ChangeBadge(value: -4.25),
          ChangeBadge(value: 0),
          ChangeBadge(value: 3.1, size: ChangeBadgeSize.small),
          ChangeBadge(value: -8, size: ChangeBadgeSize.large),
        ],
      ),
    ),
  ),
  'text_fields': _Scene(build: _fields),
  'buttons': _Scene(
    build: () => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {},
              child: const Text('Outlined'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              child: const Text('Filled'),
            ),
          ),
        ],
      ),
    ),
  ),
  'card_edges': _Scene(
    build: () => const Padding(
      padding: EdgeInsets.all(16),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Card title'),
            SizedBox(height: 8),
            Divider(),
            SizedBox(height: 8),
            Text('Below a divider'),
          ],
        ),
      ),
    ),
  ),
  'metric_tiles': _Scene(
    build: () => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          MetricTile(
            label: 'Net cash flow',
            value: '₹1,14,000',
            change: '+11.4%',
            isPositive: true,
            icon: Icons.trending_up_rounded,
            onTap: () {},
          ),
          const SizedBox(height: 12),
          MetricTile(
            label: 'Net position',
            value: '-₹50,000',
            change: '-50.0%',
            isPositive: false,
            icon: Icons.trending_down_rounded,
            onTap: () {},
          ),
        ],
      ),
    ),
  ),
  'currency_badges': _Scene(
    build: () => const Padding(
      padding: EdgeInsets.all(16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          CurrencyBadge(currencyCode: 'USD', compact: true),
          CurrencyBadge(
            currencyCode: 'USD',
            exchangeRate: 83.12,
            targetCurrency: 'INR',
          ),
        ],
      ),
    ),
  ),
  'type_chips': _Scene(
    build: () => Padding(
      padding: const EdgeInsets.all(16),
      child: TypeSelector<InvestmentType>(
        values: InvestmentType.values,
        selectedValue: InvestmentType.bonds,
        onSelected: (_) {},
        colorBuilder: (t) => t.color,
        iconBuilder: (t) => t.icon,
        labelBuilder: (t) => t.displayName,
      ),
    ),
  ),
  'type_chips_more': _Scene(
    height: 1200,
    build: () => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (final selected in [
            InvestmentType.gold,
            InvestmentType.crypto,
          ]) ...[
            TypeSelector<InvestmentType>(
              values: InvestmentType.values,
              selectedValue: selected,
              onSelected: (_) {},
              colorBuilder: (t) => t.color,
              iconBuilder: (t) => t.icon,
              labelBuilder: (t) => t.displayName,
            ),
            const SizedBox(height: 16),
          ],
          TypeSelector<DocumentType>(
            values: DocumentType.values,
            selectedValue: DocumentType.certificate,
            onSelected: (_) {},
            colorBuilder: (t) => t.color,
            iconBuilder: (t) => t.icon,
            labelBuilder: (t) => t.name,
          ),
        ],
      ),
    ),
  ),
  'hero_card_gain': _Scene(
    build: () => Padding(
      padding: const EdgeInsets.all(16),
      child: _hero(_gain, archived: 1),
    ),
  ),
  'hero_card_loss': _Scene(
    build: () => Padding(
      padding: const EdgeInsets.all(16),
      child: _hero(_loss, realizedOnly: true),
    ),
  ),
  'view_details_card': _Scene(
    height: 300,
    overrides: _noCashFlows.overrides,
    build: () => Padding(
      padding: const EdgeInsets.all(16),
      child: InvestmentCard(
        investment: _noCashFlows.investment,
        isSelectionMode: false,
        isSelected: false,
        onTap: () {},
        referenceDate: _today,
      ),
    ),
  ),
  'overview_tiles': _Scene(
    height: 500,
    build: () => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          OverviewQuickStats(
            stats: _paidOut(1000000, 1114000, 0.114),
            openStats: InvestmentStats.empty(),
          ),
          const SizedBox(height: 12),
          OverviewQuickStats(
            stats: _awaitingPayout,
            openStats: _awaitingPayout,
          ),
          const SizedBox(height: 12),
          OverviewLoadErrorState(onRetry: () {}),
        ],
      ),
    ),
  ),
  'cash_flow_chart': _Scene(
    height: 400,
    overrides: [
      monthlyCashFlowTrendProvider.overrideWithValue(AsyncValue.data(_trend)),
    ],
    build: () => Padding(
      padding: const EdgeInsets.all(16),
      child: MonthlyCashFlowTrend(currencyFormat: _inr),
    ),
  ),
  'goals_cards': _Scene(
    height: 420,
    overrides: [
      currencyLocaleProvider.overrideWith((ref) => 'en_IN'),
      // The goal card shows its error line when the progress cannot load.
      multiCurrencyGoalProgressProvider(
        _goal.id,
      ).overrideWith((ref) => Future<GoalProgress>.error(Exception('offline'))),
    ],
    build: () => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GoalCarouselCard(progress: _goalAchieved, width: 368),
          const SizedBox(height: 12),
          GoalCard(goal: _goal, onTap: () {}),
        ],
      ),
    ),
  ),
  'fire_cards': _Scene(
    height: 420,
    overrides: [
      currencyLocaleProvider.overrideWith((ref) => 'en_IN'),
      fireSettingsProvider.overrideWith((ref) => Stream.value(_fireSettings)),
      fireCalculationProvider.overrideWithValue(AsyncValue.data(_fireAhead)),
    ],
    build: () => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const FireDashboardCard(),
          const SizedBox(height: 12),
          FireLoadErrorCard(onRetry: () {}),
        ],
      ),
    ),
  ),
  // Behind schedule: the status icon, label and percentage in the deeper amber
  // on a chip tinted with the bright amber, and the FIRE and Barista icons.
  'fire_cards_behind': _Scene(
    height: 700,
    overrides: [
      currencyLocaleProvider.overrideWith((ref) => 'en_IN'),
      fireSettingsProvider.overrideWith((ref) => Stream.value(_fireSettings)),
      fireCalculationProvider.overrideWithValue(AsyncValue.data(_fireBehind)),
    ],
    build: () => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const FireDashboardCard(),
          const SizedBox(height: 12),
          FireStatsCard(calculation: _fireBehind, currencySymbol: '₹'),
        ],
      ),
    ),
  ),
  // The empty Overview: the XIRR demo's amber figure, the Import CSV tile and
  // the sample-data tile with its "Try It" button.
  'overview_empty_state': _Scene(
    height: 1700,
    build: () => Padding(
      padding: const EdgeInsets.all(16),
      child: OverviewEmptyState(onImportCsv: () {}, onTrySampleData: () {}),
    ),
  ),
  'sample_data_banner': _Scene(
    height: 200,
    overrides: [sampleDataModeProvider.overrideWith(_SampleModeOn.new)],
    build: () =>
        const Padding(padding: EdgeInsets.all(16), child: SampleDataBanner()),
  ),
  // The investment detail: the net position, the return badge and the
  // maturity row, for a gain that has matured and for a loss.
  'detail_stats': _Scene(
    height: 1500,
    build: () => Padding(
      padding: const EdgeInsets.all(16),
      child: Builder(
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          Widget section(InvestmentEntity investment, InvestmentStats stats) =>
              InvestmentDetailStatsSection(
                stats: stats,
                investment: investment,
                isDark: isDark,
                currencyFormat: _inr,
                isPrivacyMode: false,
                now: _today,
              );
          return Column(
            children: [
              section(
                _investment(
                  'demo-7',
                  'Demo fixed deposit',
                  InvestmentType.fixedDeposit,
                  status: InvestmentStatus.closed,
                  maturity: DateTime(2025, 10, 1),
                ),
                _paidOut(1000000, 1114000, 0.114),
              ),
              const SizedBox(height: 24),
              section(
                _investment(
                  'demo-8',
                  'Demo stocks',
                  InvestmentType.stocks,
                  status: InvestmentStatus.closed,
                ),
                _paidOut(100000, 50000, -0.5258),
              ),
            ],
          );
        },
      ),
    ),
  ),
  // The goals strip on the Overview: the "achieved" count in a green chip.
  'goals_dashboard_card': _Scene(
    height: 300,
    overrides: [
      currencyLocaleProvider.overrideWith((ref) => 'en_IN'),
      multiCurrencyGoalsSummaryProvider.overrideWith(
        (ref) => Future.value(
          GoalsSummary(
            totalGoals: 2,
            achievedGoals: 1,
            onTrackGoals: 1,
            behindGoals: 0,
            averageProgress: 80,
            completedGoals: [_goalAchieved],
          ),
        ),
      ),
    ],
    build: () =>
        const Padding(padding: EdgeInsets.all(16), child: GoalsDashboardCard()),
  ),
  'cash_flow_rows': _Scene(
    height: 300,
    build: () => Padding(
      padding: const EdgeInsets.all(16),
      child: Builder(
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Column(
            children: [
              for (final flow in [
                _cashFlow('cf-1', CashFlowType.invest, 100000),
                _cashFlow('cf-2', CashFlowType.returnFlow, 114000),
              ])
                CashFlowCardWidget(
                  cashFlow: flow,
                  isDark: isDark,
                  currencyFormat: _inr,
                  onTap: () {},
                  onEdit: () {},
                  onConfirmDelete: () async => false,
                  onDeleted: () {},
                ),
            ],
          );
        },
      ),
    ),
  ),
};

// Demo goal and FIRE settings only.
final _goal = GoalEntity(
  id: 'demo-goal',
  name: 'Demo goal',
  type: GoalType.targetAmount,
  targetAmount: 1000000,
  trackingMode: GoalTrackingMode.all,
  // A letter, not an emoji: the harness has no emoji font.
  icon: 'G',
  colorValue: 0xFF3B82F6,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  currency: 'INR',
);

final _goalAchieved = GoalProgress(
  goal: _goal,
  currentAmount: 1000000,
  targetAmount: 1000000,
  progressPercent: 100,
  monthlyVelocity: 0,
  monthlyIncome: 0,
  status: GoalStatus.achieved,
  currentMilestone: GoalMilestone.complete,
  achievedMilestones: const [],
  linkedInvestmentCount: 1,
  calculatedAt: DateTime(2026, 10, 4),
);

final _fireSettings = FireSettingsEntity(
  id: 'fire',
  monthlyExpenses: 50000,
  birthYear: 1998,
  targetFireAge: 50,
  isSetupComplete: true,
  currency: 'INR',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

// 36.6 lakh saved with 60,000 added a month: ahead of schedule.
final _fireAhead = FireCalculationService().calculate(
  settings: _fireSettings,
  currentPortfolioValue: 3660000,
  currentMonthlySavings: 60000,
  asOf: DateTime(2026, 10, 2),
  inputs: const FireInputsSummary(
    investmentsValue: 3660000,
    principalWithoutValue: 0,
    otherAssets: 0,
    savingsSource: MonthlySavingsSource.history,
  ),
);

// 14 lakh saved and nothing added: behind schedule.
final _fireBehind = FireCalculationService().calculate(
  settings: _fireSettings,
  currentPortfolioValue: 1402551.73,
  currentMonthlySavings: 0,
  asOf: DateTime(2026, 10, 2),
  inputs: const FireInputsSummary(
    investmentsValue: 1402551.73,
    principalWithoutValue: 0,
    otherAssets: 0,
    savingsSource: MonthlySavingsSource.history,
  ),
);

const _sceneWidth = 400.0;
final _sceneKey = GlobalKey();

void main() {
  setUpAll(GoldenTestConfig.setup);

  for (final MapEntry(key: name, value: scene) in _scenes.entries) {
    for (final dark in [false, true]) {
      final theme = dark ? 'dark' : 'light';
      testWidgets('$name - $theme', (tester) async {
        // The bundled Plus Jakarta Sans files are unusable until #973 is
        // fixed, so the harness puts Roboto in their place, as it does for
        // the store screenshots. It also loads the icon font.
        await loadStoreScreenshotFonts(tester);
        await tester.setGoldenSize(Size(_sceneWidth, scene.height));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              privacyModeProvider.overrideWith(_PrivacyOff.new),
              currencyCodeProvider.overrideWith((ref) => 'INR'),
              currencySymbolProvider.overrideWith((ref) => '₹'),
              currencyFormatProvider.overrideWith((ref) => _inr),
              analyticsServiceProvider.overrideWithValue(
                FakeAnalyticsService(),
              ),
              ...scene.overrides,
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: RepaintBoundary(
                    key: _sceneKey,
                    child: Builder(
                      builder: (context) => ColoredBox(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        // A column gives the scene unbounded height, so it
                        // is as tall as its content.
                        child: SizedBox(
                          width: _sceneWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [scene.build()],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(_sceneKey),
          matchesGoldenFile('goldens/${name}_$theme.png'),
        );
      });
    }
  }
}
