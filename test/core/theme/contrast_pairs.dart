/// Every foreground and ground the colour audit judged (see design/system
/// README "Contrast"), read from the real `AppColors`, `AppTheme` and
/// `InvestmentType` values so a change to a colour changes its ratio here.
///
/// A [PairKind.token] pair is measured. A [PairKind.widget] pair is a colour
/// a widget hard-codes (the hero card, glass border, snackbar icons ...):
/// nothing here can read it, so it carries the audited ratio and the PR that
/// fixes it adds a widget test that pumps the widget and names that test in
/// [ContrastPair.widgetTest]. A control pair passes today and must keep
/// passing.
///
/// Two pairs the audit judged are not here: dark `danger` and `success` on the
/// pale `danger-bg` and `success-bg`. `ChangeBadge` is the only widget that
/// paints those fills, it has no caller, and it paints the light colour on
/// them, so a dark colour on a pale fill never occurs. The real pairs are
/// `danger-light@danger-bg` and `success-light@success-bg`.
///
/// The measured ratios equal the audit's to 0.01, except the light 10% tints
/// of mutual funds and P2P lending (3.29 measured, 3.27 audited): the audit
/// rounded the exact half channel 242.5 down, [composeOver] rounds it up.
library;

import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_theme.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/presentation/ui_extensions/investment_ui.dart';

import '../../helpers/contrast.dart';

enum PairKind { token, widget }

class ContrastPair {
  /// A measured pair that fails today. [audit] is the ratio the audit
  /// printed, the floor it may not drop below while it is allowlisted.
  ContrastPair.token(
    this.id, {
    required this.rows,
    required Color this.fg,
    required Color this.ground,
    required double this.audit,
    this.min = kMinText,
    this.tier = 'P1',
    this.addedByPlan = false,
  }) : kind = PairKind.token,
       widgetTest = null;

  /// A pair that passes today; no audit ratio.
  ContrastPair.control(
    this.id, {
    required Color this.fg,
    required Color this.ground,
    this.min = kMinText,
  }) : kind = PairKind.token,
       rows = const [],
       audit = null,
       tier = 'control',
       addedByPlan = false,
       widgetTest = null;

  /// A hard-coded pair measured by a widget test. Once it leaves the
  /// allowlist, [widgetTest] must name that test file.
  ContrastPair.widget(
    this.id, {
    required this.rows,
    required double this.audit,
    this.min = kMinText,
    this.tier = 'P1',
    this.widgetTest,
    this.addedByPlan = false,
  }) : kind = PairKind.widget,
       fg = null,
       ground = null;

  final String id;

  /// Indexes into the audit's corrected proposal (0 to 76). Empty for a
  /// control and for a pair the audit had no row for.
  final List<int> rows;
  final PairKind kind;
  final Color? fg;
  final Color? ground;
  final double? audit;
  final double min;

  /// P1 text, P2 outlines, P3 edges and dividers, or control.
  final String tier;

  /// True for a pair the audit had no row for: the three light dividers the
  /// plan added, and the four the PR 1 review added. [audit] is then the ratio
  /// measured with this table.
  final bool addedByPlan;

  /// Repo-relative path of the widget test, for a widget pair that is fixed.
  final String? widgetTest;

  double get ratio => contrastRatio(fg!, ground!);
}

// The test that pumps the investment card in dark and measures its text.
const _cardTest =
    'test/features/investment/presentation/widgets/investment_card_theme_contrast_test.dart';

// The test that pumps the zero-change ChangeBadge and measures its text.
const _zeroBadgeTest = 'test/core/widgets/change_badge_zero_contrast_test.dart';

// PR 5: the tests that pump a green or red label on its tint, or a fill.
const _fireCardTest =
    'test/features/fire_number/presentation/widgets/fire_dashboard_card_theme_contrast_test.dart';
const _goalCardsTest =
    'test/features/goals/presentation/widgets/goal_cards_theme_contrast_test.dart';
const _cashFlowRowTest =
    'test/features/investment/presentation/widgets/cash_flow_card_theme_contrast_test.dart';
const _detailStatsTest =
    'test/features/investment/presentation/widgets/investment_detail_stats_theme_contrast_test.dart';
const _breakdownTest =
    'test/features/overview/presentation/screens/overview_breakdown_theme_contrast_test.dart';
const _overviewColoursTest =
    'test/features/overview/presentation/widgets/overview_theme_colours_test.dart';
