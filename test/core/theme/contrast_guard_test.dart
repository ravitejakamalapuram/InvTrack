// Guards the app's colours against the WCAG 2.1 AA minimums: 4.5:1 for text,
// 3:1 for outlines, dividers and icons.
//
// Every pair the audit found failing is on [_allowlist]. Each colour PR
// deletes the ids it fixes and lowers [_allowlistMax], so a later change
// cannot quietly break a fixed pair, and a stale entry fails the suite. The
// allowlist is the thing to review: it may only shrink. Nothing enforces
// that, so in every diff read the three literals [_allowlist],
// [_allowlistMax] and [_pairCount]: an id added, or a number raised, needs a
// reason in the PR body.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'contrast_pairs.dart';

/// Pairs that still fail. Grouped by the PR in the stack that fixes them.
const _allowlist = <String>{
  // Decorative edges kept as drawn (owner decision 2026-10-17, #977): dividers
  // and the glass card border. Text, icons and controls carry the meaning.
  'outline-variant-dark@background',
  'outline-variant-light@background',
  'outline-variant-light@card',
  'outline-variant-light@surface',
  'glass-border-dark@card',
  'glass-border-light@card',
};

/// The size of [_allowlist]. Lower it with the list; raising it needs a reason
/// in the PR body.
const _allowlistMax = 6;

/// The size of the pair table. A fixing PR that retires a pair or drops a
/// ground it cannot fix changes this literal, so the change is in the diff.
const _pairCount = 262;

/// Files that can never be the measurement of a widget pair: the helper's own
/// test, this guard and the table. Each mentions pair ids or `contrastRatio`.
const _notMeasurements = [
  'test/helpers/contrast_test.dart',
  'test/core/theme/contrast_guard_test.dart',
  'test/core/theme/contrast_pairs.dart',
];

