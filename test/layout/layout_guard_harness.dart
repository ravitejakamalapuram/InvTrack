// Shared by edge_guard_360_test.dart and edge_guard_411_test.dart.
//
// Runs the real app on the store demo data at a phone width and a text scale
// and measures render boxes (never pixels) on the four main screens:
// Overview, Investments, Investment detail and Goals. Every one of them must
// start its content on AppSpacing.screenEdge and must let its last item be
// scrolled clear of the add button.
//
// A failed check is collected, not thrown, so one run lists every screen that
// is off. The message names the element and the measured value in dp.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/privacy_toggle_button.dart';
import 'package:inv_tracker/features/fire_number/presentation/widgets/fire_dashboard_card.dart';
import 'package:inv_tracker/features/goals/presentation/screens/goals_screen.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goal_card.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goal_carousel_card.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goals_dashboard_card.dart';
import 'package:inv_tracker/features/income_projection/presentation/widgets/expected_income_section.dart';
import 'package:inv_tracker/features/investment/presentation/screens/investment_detail_screen.dart';
import 'package:inv_tracker/features/investment/presentation/screens/investment_list_screen.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/cash_flow_card_widget.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/document_list_widget.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_card.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_detail_segment_control.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_list_filter_tabs.dart';
import 'package:inv_tracker/features/overview/presentation/screens/overview_screen.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/hero_card.dart';

import '../../integration_test/mocks/store_demo_data.dart';
import '../store_screenshots/store_screenshot_harness.dart';

const _pixelRatio = 2.625;

/// Phone height in dp for every run; only the width and the text scale vary.
const guardHeight = 780.0;

/// Text scales every width is checked at.
const guardTextScales = [1.0, 1.3, 2.0];

/// Edge and clearance checks may be off by this much (dp).
const guardTolerance = 0.5;

/// Files this change owns. An overflow whose report names one of them fails
/// the run; the others (card internals, add-investment screens) are printed
/// so they can be fixed on their own.
final _ownedFiles = RegExp(
  r'/(?:overview_screen|investment_list_screen|goals_screen|'
  r'investment_detail_screen|screen_layout|tonal_icon_action|'
  r'goals_dashboard_card|sample_data_banner)\.dart',
);

/// One `testWidgets` per text scale at [width] dp.
void defineEdgeGuardTests({required double width}) {
  for (final scale in guardTextScales) {
    testWidgets('main screens share one edge and a clear foot at '
        '${width.toInt()}dp, text x$scale', (tester) async {
      await runLayoutGuard(
        tester,
        width: width,
        textScale: scale,
        body: (guard) => _checkMainScreens(guard, withPrivacy: scale == 1.0),
      );
    });
  }
}

/// Runs [body] on the real app at [width] x [guardHeight] dp and [textScale],
/// then fails with every violation [body] collected.
Future<void> runLayoutGuard(
  WidgetTester tester, {
  required double width,
  required double textScale,
  required Future<void> Function(LayoutGuard guard) body,
}) async {
  // The test font makes every glyph a same-width square, which hides and
  // invents overflows at large text scales.
  final fonts = await loadStoreScreenshotFonts(tester);
  expect(
    fonts.testFontFamilies,
    isEmpty,
    reason: 'these families would render as solid test boxes',
  );

  final guard = LayoutGuard._(tester, width: width, textScale: textScale);
  final previousOnError = FlutterError.onError;
  FlutterError.onError = guard._record;
  try {
    await pumpStoreApp(tester, StoreDemoData.build(DateTime.now()));
    tester.view.physicalSize = Size(
      width * _pixelRatio,
      guardHeight * _pixelRatio,
    );
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    await guard.pumpFrames(6);
    await body(guard);
    guard._verify();
  } finally {
    FlutterError.onError = previousOnError;
    tester.platformDispatcher.clearAllTestValues();
    releaseStoreApp();
  }
}

