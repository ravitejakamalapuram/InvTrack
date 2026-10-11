// Source scan: a colour made for the light theme must not be painted
// unconditionally.
//
// The nine constants below are the light-theme text colours (and the one dark
// grey) that the contrast PRs change. A site that reads one of them without a
// theme check paints it in both themes, so changing its value would also change
// the dark theme, where the old value was the readable one. A site passes when
//
//  1. its expression (the argument or assignment around it, up to the nearest
//     comma, semicolon or enclosing bracket) mentions the theme: `isDark` or
//     `brightness`; or
//  2. it is a tint: `.withValues(alpha: 0.5)` or less applied to it; or
//  3. the line carries a `theme-neutral:` comment, or the comment line just
//     above it does, saying why the same colour belongs in both themes (a
//     fill under a white label, a chart bar).
//
// The check reads text, not types. It cannot tell a label from a fill, so rule
// 1 passes any site whose expression mentions the theme, rule 2 passes a
// translucent text colour, and rule 3 is the author's word. A colour inside a
// string interpolation is not seen (none exists in lib/). A reviewer reads the
// `theme-neutral:` comments.
//
// Files still to fix are counted in [_unfixed]. The count must match exactly:
// a new site in a listed file fails, and so does a fixed one that is still
// counted. Later PRs in the stack lower the counts and delete the entries.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _constants = [
  'neutral500Light',
  'textSecondaryLight',
  'neutral400Light',
  'neutral500Dark',
  'successLight',
  'dangerLight',
  'errorLight',
  'accentLight',
  'warningLight',
];

/// Sites not yet fixed, by file: how many are left. Raising a number, or adding
/// a file, needs a reason in the PR body.
const _unfixed = <String, int>{
  // PR 3 contrast-theme-aware-screens: settings, auth, goals, FIRE, onboarding.
  'lib/features/auth/presentation/dialogs/backup_merge_dialog.dart': 1,
  'lib/features/auth/presentation/widgets/pending_guest_backup_notice.dart': 1,
  'lib/features/fire_number/presentation/extensions/fire_entity_ui_extensions.dart':
      5,
  'lib/features/fire_number/presentation/screens/fire_dashboard_screen.dart': 1,
  'lib/features/fire_number/presentation/screens/fire_settings_screen.dart': 4,
  'lib/features/goals/presentation/screens/goal_details_screen.dart': 4,
  'lib/features/goals/presentation/screens/goals_screen.dart': 1,
  'lib/features/goals/presentation/widgets/goal_card.dart': 1,
  'lib/features/goals/presentation/widgets/goal_carousel_card.dart': 1,
  'lib/features/goals/presentation/widgets/goals_dashboard_card.dart': 1,
  'lib/features/goals/presentation/widgets/goals_list_action_bar.dart': 1,
  'lib/features/onboarding/presentation/screens/onboarding_screen.dart': 2,
  'lib/features/settings/presentation/screens/about_screen.dart': 4,
  'lib/features/settings/presentation/screens/appearance_settings_screen.dart':
      2,
  'lib/features/settings/presentation/screens/data_management_screen.dart': 15,
  'lib/features/settings/presentation/screens/debug_settings_screen.dart': 8,
  'lib/features/settings/presentation/screens/notifications_settings_screen.dart':
      1,
  'lib/features/settings/presentation/screens/security_settings_screen.dart': 1,
  'lib/features/settings/presentation/screens/settings_screen.dart': 6,
  'lib/features/settings/presentation/widgets/crashlytics_settings_section.dart':
      2,
  'lib/features/settings/presentation/widgets/deletion_request_banner.dart': 1,
  'lib/features/settings/presentation/widgets/saved_guest_backup_tile.dart': 2,
  // PR 3, separate commit: hidden until A42 (Income Guardian).
  'lib/features/income_projection/presentation/screens/income_calendar_screen.dart':
      1,
  'lib/features/income_projection/presentation/screens/income_guardian_settings_screen.dart':
      3,
  'lib/features/income_projection/presentation/screens/income_trend_report_screen.dart':
      1,
  'lib/features/income_projection/presentation/widgets/expected_income_section.dart':
      13,
  'lib/features/income_projection/presentation/widgets/income_cell.dart': 4,
  'lib/features/income_projection/presentation/widgets/income_guardian_dashboard_card.dart':
      11,
  // In neither PR 2's nor PR 3's file list in the plan; PR 3 must take them.
  'lib/core/widgets/metric_tile.dart': 2,
  'lib/features/fire_number/presentation/widgets/fire_load_error_card.dart': 1,
  // Deliberately kept: no screen uses ChangeBadge (the plan's W2), and its pale
  // fill is the same in both themes. PR 4 edits only its zero-badge text.
  'lib/core/widgets/change_badge.dart': 3,
};

