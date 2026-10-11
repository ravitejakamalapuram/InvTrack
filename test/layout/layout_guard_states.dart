// The states of the main screens that the store demo data never shows, run
// through the same measurements as layout_guard_harness.dart: a new account,
// a failed load, only archived investments, a deletion request, no goals,
// the archived goals tab, and the Investments search and type filter.
//
// A body, a banner or a header that adds its own margin in one of these
// states would sit off the screen edge; the demo data alone would not show it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/features/goals/presentation/screens/goals_screen.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goal_card.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goals_empty_state.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_list_state_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/multi_currency_providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/investment_list_screen.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_card.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_list_filter_tabs.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_list_search_field.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_list_states.dart';
import 'package:inv_tracker/features/overview/presentation/screens/overview_screen.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/hero_card.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/overview_all_archived_card.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/overview_empty_state.dart';
import 'package:inv_tracker/features/settings/data/services/deletion_request_service.dart';
import 'package:inv_tracker/features/settings/presentation/providers/deletion_request_status_provider.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/deletion_request_banner.dart';

import '../../integration_test/mocks/store_demo_data.dart';
import 'layout_guard_harness.dart';

/// Text scales the states are checked at: normal and the largest.
const _stateTextScales = [1.0, 2.0];

StoreDemoData _noPortfolio(DateTime now) {
  final full = StoreDemoData.build(now);
  return StoreDemoData(
    investments: const [],
    cashFlows: const [],
    goals: const [],
    fireSettings: full.fireSettings,
  );
}

StoreDemoData _noGoals(DateTime now) {
  final full = StoreDemoData.build(now);
  return StoreDemoData(
    investments: full.investments,
    cashFlows: full.cashFlows,
    goals: const [],
    fireSettings: full.fireSettings,
  );
}

/// One `testWidgets` per state and text scale at [width] dp.
void defineStateGuardTests({required double width}) {
  void state(
    String name,
    Future<void> Function(LayoutGuard guard) body, {
    StoreDemoData Function(DateTime now)? demo,
    List<Override> overrides = const [],
  }) {
    for (final scale in _stateTextScales) {
      testWidgets('$name at ${width.toInt()}dp, text x$scale', (tester) async {
        await runLayoutGuard(
          tester,
          width: width,
          textScale: scale,
          demo: demo,
          overrides: overrides,
          body: body,
        );
      });
    }
  }

  state(
    'Overview of a new account keeps the edge and clears the add button',
    _checkOverviewNewAccount,
    demo: _noPortfolio,
    overrides: [
      hasNoInvestmentsProvider.overrideWith((ref) => Stream.value(true)),
    ],
  );

  state(
    'Overview with only archived investments keeps the edge',
    _checkOverviewAllArchived,
    demo: _noPortfolio,
    overrides: [
      archivedInvestmentsProvider.overrideWith(
        (ref) => Stream.value([
          StoreDemoData.build(DateTime.now()).investments.first,
        ]),
      ),
    ],
  );

  state(
    'Overview that failed to load keeps the edge',
    _checkOverviewLoadError,
    overrides: [
      multiCurrencyGlobalStatsProvider.overrideWith(
        (ref) async => throw StateError('forced load failure'),
      ),
    ],
  );

  state(
    'Overview with a deletion request keeps the edge',
    _checkOverviewDeletionBanner,
    overrides: [
      deletionRequestStatusProvider.overrideWith(
        (ref) => Stream.value(DeletionRequestStatus.pending),
      ),
    ],
  );

  state('Goals with no goals keeps the edge', _checkGoalsEmpty, demo: _noGoals);
  state('Goals archived tab keeps the edge', _checkGoalsArchivedTab);
  state('Investments in search mode keep the edge', _checkInvestmentsSearch);
  state(
    'Investments with a type filter keep the edge and clear the add button',
    _checkInvestmentsTypeFilter,
  );
}

// -- Overview --------------------------------------------------------------

Future<void> _checkOverviewHeader(LayoutGuard g, String label) async {
  final screen = find.byType(OverviewScreen);
  await g.scrollToStart(screen);
  g.expectStart(
    '$label app bar title',
    find.descendant(of: screen, matching: find.text('InvTrack')),
  );
}

Future<void> _checkOverviewNewAccount(LayoutGuard g) async {
  const label = 'New-account Overview';
  final screen = find.byType(OverviewScreen);
  final empty = find.byType(OverviewEmptyState);
  await _checkOverviewHeader(g, label);
  g.expectStart('$label hero card', find.byType(HeroCardWithToggle));
  g.expectEnd('$label hero card', find.byType(HeroCardWithToggle));

  await g.reveal(empty, screen);
  g.expectFound('$label empty state', empty);
  g.expectSpan('$label empty state', empty);
  final firstCard = find.descendant(
    of: empty,
    matching: find.byType(GlassCard),
  );
  g.expectStart('$label first card', firstCard);
  g.expectEnd('$label first card', firstCard);

  await g.scrollToEnd(screen);
  g.expectClearOfFab('Overview (new account)', empty, screen);
}