const _copiedSnackbarTest =
    'test/core/widgets/compact_amount_text_theme_contrast_test.dart';
const _changeBadgeStatusTest =
    'test/core/widgets/change_badge_status_contrast_test.dart';
const _feedbackTest = 'test/core/utils/app_feedback_theme_contrast_test.dart';

// Grounds the audit used. Dark input fill is the theme's, `neutral800Dark`.
const _bgL = AppColors.backgroundLight;
const _cardL = AppColors.cardLight;
const _surfaceL = AppColors.surfaceLight; // also the light input fill
const _bgD = AppColors.backgroundDark;
const _cardD = AppColors.cardDark;
const _inputD = AppColors.neutral800Dark;

Color _tint(Color c, double alpha, Color over) =>
    composeOver(c.withValues(alpha: alpha), over);

// Label on a type fill (white today): id, type, audit row, audit ratio.
final _typeFills = <(String, InvestmentType, int, double)>[
  ('angel-investing', InvestmentType.angelInvesting, 21, 2.43),
  ('bonds', InvestmentType.bonds, 23, 2.15),
  ('chit-funds', InvestmentType.chitFunds, 25, 2.80),
  ('crypto', InvestmentType.crypto, 27, 4.23),
  ('financing', InvestmentType.financing, 30, 2.49),
  ('fixed-deposit', InvestmentType.fixedDeposit, 32, 2.54),
  ('gold', InvestmentType.gold, 34, 1.40),
  ('invoice-discounting', InvestmentType.invoiceDiscounting, 36, 2.77),
  ('mutual-funds', InvestmentType.mutualFunds, 38, 3.68),
  ('p2p-lending', InvestmentType.p2pLending, 43, 3.68),
  ('private-equity', InvestmentType.privateEquity, 46, 4.23),
  ('real-estate', InvestmentType.realEstate, 49, 3.53),
  ('stocks', InvestmentType.stocks, 51, 2.54),
];

// Type name on its own 10% tint over the card: id, type, dark, row, ratio.
final _typeTints = <(String, InvestmentType, bool, int, double)>[
  ('angel-investing', InvestmentType.angelInvesting, false, 22, 2.22),
  ('bonds', InvestmentType.bonds, false, 24, 1.99),
  ('chit-funds', InvestmentType.chitFunds, false, 26, 2.53),
  ('crypto', InvestmentType.crypto, true, 28, 3.83),
  ('crypto', InvestmentType.crypto, false, 29, 3.75),
  ('financing', InvestmentType.financing, false, 31, 2.27),
  ('fixed-deposit', InvestmentType.fixedDeposit, false, 33, 2.31),
  ('gold', InvestmentType.gold, false, 35, 1.35),
  ('invoice-discounting', InvestmentType.invoiceDiscounting, false, 37, 2.51),
  ('mutual-funds', InvestmentType.mutualFunds, true, 39, 4.35),
  ('mutual-funds', InvestmentType.mutualFunds, false, 40, 3.27),
  ('other', InvestmentType.other, true, 41, 3.37),
  ('other', InvestmentType.other, false, 42, 4.27),
  ('p2p-lending', InvestmentType.p2pLending, true, 44, 4.35),
  ('p2p-lending', InvestmentType.p2pLending, false, 45, 3.27),
  ('private-equity', InvestmentType.privateEquity, true, 47, 3.83),
  ('private-equity', InvestmentType.privateEquity, false, 48, 3.75),
  ('real-estate', InvestmentType.realEstate, false, 50, 3.13),
  ('stocks', InvestmentType.stocks, false, 52, 2.31),
];

String _typeId(InvestmentType type) => type.name.replaceAllMapped(
  RegExp('[A-Z]'),
  (m) => '-${m[0]!.toLowerCase()}',
);

// Ids of the type pairs the audit found failing; the rest are controls.
final _failingTypeIds = <String>{
  for (final (id, _, _, _) in _typeFills) 'inv-$id-label@fill',
  for (final (id, _, isDark, _, _) in _typeTints)
    'inv-$id-${isDark ? 'dark' : 'light'}@tint10',
};

/// Built on first use. It reads `AppTheme`, so a test binding must exist.
final List<ContrastPair> kContrastPairs = _build();