/// Collects measurements and violations for one run.
class LayoutGuard {
  LayoutGuard._(this.tester, {required this.width, required this.textScale});

  final WidgetTester tester;
  final double width;
  final double textScale;

  final _violations = <String>[];
  final _ownedOverflows = <String>[];
  final _otherOverflows = <String>{};
  final _otherErrors = <String>[];

  double get edge => AppSpacing.screenEdge;

  Future<void> pumpFrames(int frames, [int ms = 150]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(Duration(milliseconds: ms));
    }
  }

  void _record(FlutterErrorDetails details) {
    final text = details.toString();
    if (text.contains('overflowed by')) {
      final summary = text
          .split('\n')
          .where(
            (l) =>
                l.contains('overflowed by') ||
                l.contains('error-causing widget') ||
                _ownedFiles.hasMatch(l) ||
                RegExp(r'lib/\S+\.dart').hasMatch(l),
          )
          .take(4)
          .map((l) => l.trim())
          .join(' | ');
      if (_ownedFiles.hasMatch(text)) {
        _ownedOverflows.add(summary);
      } else {
        _otherOverflows.add(summary);
      }
    } else {
      _otherErrors.add(details.exceptionAsString().split('\n').first);
    }
  }

  void _verify() {
    for (final other in _otherOverflows) {
      debugPrint('LAYOUT GUARD, overflow outside this change: $other');
    }
    final problems = [
      ..._violations,
      for (final o in _ownedOverflows)
        'overflow in a file this change owns: $o',
      for (final e in _otherErrors) 'error while laying out: $e',
    ];
    if (problems.isNotEmpty) {
      fail(
        '${problems.length} layout problem(s) at ${width.toInt()}dp, text '
        'x$textScale (screen edge is ${edge.toInt()}dp):\n'
        '${problems.map((p) => '  - $p').join('\n')}',
      );
    }
  }

  void fault(String message) => _violations.add(message);

  // -- Navigation and scrolling ------------------------------------------

  Future<void> goToTab(IconData icon) async {
    await tester.tap(
      find
          .descendant(
            of: find.byType(NavigationBar),
            matching: find.byIcon(icon),
          )
          .first,
    );
    await pumpFrames(8);
  }

  Finder _scrollable(Finder screen) => find
      .descendant(
        of: find.descendant(
          of: screen,
          matching: find.byType(CustomScrollView),
        ),
        matching: find.byType(Scrollable),
      )
      .first;

  ScrollPosition _position(Finder screen) =>
      tester.state<ScrollableState>(_scrollable(screen)).position;

  /// The viewport of the screen's main scroll view.
  Rect bodyRect(Finder screen) => tester.getRect(_scrollable(screen));

  Future<void> scrollToStart(Finder screen) async {
    _position(screen).jumpTo(0);
    await pumpFrames(2, 120);
  }

  /// Items are built lazily, so the end moves while they are laid out. The
  /// list entries slide in over about 650ms, so wait that long before
  /// measuring.
  Future<void> scrollToEnd(Finder screen) async {
    for (var i = 0; i < 6; i++) {
      final position = _position(screen);
      final before = position.maxScrollExtent;
      position.jumpTo(before);
      await pumpFrames(2, 120);
      if (_position(screen).maxScrollExtent == before) break;
    }
    await pumpFrames(6, 150);
  }

  /// Scrolls forward until [target] is built, then brings it on screen.
  Future<void> reveal(Finder target, Finder screen) async {
    for (var i = 0; i < 80 && target.evaluate().isEmpty; i++) {
      final position = _position(screen);
      if (position.pixels >= position.maxScrollExtent) break;
      position.jumpTo(
        (position.pixels + 200).clamp(0.0, position.maxScrollExtent),
      );
      await pumpFrames(1, 100);
    }
    if (target.evaluate().isNotEmpty) await tester.ensureVisible(target.first);
    await pumpFrames(2, 120);
  }

  // -- Measurements ------------------------------------------------------

  String _dp(double v) => v.toStringAsFixed(1);

  Rect? _rect(String what, Finder finder, {bool last = false}) {
    final count = finder.evaluate().length;
    if (count == 0) {
      fault('$what: not found, so its edge could not be measured');
      return null;
    }
    return tester.getRect(last ? finder.at(count - 1) : finder.first);
  }

  /// [finder] starts on the screen edge.
  void expectStart(String what, Finder finder) {
    final rect = _rect(what, finder);
    if (rect != null) expectStartAt(what, rect.left);
  }

  void expectStartAt(String what, double left) {
    if ((left - edge).abs() > guardTolerance) {
      fault('$what starts at ${_dp(left)}dp, want ${_dp(edge)}dp');
    }
  }

  /// [finder] ends on the screen edge.
  void expectEnd(String what, Finder finder) {
    final rect = _rect(what, finder);
    if (rect != null) expectEndAt(what, rect.right);
  }

  void expectEndAt(String what, double right) {
    final want = width - edge;
    if ((right - want).abs() > guardTolerance) {
      fault('$what ends at ${_dp(right)}dp, want ${_dp(want)}dp');
    }
  }

  /// The visible chip of the app bar action with [tooltip] and the tap box
  /// around it.
  ({Rect? chip, Rect? box}) action(String tooltip, Finder within) {
    final tip = find.descendant(of: within, matching: find.byTooltip(tooltip));
    if (tip.evaluate().isEmpty) {
      fault('app bar action "$tooltip": not found');
      return (chip: null, box: null);
    }
    final box = find.ancestor(of: tip.first, matching: find.byType(IconButton));
    final chip = find.descendant(
      of: tip.first,
      matching: find.byWidgetPredicate(
        (w) => w is Container && w.decoration is BoxDecoration,
      ),
    );
    if (chip.evaluate().isEmpty) {
      fault('app bar action "$tooltip": has no visible chip, only a bare icon');
    }
    return (
      box: box.evaluate().isEmpty ? null : tester.getRect(box.first),
      chip: chip.evaluate().isEmpty ? null : tester.getRect(chip.first),
    );
  }

  /// The tap box of an action is at least 48 x 48.
  void expectTapBox(String what, Rect? box) {
    if (box == null) {
      fault('$what: has no button box');
    } else if (box.width < 47.5 || box.height < 47.5) {
      fault(
        '$what tap box is ${_dp(box.width)} x ${_dp(box.height)}dp, '
        'want at least 48 x 48',
      );
    }
  }

  /// The FAB, or null when the screen shows none.
  Rect? get fab {
    final f = find.byType(FloatingActionButton);
    return f.evaluate().isEmpty ? null : tester.getRect(f.first);
  }

  /// After scrolling to the end, [last] must clear the FAB, and the body must
  /// leave at least AppSpacing.fabBottomPadding below it.
  void expectClearOfFab(String what, Finder last, Finder screen) {
    final count = last.evaluate().length;
    final button = fab;
    if (count == 0) {
      fault('$what: last item not found');
      return;
    }
    if (button == null) {
      fault('$what: no floating action button to clear');
      return;
    }
    var bottom = double.negativeInfinity;
    for (var i = 0; i < count; i++) {
      final b = tester.getRect(last.at(i)).bottom;
      if (b > bottom) bottom = b;
    }
    final gap = button.top - bottom;
    if (gap < 0) {
      fault(
        '$what: the last item ends ${_dp(bottom)}dp, ${_dp(-gap)}dp under the '
        'add button (button top ${_dp(button.top)}dp)',
      );
    }
    final below = bodyRect(screen).bottom - bottom;
    if (below < AppSpacing.fabBottomPadding - guardTolerance) {
      fault(
        '$what: only ${_dp(below)}dp of scroll body under the last item, '
        'want at least ${_dp(AppSpacing.fabBottomPadding)}dp',
      );
    }
  }

  /// Left edge of the leftmost [finder] match that is on screen, once the
  /// carousel has stopped moving.
  Future<double?> settledActiveLeft(Finder finder) async {
    double? read() {
      double? best;
      for (var i = 0; i < finder.evaluate().length; i++) {
        final left = tester.getTopLeft(finder.at(i)).dx;
        if (left >= 0 && (best == null || left < best)) best = left;
      }
      return best;
    }

    var previous = read();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final now = read();
      if (now == previous) return now;
      previous = now;
    }
    return previous;
  }
}