/// Never scanned: they define the constants and build both themes explicitly.
const _skipped = [
  'lib/core/theme/app_colors.dart',
  'lib/core/theme/app_theme.dart',
];

typedef Site = ({int line, String constant, String expression});

/// [source] with comments and string contents turned into spaces, so the
/// brackets and commas in them are not read. Offsets and lines are unchanged.
String blankCommentsAndStrings(String source) {
  final out = StringBuffer();
  String blank(String s) => s.replaceAll(RegExp(r'[^\n]'), ' ');
  var i = 0;
  while (i < source.length) {
    if (source.startsWith('//', i)) {
      var end = source.indexOf('\n', i);
      if (end < 0) end = source.length;
      out.write(blank(source.substring(i, end)));
      i = end;
    } else if (source.startsWith('/*', i)) {
      final close = source.indexOf('*/', i + 2);
      final end = close < 0 ? source.length : close + 2;
      out.write(blank(source.substring(i, end)));
      i = end;
    } else if (source[i] == "'" || source[i] == '"') {
      final quote = source[i];
      final isRaw = i > 0 && source[i - 1] == 'r';
      final open = source.startsWith(quote * 3, i) ? quote * 3 : quote;
      var j = i + open.length;
      while (j < source.length && !source.startsWith(open, j)) {
        j += !isRaw && source[j] == r'\' ? 2 : 1;
      }
      // An unterminated string runs to the end of the file.
      final end = j < source.length ? j : source.length;
      out
        ..write(open)
        ..write(blank(source.substring(i + open.length, end)))
        ..write(j < source.length ? open : '');
      i = j < source.length ? j + open.length : source.length;
    } else {
      out.write(source[i++]);
    }
  }
  return out.toString();
}

/// The expression around [start]..[end]: back to the nearest `,` `;` `=` `=>`
/// or unmatched opening bracket, forward to the nearest `,` `;` or unmatched
/// closing bracket. Brackets inside it are skipped over.
(int, int) expressionAround(String code, int start, int end) {
  var depth = 0;
  var from = start - 1;
  for (; from >= 0; from--) {
    final c = code[from];
    if (')]}'.contains(c)) {
      depth++;
    } else if ('([{'.contains(c)) {
      if (depth == 0) break;
      depth--;
    } else if (depth == 0) {
      final prev = from > 0 ? code[from - 1] : '';
      final next = from + 1 < code.length ? code[from + 1] : '';
      if (',;'.contains(c)) break;
      if (c == '>' && prev == '=') break; // =>
      if (c == '=' && !'=>'.contains(next) && !'=!<>'.contains(prev)) break;
    }
  }
  depth = 0;
  var to = end;
  for (; to < code.length; to++) {
    final c = code[to];
    if ('([{'.contains(c)) {
      depth++;
    } else if (')]}'.contains(c)) {
      if (depth == 0) break;
      depth--;
    } else if (depth == 0 && ',;'.contains(c)) {
      break;
    }
  }
  return (from + 1, to);
}

final _theme = RegExp('isDark|brightness', caseSensitive: false);
final _tint = RegExp(r'\s*\.withValues\(\s*alpha:\s*([0-9.]+)\s*\)');
final _occurrence = RegExp('\\bAppColors\\.(${_constants.join('|')})\\b');

bool _isTint(String code, int at) {
  final m = _tint.matchAsPrefix(code, at);
  return m != null && double.parse(m.group(1)!) <= 0.5;
}

