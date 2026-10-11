// Guards the app's colours against the WCAG 2.1 AA minimums: 4.5:1 for text,
// 3:1 for outlines, dividers and icons.
//
// Every pair the audit found failing is on [_allowlist]. Each colour PR
// deletes the ids it fixes and lowers [_allowlistMax], so a later change
// cannot quietly break a fixed pair, and a stale entry fails the suite. The
// allowlist is the thing to review: it may only shrink.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'contrast_pairs.dart';

/// Pairs that still fail. Grouped by the PR in the stack that fixes them.
const _allowlist = <String>{
  // PR 2 contrast-theme-aware-core: primary painted in dark (4)
  'primary-light-in-dark@card',
  'primary-light-in-dark@card-strip',
  'primary-light-in-dark@background',
  'primary-focus-border-dark@card',
  // PR 4 contrast-grey-text (7)
  'neutral400-light@card',
  'neutral400-light@surface',
  'neutral500-dark@background',
  'neutral500-dark@card',
  'neutral500-dark@input-fill',
  'neutral500-light@surface',
  'zero-badge-text-light@fill',
  // PR 5 contrast-gain-loss (the two ChangeBadge dark pairs are retired there) (10)
  'danger-light@danger-bg',
  'danger-light@card',
  'on-error-dark',
  'on-error-light',
  'success-light@success-bg',
  'success-light@card',
  'success-light@tint15',
  'on-primary-container-light',
  'danger-dark@danger-bg',
  'success-dark@success-bg',
  // PR 6 contrast-warning-accent (4)
  'accent-light@card',
  'accent-light@tint15',
  'warning-light@card',
  'warning-light@tint15',
  // PR 7 contrast-type-colours (33)
  'closed-chip-text-light@grey20',
  'inv-angel-investing-label@fill',
  'inv-bonds-label@fill',
  'inv-chit-funds-label@fill',
  'inv-crypto-label@fill',
  'inv-financing-label@fill',
  'inv-fixed-deposit-label@fill',
  'inv-gold-label@fill',
  'inv-invoice-discounting-label@fill',
  'inv-mutual-funds-label@fill',
  'inv-p2p-lending-label@fill',
  'inv-private-equity-label@fill',
  'inv-real-estate-label@fill',
  'inv-stocks-label@fill',
  'inv-angel-investing-light@tint10',
  'inv-bonds-light@tint10',
  'inv-chit-funds-light@tint10',
  'inv-crypto-dark@tint10',
  'inv-crypto-light@tint10',
  'inv-financing-light@tint10',
  'inv-fixed-deposit-light@tint10',
  'inv-gold-light@tint10',
  'inv-invoice-discounting-light@tint10',
  'inv-mutual-funds-dark@tint10',
  'inv-mutual-funds-light@tint10',
  'inv-other-dark@tint10',
  'inv-other-light@tint10',
  'inv-p2p-lending-dark@tint10',
  'inv-p2p-lending-light@tint10',
  'inv-private-equity-dark@tint10',
  'inv-private-equity-light@tint10',
  'inv-real-estate-light@tint10',
  'inv-stocks-light@tint10',
  // PR 8 contrast-hardcoded (4)
  'currency-badge-compact-light@tint20',
  'gradient-button-tail-light@page',
  'quick-stat-subtitle-light@card',
  'quick-stat-label-dark@card',
  // PR 9 contrast-chart-hero (25)
  'graph-cyan-light@card',
  'graph-emerald-light@card',
  'graph-purple-light@card',
  'hero-return-negative-dark@stop-1e1b4b',
  'hero-return-negative-dark@stop-312e81',
  'hero-return-negative-dark@stop-3b0764',
  'hero-return-negative-light@stop-5b4cdb',
  'hero-return-negative-light@stop-7c3aed',
  'hero-return-negative-light@stop-9333ea',
  'hero-return-positive-light@stop-5b4cdb',
  'hero-return-positive-light@stop-7c3aed',
  'hero-return-positive-light@stop-9333ea',
  'hero-secondary-dark-50@stop-312e81',
  'hero-secondary-light-80@stop-5b4cdb',
  'hero-secondary-light-80@stop-7c3aed',
  'hero-secondary-light-80@stop-9333ea',
  'hero-secondary-light-60@stop-5b4cdb',
  'hero-secondary-light-60@stop-7c3aed',
  'hero-secondary-light-60@stop-9333ea',
  'hero-secondary-light-50@stop-5b4cdb',
  'hero-secondary-light-50@stop-7c3aed',
  'hero-secondary-light-50@stop-9333ea',
  'hero-toggle-light@stop-5b4cdb',
  'hero-toggle-light@stop-7c3aed',
  'hero-toggle-light@stop-9333ea',
  // PR 10 contrast-outlines (12)
  'field-border-dark@background',
  'field-border-dark@card',
  'field-border-dark@input-fill',
  'field-border-light@background',
  'field-border-light@card',
  'field-border-light@surface',
  'outline-dark@background',
  'outline-dark@card',
  'outline-dark@input-fill',
  'outline-light@background',
  'outline-light@card',
  'outline-light@surface',
  // PR 11 contrast-card-edges (12)
  'outline-variant-dark@background',
  'outline-variant-light@background',
  'outline-variant-light@card',
  'outline-variant-light@surface',
  'archive-gradient-start-light',
  'glass-border-dark@card',
  'glass-border-light@card',
  'snackbar-icon-danger-dark',
  'snackbar-icon-success-dark',
  'hero-info-icon-light@stop-5b4cdb',
  'hero-info-icon-light@stop-7c3aed',
  'hero-info-icon-light@stop-9333ea',
};