Future<void> _checkMainScreens(
  LayoutGuard g, {
  required bool withPrivacy,
}) async {
  await _checkOverview(g, withPrivacy: withPrivacy);
  await _checkGoals(g);
  await _checkInvestmentsAndDetail(g);
}

// -- Overview ------------------------------------------------------------

Future<void> _checkOverviewEdges(LayoutGuard g, String label) async {
  final screen = find.byType(OverviewScreen);
  await g.scrollToStart(screen);
  g.expectStart(
    '$label app bar title',
    find.descendant(of: screen, matching: find.text('InvTrack')),
  );
  g.expectStart('$label hero card', find.byType(HeroCardWithToggle));
  g.expectEnd('$label hero card', find.byType(HeroCardWithToggle));

  final goals = find.byType(GoalsDashboardCard);
  await g.reveal(goals, screen);
  g.expectStart(
    '$label "Goals" heading',
    find.descendant(of: goals, matching: find.text('Goals')),
  );
  final cardLeft = await g.settledActiveLeft(find.byType(GoalCarouselCard));
  if (cardLeft == null) {
    g.fault('$label active goal card: not found');
  } else {
    g.expectStartAt('$label active goal card', cardLeft);
  }

  await g.reveal(find.byType(FireDashboardCard), screen);
  g.expectStart('$label FIRE card', find.byType(FireDashboardCard));
}