/// The sites in [source] that read one of the nine constants with no theme
/// check, no tint and no `theme-neutral:` comment.
List<Site> unguardedSites(String source) {
  final code = blankCommentsAndStrings(source);
  final lines = source.split('\n');
  final sites = <Site>[];
  for (final m in _occurrence.allMatches(code)) {
    final (from, to) = expressionAround(code, m.start, m.end);
    final expression = code.substring(from, to);
    if (_theme.hasMatch(expression)) continue;
    // `(a ? x : y).withValues(...)` tints the whole group.
    final closes = to < code.length && code[to] == ')';
    if (_isTint(code, m.end) || (closes && _isTint(code, to + 1))) continue;
    final line = '\n'.allMatches(code.substring(0, m.start)).length;
    if (lines[line].contains('theme-neutral:')) continue;
    if (line > 0 &&
        lines[line - 1].trimLeft().startsWith('//') &&
        lines[line - 1].contains('theme-neutral:')) {
      continue;
    }
    sites.add((
      line: line + 1,
      constant: m.group(1)!,
      expression: expression.trim().replaceAll(RegExp(r'\s+'), ' '),
    ));
  }
  return sites;
}

void main() {
  group('the scan', () {
    List<int> found(String source) => [
      for (final s in unguardedSites(source)) s.line,
    ];

    test('passes a site whose expression mentions the theme', () {
      expect(
        found('''
final a = isDark ? AppColors.successDark : AppColors.successLight;
final b = Theme.of(context).brightness == Brightness.dark
    ? AppColors.errorDark
    : AppColors.errorLight;
Text('x', style: TextStyle(color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light));
'''),
        isEmpty,
      );
    });

    test('flags a bare site and a ternary with no theme in it', () {
      expect(
        found('''
final a = AppColors.successLight;
final b = up ? AppColors.successLight : AppColors.errorLight;
'''),
        [1, 2, 2],
      );
    });

    test('does not borrow the theme from a sibling argument', () {
      expect(
        found('''
Row(children: [
  Icon(Icons.add, color: isDark ? Colors.white : Colors.black),
  Icon(Icons.add, color: AppColors.accentLight),
]);
'''),
        [3],
      );
    });

    test('passes a tint of half strength or less, flags a stronger one', () {
      expect(
        found('''
final a = AppColors.errorLight.withValues(alpha: 0.1);
final b = AppColors.errorLight.withValues(alpha: 0.5);
final c = (up ? AppColors.successLight : AppColors.errorLight).withValues(alpha: 0.15);
final d = AppColors.errorLight.withValues(alpha: 0.7);
'''),
        [4],
      );
    });

    test('passes a site that says why it is the same in both themes', () {
      expect(
        found('''
// theme-neutral: a fill under a white label.
final a = AppColors.successLight;
final b = AppColors.successLight; // theme-neutral: a fill.
final c = AppColors.successLight;
'''),
        [4],
      );
    });

    test('ignores comments and strings, and other constants', () {
      expect(
        found('''
// AppColors.successLight in a comment
/* AppColors.errorLight, isDark */
final a = 'AppColors.successLight';
final b = AppColors.successDark;
final c = AppColors.successLightBg;
'''),
        isEmpty,
      );
    });

    test('a bracket or comma inside a string does not end the expression', () {
      expect(
        found('''
final a = isDark ? 'a, (b' : AppColors.successLight;
'''),
        isEmpty,
      );
    });
  });

  test('every site that reads a light colour checks the theme', () {
    final failures = <String>[];
    final stale = <String>[];
    final seen = <String>{};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (_skipped.contains(path)) continue;
      final sites = unguardedSites(entity.readAsStringSync());
      final allowed = _unfixed[path] ?? 0;
      if (allowed > 0) seen.add(path);
      if (sites.length == allowed) continue;
      if (sites.length < allowed) {
        stale.add('$path: ${sites.length} left, _unfixed says $allowed');
        continue;
      }
      failures.addAll([
        if (allowed > 0) '$path: ${sites.length} sites, _unfixed says $allowed',
        for (final s in sites)
          '$path:${s.line} AppColors.${s.constant}  ${s.expression}',
      ]);
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
    expect(stale, isEmpty, reason: 'Lower the count: ${stale.join('\n')}');
    expect(
      _unfixed.keys.toSet().difference(seen),
      isEmpty,
      reason: 'Delete the entry: the file is fixed or gone.',
    );
  });
}