/// Whether [path] names a test that measures the widget pair [id]: a `_test`
/// file (so the runner runs it) other than [_notMeasurements], resolved
/// through symlinks, that calls `contrastRatio` and names [id] in code, not
/// only in a comment (a `//` inside a string hides the rest of its line, which
/// can only fail closed). A reviewer still checks that it pumps the widget.
bool measuresPair(String id, String? path) {
  if (path == null || !path.endsWith('_test.dart')) return false;
  final file = File(path);
  if (!file.existsSync()) return false;
  final real = file.resolveSymbolicLinksSync();
  for (final other in _notMeasurements) {
    if (File(other).resolveSymbolicLinksSync() == real) return false;
  }
  final code = file
      .readAsStringSync()
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .replaceAll(RegExp('//.*'), '');
  return code.contains('contrastRatio') && code.contains(id);
}

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

  test('the table has as many pairs as _pairCount says', () {
    expect(pairs.length, _pairCount);
  });

  test('every audited row is in the table, but the two retired ones', () {
    final rows = {for (final p in pairs) ...p.rows};
    // Rows 1 and 10 (dark danger and success on their pale fills) were retired
    // in PR 5: only ChangeBadge paints those fills, it paints the light
    // colour on them and has no caller, so the pairs never occur.
    const retired = {1, 10};
    expect(rows, {
      for (var i = 0; i < 77; i++)
        if (!retired.contains(i)) i,
    });
  });

  test('the pairs the audit had no row for are exactly these', () {
    // The plan's three light dividers, the four the PR 1 review found on the
    // investment card's XIRR pill and the danger tint, and the twenty-six widget
    // pairs PR 5 added for green and red on the tints and fills they sit on,
    // the nineteen PR 6 added for blue and amber text and icons, and the five
    // PR 7 added for the widgets that paint a type's colours.
    expect(
      pairs.where((p) => p.addedByPlan).map((p) => p.id),
      unorderedEquals([
        'danger-light@tint15',
        'error-light-in-dark@tint10',
        'error-light@tint10',
        'graph-emerald-light@tint10',
        'outline-variant-light@background',
        'outline-variant-light@card',
        'outline-variant-light@surface',
        'maturity-matured-light@tint15',
        'card-xirr-pill-error-light@tint10',
        'fire-status-ahead-light@tint15',
        'goal-completed-light@tint15',
        'goals-achieved-light@tint10',
        'cash-flow-row-in-light@tint10',
        'cash-flow-row-out-light@tint10',
        'detail-return-badge-success-light@tint15',
        'detail-return-badge-danger-light@tint15',
        'detail-maturity-matured-light@tint15',
        'detail-net-disc-success-light@tint10',
        'detail-net-disc-danger-light@tint10',
        'fire-milestone-disc-light@tint20',
        'fire-insight-disc-light@tint20',
        'overview-breakdown-success-light@tint10',
        'overview-breakdown-danger-light@tint10',
        'yoy-pill-success-light@tint10',
        'copied-snackbar-label-light',
        'reports-attention-count-light@tint10',
        'confirm-dialog-destructive-light@dialog',
        'overview-cash-in-bar-light@card',
        'overview-cash-out-bar-light@card',
        'overview-cash-in-bar-dark@card',
        'overview-cash-out-bar-dark@card',
        'change-badge-outlined-success-dark@page',
        'change-badge-outlined-danger-dark@page',
        'maturity-soon-light@tint15',
        'maturity-upcoming-light@tint15',
        'detail-maturity-soon-light@tint15',
        'detail-maturity-upcoming-light@tint15',
        'fire-status-behind-light@tint15',
        'fire-status-on-track-light@tint15',
        'fire-stats-icon-fire-light@tint15',
        'fire-stats-icon-barista-light@tint15',
        'sample-data-banner-light@tint10',
        'sample-data-icon-light@tint20',
        'sample-data-try-it-light@gradient',
        'sample-data-tile-icon-light@tint20',
        'quick-start-csv-icon-light@tint20',
        'xirr-demo-highlight-light@tint5',
        'saved-guest-backup-icon-light@card',
        'insight-warning-value-light@card',
        'insight-warning-icon-light@tint20',
        'settings-tile-warning-icon-light@tint15',
        'import-option-warning-icon-light@tint15',
        'closed-chip-text-dark@grey20',
        'currency-badge-compact-dark@tint20',
        'gradient-button-tail-dark@page',
        'quick-stat-label-light@card',
        'quick-stat-subtitle-dark@card',
        'health-tier-excellent-light@card',
        'health-tier-excellent-dark@card',
        'health-tier-good-light@card',
        'health-tier-good-dark@card',
        'health-tier-fair-light@card',
        'health-tier-fair-dark@card',
        'health-tier-poor-light@card',
        'health-tier-poor-dark@card',
        'health-badge-excellent-light@tint10',
        'health-badge-excellent-dark@tint10',
        'health-badge-good-light@tint10',
        'health-badge-good-dark@tint10',
        'health-badge-fair-light@tint10',
        'health-badge-fair-dark@tint10',
        'health-badge-poor-light@tint10',
        'health-badge-poor-dark@tint10',
        'health-suggestion-digit-light@fill',
        'health-suggestion-digit-dark@fill',
        'health-chart-lines-light@card',
        'health-chart-lines-dark@card',
        'score-change-positive-light@tint10',
        'score-change-positive-dark@tint10',
        'score-change-negative-light@tint10',
        'score-change-negative-dark@tint10',
        'goal-status-not-started-light@card',
        'goal-status-not-started-dark@card',
        'goal-status-in-progress-light@card',
        'goal-status-in-progress-dark@card',
        'goal-status-on-track-light@card',
        'goal-status-on-track-dark@card',
        'goal-status-ahead-light@card',
        'goal-status-ahead-dark@card',
        'goal-status-behind-light@card',
        'goal-status-behind-dark@card',
        'goal-status-achieved-light@card',
        'goal-status-achieved-dark@card',
        'goal-status-archived-light@card',
        'goal-status-archived-dark@card',
        'inv-tile-icon-light@gradient',
        'inv-tile-icon-dark@gradient',
        'inv-detail-header@fill',
        'type-selector-label@fill',
      ]),
    );
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
    expectNone([
      for (final p in pairs)
        if (p.kind == PairKind.widget &&
            !_allowlist.contains(p.id) &&
            !measuresPair(p.id, p.widgetTest))
          p.id,
    ]);
  });

  group('a widget pair counts as measured only by a test that measures it', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('contrast_guard_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    String write(String name, String source) {
      final file = File('${tmp.path}/$name')..writeAsStringSync(source);
      return file.path;
    }

    const measuring = '''
void main() {
  test('x', () {
    expect(contrastRatio(a, b), greaterThan(4.5)); // closed-chip@grey20
    final id = 'closed-chip@grey20';
  });
}
''';

    test('accepts a test that calls contrastRatio and names the pair', () {
      expect(
        measuresPair('closed-chip@grey20', write('a_test.dart', measuring)),
        isTrue,
      );
    });

    test('rejects a test that never names the pair', () {
      expect(
        measuresPair('other-pair@card', write('a_test.dart', measuring)),
        isFalse,
      );
    });

    test('rejects a pair named only in a comment', () {
      final path = write('a_test.dart', '''
// closed-chip@grey20 is checked elsewhere
void main() => contrastRatio(a, b);
''');
      expect(measuresPair('closed-chip@grey20', path), isFalse);
    });

    test('rejects a pair named only in a trailing or block comment', () {
      final path = write('a_test.dart', '''
/* closed-chip@grey20 */
void main() => contrastRatio(a, b); // closed-chip@grey20
''');
      expect(measuresPair('closed-chip@grey20', path), isFalse);
    });

    test('rejects a test that never calls contrastRatio', () {
      final path = write(
        'a_test.dart',
        "void main() => print('closed-chip@grey20');",
      );
      expect(measuresPair('closed-chip@grey20', path), isFalse);
    });

    test('rejects a file the test runner would not run', () {
      expect(
        measuresPair('closed-chip@grey20', write('a_helper.dart', measuring)),
        isFalse,
      );
    });

    test('rejects a missing file and no file', () {
      expect(
        measuresPair('closed-chip@grey20', '${tmp.path}/none_test.dart'),
        isFalse,
      );
      expect(measuresPair('closed-chip@grey20', null), isFalse);
    });

    test('rejects the helper test, whatever it mentions', () {
      // contrast_test.dart calls contrastRatio and mentions composeOver.
      expect(
        measuresPair('composeOver', 'test/helpers/contrast_test.dart'),
        isFalse,
      );
    });

    test('rejects this guard, which mentions every pair id', () {
      expect(
        measuresPair(
          'measures-nothing@card',
          'test/core/theme/contrast_guard_test.dart',
        ),
        isFalse,
      );
    });

    test(
      'rejects a symlink to the helper test',
      () {
        final link = Link('${tmp.path}/alias_test.dart')
          ..createSync(File('test/helpers/contrast_test.dart').absolute.path);
        expect(measuresPair('composeOver', link.path), isFalse);
      },
      skip: Platform.isWindows ? 'symlinks need privileges on Windows' : false,
    );
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