List<ContrastPair> _build() {
  final light = AppTheme.lightTheme.colorScheme;
  final dark = AppTheme.darkTheme.colorScheme;
  const graphic = kMinGraphic;
  const white = Colors.white;

  return [
    // ---- P1 text on the token grounds ----
    ContrastPair.token(
      'accent-light@card',
      rows: [0],
      fg: AppColors.accentLight,
      ground: _cardL,
      audit: 2.77,
    ),
    ContrastPair.token(
      'accent-light@tint15',
      rows: [0],
      fg: AppColors.accentLight,
      ground: _tint(AppColors.accentLight, 0.15, _cardL),
      audit: 2.39,
    ),
    ContrastPair.token(
      'danger-light@danger-bg',
      rows: [2],
      fg: AppColors.dangerLight,
      ground: AppColors.dangerBgLight,
      audit: 3.08,
    ),
    ContrastPair.token(
      'danger-light@card',
      rows: [2],
      fg: AppColors.dangerLight,
      ground: _cardL,
      audit: 3.76,
    ),
    ContrastPair.token(
      'graph-cyan-light@card',
      rows: [3],
      fg: AppColors.graphCyan,
      ground: _cardL,
      audit: 2.43,
    ),
    ContrastPair.token(
      'graph-emerald-light@card',
      rows: [4],
      fg: AppColors.graphEmerald,
      ground: _cardL,
      audit: 2.54,
    ),
    ContrastPair.token(
      'graph-purple-light@card',
      rows: [5],
      fg: AppColors.graphPurple,
      ground: _cardL,
      audit: 3.96,
    ),
    ContrastPair.token(
      'neutral400-light@card',
      rows: [6, 15],
      fg: AppColors.neutral400Light,
      ground: _cardL,
      audit: 2.52,
    ),
    ContrastPair.token(
      'neutral400-light@surface',
      rows: [6, 15],
      fg: AppColors.neutral400Light,
      ground: _surfaceL,
      audit: 2.31,
    ),
    ContrastPair.token(
      'neutral500-dark@background',
      rows: [7, 14],
      fg: AppColors.neutral500Dark,
      ground: _bgD,
      audit: 4.13,
    ),
    ContrastPair.token(
      'neutral500-dark@card',
      rows: [7, 14],
      fg: AppColors.neutral500Dark,
      ground: _cardD,
      audit: 3.74,
    ),
    ContrastPair.token(
      'neutral500-dark@input-fill',
      rows: [7, 14],
      fg: AppColors.neutral500Dark,
      ground: _inputD,
      audit: 3.65,
    ),
    ContrastPair.token(
      'on-error-dark',
      rows: [8],
      fg: dark.onError,
      ground: dark.error,
      audit: 2.77,
    ),
    ContrastPair.token(
      'on-error-light',
      rows: [9],
      fg: light.onError,
      ground: light.error,
      audit: 3.76,
    ),
    ContrastPair.token(
      'success-light@success-bg',
      rows: [11],
      fg: AppColors.successLight,
      ground: AppColors.successBgLight,
      audit: 2.24,
    ),
    ContrastPair.token(
      'success-light@card',
      rows: [11],
      fg: AppColors.successLight,
      ground: _cardL,
      audit: 2.54,
    ),
    ContrastPair.token(
      'success-light@tint15',
      rows: [11],
      fg: AppColors.successLight,
      ground: _tint(AppColors.successTintLight, 0.15, _cardL),
      audit: 2.21,
    ),
    ContrastPair.token(
      'neutral500-light@surface',
      rows: [12, 13],
      fg: AppColors.neutral500Light,
      ground: _surfaceL,
      audit: 4.40,
    ),
    ContrastPair.token(
      'warning-light@card',
      rows: [16],
      fg: AppColors.warningLight,
      ground: _cardL,
      audit: 2.15,
    ),
    ContrastPair.token(
      'warning-light@tint15',
      rows: [16],
      fg: AppColors.warningLight,
      ground: _tint(AppColors.warningLight, 0.15, _cardL),
      audit: 1.91,
    ),
    // ChangeBadge text for a zero change, on its fill. The widget picks both
    // colours itself, so a pair that repeated them here could pass while the
    // badge painted something else: a test pumps the badge and measures it.
    ContrastPair.widget(
      'zero-badge-text-light@fill',
      rows: [62],
      audit: 3.82,
      widgetTest: _zeroBadgeTest,
    ),
    ContrastPair.token(
      'on-primary-container-light',
      rows: [56],
      fg: light.onPrimaryContainer,
      ground: light.primaryContainer,
      audit: 3.33,
    ),

    // ---- P1 text the audit had no row for, found in the PR 1 review ----
    // The investment card's XIRR pill paints graphEmerald or errorLight on a
    // 10% tint (investment_card.dart, `xirrColor`). The green is tinted with
    // itself; the red with `dangerTintLight`, the brighter red that
    // `errorLight` had before it was deepened. Dark has the pair below.
    ContrastPair.token(
      'graph-emerald-light@tint10',
      rows: [],
      fg: AppColors.graphEmerald,
      ground: _tint(AppColors.graphEmerald, 0.1, _cardL),
      audit: 2.31,
      addedByPlan: true,
    ),
    ContrastPair.token(
      'error-light@tint10',
      rows: [],
      fg: AppColors.errorLight,
      ground: _tint(AppColors.dangerTintLight, 0.1, _cardL),
      audit: 3.29,
      addedByPlan: true,
    ),
    // Measured on the pumped card since PR 2: the card paints errorDark in dark.
    ContrastPair.widget(
      'error-light-in-dark@tint10',
      rows: [],
      audit: 4.31,
      addedByPlan: true,
      widgetTest: _cardTest,
    ),
    // Danger text on its 15% tint (goal and FIRE status chips, plan PR 5).
    ContrastPair.token(
      'danger-light@tint15',
      rows: [],
      fg: AppColors.dangerLight,
      ground: _tint(AppColors.dangerTintLight, 0.15, _cardL),
      audit: 3.10,
      addedByPlan: true,
    ),

    // ---- P1 green and red on the tints and fills of the widgets (PR 5) ----
    // Each is measured by a test that pumps the widget and reads its real text
    // colour and its real tint. [audit] is the ratio before the green and red
    // were deepened (the bars: before they were made solid in light).
    for (final (id, audit, test, min) in [
      ('maturity-matured-light@tint15', 2.21, _cardTest, kMinText),
      ('card-xirr-pill-error-light@tint10', 3.29, _cardTest, kMinText),
      ('fire-status-ahead-light@tint15', 2.21, _fireCardTest, kMinText),
      ('goal-completed-light@tint15', 2.21, _goalCardsTest, kMinText),
      ('goals-achieved-light@tint10', 2.23, _goalCardsTest, kMinText),
      ('cash-flow-row-in-light@tint10', 2.31, _cashFlowRowTest, kMinText),
      ('cash-flow-row-out-light@tint10', 3.29, _cashFlowRowTest, kMinText),
      (
        'detail-return-badge-success-light@tint15',
        2.21,
        _detailStatsTest,
        kMinText,
      ),
      (
        'detail-return-badge-danger-light@tint15',
        3.10,
        _detailStatsTest,
        kMinText,
      ),
      (
        'detail-maturity-matured-light@tint15',
        2.21,
        _detailStatsTest,
        kMinText,
      ),
      (
        'overview-breakdown-success-light@tint10',
        2.31,
        _breakdownTest,
        kMinText,
      ),
      (
        'overview-breakdown-danger-light@tint10',
        3.29,
        _breakdownTest,
        kMinText,
      ),
      ('yoy-pill-success-light@tint10', 2.31, _overviewColoursTest, kMinText),
      ('copied-snackbar-label-light', 2.54, _copiedSnackbarTest, kMinText),
      (
        'confirm-dialog-destructive-light@dialog',
        3.45,
        _feedbackTest,
        kMinText,
      ),
      ('overview-cash-in-bar-light@card', 1.94, _overviewColoursTest, graphic),
      ('overview-cash-out-bar-light@card', 2.62, _overviewColoursTest, graphic),
      ('overview-cash-in-bar-dark@card', 5.15, _overviewColoursTest, graphic),
      ('overview-cash-out-bar-dark@card', 3.78, _overviewColoursTest, graphic),
      (
        'change-badge-outlined-success-dark@page',
        7.81,
        _changeBadgeStatusTest,
        kMinText,
      ),
      (
        'change-badge-outlined-danger-dark@page',
        5.26,
        _changeBadgeStatusTest,
        kMinText,
      ),
    ])
      ContrastPair.widget(
        id,
        rows: const [],
        audit: audit,
        min: min,
        addedByPlan: true,
        widgetTest: test,
      ),

    // ---- P1 investment-type colours ----
    for (final (id, type, row, audit) in _typeFills)
      ContrastPair.token(
        'inv-$id-label@fill',
        rows: [row],
        fg: white,
        ground: type.color,
        audit: audit,
      ),
    for (final (id, type, isDark, row, audit) in _typeTints)
      ContrastPair.token(
        'inv-$id-${isDark ? 'dark' : 'light'}@tint10',
        rows: [row],
        fg: type.color,
        ground: _tint(type.color, 0.1, isDark ? _cardD : _cardL),
        audit: audit,
      ),

    // ---- P2 outlines of fields, buttons and chips ----
    for (final (name, fg, grounds, row) in [
      (
        'field-border-dark',
        AppColors.neutral700Dark,
        [
          ('background', _bgD, 1.31),
          ('card', _cardD, 1.18),
          ('input-fill', _inputD, 1.15),
        ],
        63,
      ),
      (
        'field-border-light',
        AppColors.neutral200Light,
        [
          ('background', _bgL, 1.20),
          ('card', _cardL, 1.26),
          ('surface', _surfaceL, 1.15),
        ],
        64,
      ),
      (
        'outline-dark',
        dark.outline,
        [
          ('background', _bgD, 1.31),
          ('card', _cardD, 1.18),
          ('input-fill', _inputD, 1.15),
        ],
        65,
      ),
      (
        'outline-light',
        light.outline,
        [
          ('background', _bgL, 1.43),
          ('card', _cardL, 1.49),
          ('surface', _surfaceL, 1.37),
        ],
        66,
      ),
    ])
      for (final (groundName, ground, audit) in grounds)
        ContrastPair.token(
          '$name@$groundName',
          rows: [row],
          fg: fg,
          ground: ground,
          audit: audit,
          min: graphic,
          tier: 'P2',
        ),

    // ---- P3 dividers and the swipe gradient ----
    ContrastPair.token(
      'outline-variant-dark@background',
      rows: [70],
      fg: dark.outlineVariant,
      ground: _bgD,
      audit: 1.13,
      min: graphic,
      tier: 'P3',
    ),
    // Light dividers: the audit had no row for them (plan W7).
    ContrastPair.token(
      'outline-variant-light@background',
      rows: [],
      fg: light.outlineVariant,
      ground: _bgL,
      audit: 1.20,
      min: graphic,
      tier: 'P3',
      addedByPlan: true,
    ),
    ContrastPair.token(
      'outline-variant-light@card',
      rows: [],
      fg: light.outlineVariant,
      ground: _cardL,
      audit: 1.26,
      min: graphic,
      tier: 'P3',
      addedByPlan: true,
    ),
    ContrastPair.token(
      'outline-variant-light@surface',
      rows: [],
      fg: light.outlineVariant,
      ground: _surfaceL,
      audit: 1.15,
      min: graphic,
      tier: 'P3',
      addedByPlan: true,
    ),
    // White glyph on the start of the archive swipe gradient.
    ContrastPair.token(
      'archive-gradient-start-light',
      rows: [76],
      fg: white,
      ground: AppColors.archiveGradient.colors.first,
      audit: 2.15,
      min: graphic,
      tier: 'P3',
    ),

    // ---- Colours hard-coded in widgets (no live measurement yet) ----
    ContrastPair.widget(
      'closed-chip-text-light@grey20',
      rows: [17],
      audit: 2.27,
    ),
    for (final (stop, audit) in [
      ('1e1b4b', 3.55),
      ('312e81', 2.82),
      ('3b0764', 3.31),
    ])
      ContrastPair.widget(
        'hero-return-negative-dark@stop-$stop',
        rows: [18],
        audit: audit,
      ),
    for (final (stop, audit) in [
      ('5b4cdb', 1.83),
      ('7c3aed', 1.71),
      ('9333ea', 1.62),
    ])
      ContrastPair.widget(
        'hero-return-negative-light@stop-$stop',
        rows: [19],
        audit: audit,
      ),
    for (final (stop, audit) in [
      ('5b4cdb', 3.59),
      ('7c3aed', 3.69),
      ('9333ea', 3.66),
    ])
      ContrastPair.widget(
        'hero-return-positive-light@stop-$stop',
        rows: [20],
        audit: audit,
      ),
    ContrastPair.widget(
      'primary-light-in-dark@card',
      rows: [53],
      audit: 2.99,
      widgetTest: _cardTest,
    ),
    ContrastPair.widget(
      'primary-light-in-dark@card-strip',
      rows: [53],
      audit: 2.78,
      widgetTest: _cardTest,
    ),
    ContrastPair.widget(
      'primary-light-in-dark@background',
      rows: [53],
      audit: 3.30,
      widgetTest: _cardTest,
    ),
    ContrastPair.widget(
      'currency-badge-compact-light@tint20',
      rows: [54],
      audit: 4.45,
    ),
    ContrastPair.widget(
      'gradient-button-tail-light@page',
      rows: [55],
      audit: 4.04,
    ),
    ContrastPair.widget(
      'hero-secondary-dark-50@stop-312e81',
      rows: [57],
      audit: 4.06,
    ),
    for (final (stop, audit) in [
      ('5b4cdb', 4.45),
      ('7c3aed', 4.22),
      ('9333ea', 3.97),
    ])
      ContrastPair.widget(
        'hero-secondary-light-80@stop-$stop',
        rows: [58],
        audit: audit,
      ),
    for (final (stop, audit) in [
      ('5b4cdb', 3.20),
      ('7c3aed', 3.01),
      ('9333ea', 2.85),
    ])
      ContrastPair.widget(
        'hero-secondary-light-60@stop-$stop',
        rows: [59],
        audit: audit,
      ),
    for (final (stop, audit) in [
      ('5b4cdb', 2.70),
      ('7c3aed', 2.52),
      ('9333ea', 2.40),
    ])
      ContrastPair.widget(
        'hero-secondary-light-50@stop-$stop',
        rows: [60],
        audit: audit,
      ),
    for (final (stop, audit) in [
      ('5b4cdb', 3.91),
      ('7c3aed', 3.82),
      ('9333ea', 3.72),
    ])
      ContrastPair.widget(
        'hero-toggle-light@stop-$stop',
        rows: [61],
        audit: audit,
      ),
    ContrastPair.widget(
      'primary-focus-border-dark@card',
      rows: [67],
      audit: 2.99,
      min: graphic,
      tier: 'P2',
      widgetTest: 'test/core/widgets/app_text_field_theme_contrast_test.dart',
    ),
    ContrastPair.widget(
      'glass-border-dark@card',
      rows: [68],
      audit: 1.25,
      min: graphic,
      tier: 'P3',
    ),
    ContrastPair.widget(
      'glass-border-light@card',
      rows: [69],
      audit: 1.12,
      min: graphic,
      tier: 'P3',
    ),
    ContrastPair.widget(
      'snackbar-icon-danger-dark',
      rows: [71],
      audit: 2.77,
      min: graphic,
      tier: 'P3',
    ),
    ContrastPair.widget(
      'snackbar-icon-success-dark',
      rows: [72],
      audit: 1.92,
      min: graphic,
      tier: 'P3',
    ),
    for (final (stop, audit) in [
      ('5b4cdb', 2.24),
      ('7c3aed', 2.10),
      ('9333ea', 2.01),
    ])
      ContrastPair.widget(
        'hero-info-icon-light@stop-$stop',
        rows: [73],
        audit: audit,
        min: graphic,
        tier: 'P3',
      ),
    ContrastPair.widget(
      'quick-stat-subtitle-light@card',
      rows: [74],
      audit: 2.68,
    ),
    ContrastPair.widget('quick-stat-label-dark@card', rows: [75], audit: 3.89),

    // ---- Controls: pass today, must keep passing ----
    ContrastPair.control(
      'text-light@background',
      fg: AppColors.textPrimaryLight,
      ground: _bgL,
    ),
    ContrastPair.control(
      'text-light@card',
      fg: AppColors.textPrimaryLight,
      ground: _cardL,
    ),
    ContrastPair.control(
      'text-dark@background',
      fg: AppColors.textPrimaryDark,
      ground: _bgD,
    ),
    ContrastPair.control(
      'text-dark@card',
      fg: AppColors.textPrimaryDark,
      ground: _cardD,
    ),
    ContrastPair.control(
      'neutral600-light@card',
      fg: AppColors.neutral600Light,
      ground: _cardL,
    ),
    ContrastPair.control(
      'neutral500-light@card',
      fg: AppColors.neutral500Light,
      ground: _cardL,
    ),
    ContrastPair.control(
      'neutral500-light@background',
      fg: AppColors.neutral500Light,
      ground: _bgL,
    ),
    ContrastPair.control(
      'neutral400-dark@background',
      fg: AppColors.neutral400Dark,
      ground: _bgD,
    ),
    ContrastPair.control(
      'neutral400-dark@card',
      fg: AppColors.neutral400Dark,
      ground: _cardD,
    ),
    ContrastPair.control(
      'neutral400-dark@input-fill',
      fg: AppColors.neutral400Dark,
      ground: _inputD,
    ),
    ContrastPair.control(
      'primary-light@background',
      fg: AppColors.primaryLight,
      ground: _bgL,
    ),
    ContrastPair.control(
      'primary-light@card',
      fg: AppColors.primaryLight,
      ground: _cardL,
    ),
    ContrastPair.control(
      'primary-dark@background',
      fg: AppColors.primaryDark,
      ground: _bgD,
    ),
    ContrastPair.control(
      'primary-dark@card',
      fg: AppColors.primaryDark,
      ground: _cardD,
    ),
    ContrastPair.control(
      'on-primary-light',
      fg: light.onPrimary,
      ground: light.primary,
    ),
    ContrastPair.control(
      'on-primary-dark',
      fg: dark.onPrimary,
      ground: dark.primary,
    ),
    ContrastPair.control(
      'accent-dark@card',
      fg: AppColors.accentDark,
      ground: _cardD,
    ),
    ContrastPair.control(
      'success-dark@card',
      fg: AppColors.successDark,
      ground: _cardD,
    ),
    ContrastPair.control(
      'danger-dark@card',
      fg: AppColors.dangerDark,
      ground: _cardD,
    ),
    // Light green and red, deepened in PR 5, on the other grounds they sit on.
    for (final (id, color) in [
      ('success-light', AppColors.successLight),
      ('danger-light', AppColors.dangerLight),
    ])
      for (final (groundName, ground) in [
        ('background', _bgL),
        ('surface', _surfaceL),
      ])
        ContrastPair.control('$id@$groundName', fg: color, ground: ground),
    // Green text on a 10% tint of the old green (goals chip, cash flow rows).
    ContrastPair.control(
      'success-light@tint10',
      fg: AppColors.successLight,
      ground: _tint(AppColors.successTintLight, 0.1, _cardL),
    ),
    // A white label on the green fill: snackbars, onboarding, the Copied toast.
    ContrastPair.control(
      'white-on-success-light-fill',
      fg: white,
      ground: AppColors.successLight,
    ),
    ContrastPair.control(
      'error-dark@background',
      fg: AppColors.errorDark,
      ground: _bgD,
    ),
    ContrastPair.control(
      'warning-dark@card',
      fg: AppColors.warningDark,
      ground: _cardD,
    ),
    ContrastPair.control(
      'graph-cyan-dark@card',
      fg: AppColors.graphCyan,
      ground: _cardD,
    ),
    ContrastPair.control(
      'graph-emerald-dark@card',
      fg: AppColors.graphEmerald,
      ground: _cardD,
    ),
    ContrastPair.control(
      'graph-purple-dark@card',
      fg: AppColors.graphPurple,
      ground: _cardD,
    ),
    // Text on its own tint in dark: the chips and pills the colour PRs touch.
    ContrastPair.control(
      'graph-emerald-dark@tint10',
      fg: AppColors.graphEmerald,
      ground: _tint(AppColors.graphEmerald, 0.1, _cardD),
    ),
    for (final (id, color, alpha) in [
      ('success-dark@tint15', AppColors.successDark, 0.15),
      ('danger-dark@tint15', AppColors.dangerDark, 0.15),
      ('warning-dark@tint15', AppColors.warningDark, 0.15),
      ('accent-dark@tint15', AppColors.accentDark, 0.15),
    ])
      ContrastPair.control(id, fg: color, ground: _tint(color, alpha, _cardD)),

    // Every investment type and theme the audit passed: its label on its
    // fill and its name on its own 10% tint. PR 7 recolours the types.
    for (final type in InvestmentType.values) ...[
      if (!_failingTypeIds.contains('inv-${_typeId(type)}-label@fill'))
        ContrastPair.control(
          'inv-${_typeId(type)}-label@fill',
          fg: white,
          ground: type.color,
        ),
      for (final isDark in [false, true])
        if (!_failingTypeIds.contains(
          'inv-${_typeId(type)}-${isDark ? 'dark' : 'light'}@tint10',
        ))
          ContrastPair.control(
            'inv-${_typeId(type)}-${isDark ? 'dark' : 'light'}@tint10',
            fg: type.color,
            ground: _tint(type.color, 0.1, isDark ? _cardD : _cardL),
          ),
    ],
  ];
}