Future<void> _checkOverviewAllArchived(LayoutGuard g) async {
  const label = 'All-archived Overview';
  final screen = find.byType(OverviewScreen);
  final card = find.byType(OverviewAllArchivedCard);
  await _checkOverviewHeader(g, label);
  g.expectStart('$label hero card', find.byType(HeroCardWithToggle));
  g.expectEnd('$label hero card', find.byType(HeroCardWithToggle));

  await g.reveal(card, screen);
  g.expectFound('$label archived card', card);
  g.expectSpan('$label archived card', card);

  await g.scrollToEnd(screen);
  g.expectClearOfFab('Overview (all archived)', card, screen);
}

Future<void> _checkOverviewLoadError(LayoutGuard g) async {
  const label = 'Failed-load Overview';
  final screen = find.byType(OverviewScreen);
  final error = find.byType(OverviewLoadErrorState);
  await _checkOverviewHeader(g, label);
  await g.reveal(error, screen);
  g.expectFound('$label error state', error);
  g.expectSpan('$label error state', error);

  await g.scrollToEnd(screen);
  g.expectClearOfFab('Overview (load error)', error, screen);
}

Future<void> _checkOverviewDeletionBanner(LayoutGuard g) async {
  const label = 'Overview with a deletion request';
  final screen = find.byType(OverviewScreen);
  final banner = find.byType(DeletionRequestBanner);
  await _checkOverviewHeader(g, label);
  // The banner shows nothing until the request arrives, so look for its icon.
  g.expectFound(
    '$label banner',
    find.descendant(of: banner, matching: find.byIcon(Icons.warning_amber)),
  );
  g.expectStart('$label banner', banner);
  g.expectEnd('$label banner', banner);
  await g.reveal(find.byType(HeroCardWithToggle), screen);
  g.expectStart('$label hero card', find.byType(HeroCardWithToggle));
  g.expectEnd('$label hero card', find.byType(HeroCardWithToggle));
}

// -- Goals -----------------------------------------------------------------

Future<void> _checkGoalsEmpty(LayoutGuard g) async {
  await g.goToTab(Icons.flag_outlined);
  await checkGoalsHeader(g, 'Goals (no goals)');
  g.expectFound('Goals (no goals) empty state', find.byType(GoalsEmptyState));
  g.expectAbsent('Goals (no goals) cards', find.byType(GoalCard));
}

Future<void> _checkGoalsArchivedTab(LayoutGuard g) async {
  await g.goToTab(Icons.flag_outlined);
  final screen = find.byType(GoalsScreen);
  await g.tester.tap(
    find
        .descendant(of: screen, matching: find.textContaining('Archived'))
        .first,
  );
  await g.pumpFrames(6);
  await checkGoalsHeader(g, 'Goals (archived tab)');
  g.expectAbsent('Goals (archived tab) cards', find.byType(GoalCard));
}

// -- Investments -----------------------------------------------------------

Future<void> _checkInvestmentsSearch(LayoutGuard g) async {
  await g.goToTab(Icons.account_balance_wallet_outlined);
  final list = find.byType(InvestmentListScreen);
  final field = find.byType(InvestmentListSearchField);
  await g.scrollToStart(list);
  await g.tester.tap(find.byTooltip('Search investments'));
  await g.pumpFrames(6);

  g.expectFound('Search mode field', field);
  g.expectStart('Search mode field', field);
  g.expectEnd('Search mode field', field);
  g.expectStart(
    'Search mode filter tabs',
    find.byType(InvestmentListFilterTabs),
  );
  g.expectStart('Search mode first card', find.byType(InvestmentCard));

  await g.tester.enterText(
    find.descendant(of: field, matching: find.byType(TextField)),
    'zzz no such investment',
  );
  await g.pumpFrames(10);
  g.expectFound(
    'Search mode no-results state',
    find.byType(InvestmentNoResultsState),
  );
  g.expectAbsent('Search mode no-results cards', find.byType(InvestmentCard));
  g.expectStart('Search mode field (no results)', field);
  g.expectEnd('Search mode field (no results)', field);
}

Future<void> _checkInvestmentsTypeFilter(LayoutGuard g) async {
  await g.goToTab(Icons.account_balance_wallet_outlined);
  final list = find.byType(InvestmentListScreen);
  ProviderScope.containerOf(g.tester.element(list))
      .read(investmentListStateProvider.notifier)
      .setTypeFilter(InvestmentType.fixedDeposit);
  await g.pumpFrames(8);
  await g.scrollToStart(list);

  g.expectStart(
    'Filtered Investments filter tabs',
    find.byType(InvestmentListFilterTabs),
  );
  g.expectStart('Filtered Investments first card', find.byType(InvestmentCard));
  await g.scrollToEnd(list);
  g.expectClearOfFab(
    'Investments (type filter)',
    find.byType(InvestmentCard),
    list,
  );
}