/// The size of [_allowlist]. Lower it with the list; raising it needs a reason
/// in the PR body.
const _allowlistMax = 111;

void main() {
  // The pair table reads AppTheme, which builds text styles from fonts.
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  final pairs = kContrastPairs;
  final byId = {for (final p in pairs) p.id: p};

  String describe(ContrastPair p) =>
      '${p.id}: ${p.ratio.toStringAsFixed(2)} (needs ${p.min})';

  // The default matcher cuts a long list short; the reason lists every entry.
  void expectNone(List<String> offenders) =>
      expect(offenders, isEmpty, reason: offenders.join('\n'));

  test('pair ids are unique', () {
    expect(byId.length, pairs.length);
  });

  test('every allowlist id names a pair', () {
    expectNone([
      for (final id in _allowlist)
        if (!byId.containsKey(id)) id,
    ]);
  });

  test('the allowlist is as long as _allowlistMax says', () {
    expect(_allowlist.length, _allowlistMax);
  });

  test('every audited row is in the table', () {
    final rows = {for (final p in pairs) ...p.rows};
    expect(rows, {for (var i = 0; i < 77; i++) i});
  });

  test('the plan added exactly the three light dividers', () {
    expect(pairs.where((p) => p.addedByPlan).map((p) => p.id), [
      'outline-variant-light@background',
      'outline-variant-light@card',
      'outline-variant-light@surface',
    ]);
  });

  test('measured pairs off the allowlist meet their minimum', () {
    final failing = [
      for (final p in pairs)
        if (p.kind == PairKind.token &&
            !_allowlist.contains(p.id) &&
            p.ratio < p.min)
          describe(p),
    ];
    expectNone(failing);
  });

  test('widget pairs off the allowlist name a test that measures them', () {
    // Only that a real test is named; a reviewer checks it pumps the widget.
    bool measures(String? path) =>
        path != null &&
        File(path).existsSync() &&
        File(path).readAsStringSync().contains('contrastRatio');
    expectNone([
      for (final p in pairs)
        if (p.kind == PairKind.widget &&
            !_allowlist.contains(p.id) &&
            !measures(p.widgetTest))
          p.id,
    ]);
  });

  test('allowlisted measured pairs still fail (delete the id once fixed)', () {
    final fixed = [
      for (final id in _allowlist)
        if (byId[id] case final p? when p.kind == PairKind.token)
          if (p.ratio >= p.min) describe(p),
    ];
    expectNone(fixed);
  });

  test('allowlisted measured pairs do not get worse', () {
    final worse = [
      for (final id in _allowlist)
        if (byId[id] case final p? when p.kind == PairKind.token)
          if (p.ratio < p.audit! - 0.005) '${describe(p)}, was ${p.audit}',
    ];
    expectNone(worse);
  });
}