Future<void> _checkOverview(LayoutGuard g, {required bool withPrivacy}) async {
  final screen = find.byType(OverviewScreen);
  await _checkOverviewEdges(g, 'Overview');

  if (withPrivacy) {
    // Masking amounts must not move any edge.
    await g.scrollToStart(screen);
    await g.tester.tap(find.byType(PrivacyToggleButton).first);
    await g.pumpFrames(6);
    await _checkOverviewEdges(g, 'Overview (privacy mode)');
    await g.scrollToStart(screen);
    await g.tester.tap(find.byType(PrivacyToggleButton).first);
    await g.pumpFrames(6);
  }

  await g.scrollToEnd(screen);
  g.expectClearOfFab(
    'Overview',
    find.ancestor(
      of: find.text('Investment Period'),
      matching: find.byType(GlassCard),
    ),
    screen,
  );
}

// -- Goals ---------------------------------------------------------------

Future<void> _checkGoals(LayoutGuard g) async {
  await g.goToTab(Icons.flag_outlined);
  final screen = find.byType(GoalsScreen);
  await g.scrollToStart(screen);

  g.expectStart(
    'Goals app bar title',
    find.descendant(of: screen, matching: find.text('Goals')),
  );
  g.expectStart(
    'Goals first filter tab',
    find.ancestor(
      of: find.descendant(of: screen, matching: find.text('Active')),
      matching: find.byType(GestureDetector),
    ),
  );
  g.expectStart('Goals first card', find.byType(GoalCard));

  final add = g.action('Add Goal', screen);
  g.expectTapBox('Goals add action', add.box);
  if (add.chip != null) g.expectEndAt('Goals add action chip', add.chip!.right);

  await g.scrollToEnd(screen);
  g.expectClearOfFab('Goals', find.byType(GoalCard), screen);
}

// -- Investments and Investment detail -----------------------------------

Future<void> _checkInvestmentsAndDetail(LayoutGuard g) async {
  await g.goToTab(Icons.account_balance_wallet_outlined);
  final list = find.byType(InvestmentListScreen);
  await g.scrollToStart(list);

  g.expectStart(
    'Investments app bar title',
    find.descendant(of: list, matching: find.text('Investments')),
  );
  g.expectStart(
    'Investments filter tabs',
    find.byType(InvestmentListFilterTabs),
  );
  g.expectStart('Investments first card', find.byType(InvestmentCard));
  final search = g.action('Search investments', list);
  g.expectTapBox('Investments search action', search.box);
  if (search.chip != null) {
    g.expectEndAt('Investments last action chip', search.chip!.right);
  }

  await g.scrollToEnd(list);
  g.expectClearOfFab('Investments', find.byType(InvestmentCard), list);

  await _checkClosedDetail(g, list);
  await _checkOpenDetail(g, list);
}

Future<void> _openDetail(LayoutGuard g, Finder list, String name) async {
  await g.scrollToStart(list);
  await g.reveal(find.text(name), list);
  await g.tester.tap(find.text(name).first);
  await g.pumpFrames(8, 200);
}

Future<void> _backFromDetail(LayoutGuard g) async {
  await g.tester.tap(find.byTooltip('Back'));
  await g.pumpFrames(8, 200);
}

Future<void> _checkClosedDetail(LayoutGuard g, Finder list) async {
  await _openDetail(g, list, StoreDemoData.detailInvestmentName);
  final screen = find.byType(InvestmentDetailScreen);
  await g.scrollToStart(screen);

  final back = g.action('Back', screen);
  g.expectTapBox('Detail back action', back.box);
  if (back.chip != null) g.expectStartAt('Detail back chip', back.chip!.left);
  final more = g.action('More options', screen);
  g.expectTapBox('Detail more action', more.box);
  if (more.chip != null) g.expectEndAt('Detail more chip', more.chip!.right);

  g.expectStart(
    'Detail header icon tile',
    find.descendant(
      of: screen,
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.constraints ==
                const BoxConstraints.tightFor(width: 48, height: 48),
      ),
    ),
  );
  g.expectStart(
    'Detail notes box',
    find.descendant(
      of: screen,
      matching: find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.label ?? '').startsWith('Notes'),
      ),
    ),
  );
  g.expectStart(
    'Detail stats card',
    find.descendant(of: screen, matching: find.byType(GlassCard)),
  );
  await g.reveal(find.byType(InvestmentDetailSegmentControl), screen);
  g.expectStart(
    'Detail segment control',
    find.byType(InvestmentDetailSegmentControl),
  );
  await g.reveal(find.byType(CashFlowCardWidget), screen);
  g.expectStart('Detail first cash flow card', find.byType(CashFlowCardWidget));

  await _backFromDetail(g);
}

Future<void> _checkOpenDetail(LayoutGuard g, Finder list) async {
  await _openDetail(g, list, 'Bajaj Finance FD');
  final screen = find.byType(InvestmentDetailScreen);

  await g.scrollToEnd(screen);
  g.expectClearOfFab(
    'Detail (activity)',
    find.byType(CashFlowCardWidget),
    screen,
  );

  // The other two segments use the same edge and the same foot.
  for (final segment in const ['Upcoming', 'Docs']) {
    await g.scrollToStart(screen);
    final tab = find.descendant(
      of: find.byType(InvestmentDetailSegmentControl),
      matching: find.text(segment),
    );
    if (tab.evaluate().isEmpty) continue; // hidden with Income Guardian
    await g.reveal(tab, screen);
    await g.tester.tap(tab.first, warnIfMissed: false);
    await g.pumpFrames(6);
    final content = segment == 'Docs'
        ? find.byType(DocumentListWidget)
        : find.byType(ExpectedIncomeSection);
    await g.reveal(content, screen);
    g.expectStart('Detail $segment content', content);
    await g.scrollToEnd(screen);
    if (segment == 'Docs') {
      g.expectClearOfFab('Detail (docs)', content, screen);
    }
  }

  await _backFromDetail(g);
}
