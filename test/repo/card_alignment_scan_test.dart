/// A card footer is `CardFooterRow` (lib/core/widgets/card_footer_row.dart),
/// not a Row of `Spacer()` and `Flexible(Text)`.
///
/// `Spacer` and `Flexible` both have flex 1, so such a Row gives the text only
/// the end half of the free space and starts it there: the shorter the text,
/// the further its end sits from the card padding (the goal card footer ended
/// 22 to 48dp short of the progress ring above it). The geometry test
/// (test/layout/card_guard_*_test.dart) measures the real cards; this plain
/// file check, like platforms_test.dart, stops the pattern from coming back in
/// a card nobody measures yet.
///
/// Code, not comments or strings, is what counts, as in the FAB clearance scan.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'fab_clearance_scan_test.dart'
    show libDartFiles, stripCommentsAndStrings;

final _spacer = RegExp(r'\bSpacer\s*\(');
final _flexible = RegExp(r'\bFlexible\s*\(');

/// How many lines after a `Spacer(` a `Flexible(` still counts as its sibling
/// in the same Row.
const _window = 12;

/// Files that may keep the pair, by path, each with the reason. Empty today;
/// adding a path needs a reason next to it.
const _allowed = <String, String>{};

String _problem(String path, int line, int flexibleLine) =>
    '$path:$line has Spacer() and, ${flexibleLine - line} lines later, '
    'Flexible(. In a Row both take half of the free space, so the text starts '
    'half way and ends short of the card padding. Use CardFooterRow '
    '(lib/core/widgets/card_footer_row.dart), or allow the file in '
    'test/repo/card_alignment_scan_test.dart with a reason.';

/// Every Spacer-then-Flexible pair in the presentation files of [sources]
/// (raw file text by `/`-separated path).
List<String> spacerFlexibleProblems(Map<String, String> sources) {
  final problems = <String>[];
  for (final entry in sources.entries) {
    final path = entry.key;
    if (!path.contains('/presentation/') || _allowed.containsKey(path)) {
      continue;
    }
    final lines = stripCommentsAndStrings(entry.value).split('\n');
    for (var i = 0; i < lines.length; i++) {
      final spacer = _spacer.firstMatch(lines[i]);
      if (spacer == null) continue;
      // On the Spacer's own line only what comes after it counts.
      for (var j = i; j < lines.length && j <= i + _window; j++) {
        final text = j == i ? lines[j].substring(spacer.end) : lines[j];
        if (_flexible.hasMatch(text)) {
          problems.add(_problem(path, i + 1, j + 1));
          break;
        }
      }
    }
  }
  return problems;
}

void main() {
  late final Map<String, String> sources;

  setUpAll(() {
    sources = {
      for (final path in libDartFiles()) path: File(path).readAsStringSync(),
    };
  });

  test('no presentation file lays a footer out as Spacer and Flexible', () {
    final problems = spacerFlexibleProblems(sources);
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('controls: the scan sees the goal card, which uses CardFooterRow', () {
    const goalCard = 'lib/features/goals/presentation/widgets/goal_card.dart';
    expect(sources.keys, contains(goalCard), reason: 'the scan lost $goalCard');
    expect(
      stripCommentsAndStrings(sources[goalCard]!),
      contains('CardFooterRow('),
      reason: 'the goal card no longer lays its footer out with CardFooterRow',
    );
  });

  test('every allowed file exists and says why', () {
    for (final entry in _allowed.entries) {
      expect(sources.keys, contains(entry.key));
      expect(entry.value.trim(), isNotEmpty);
    }
  });

  group('scanner', () {
    const widgets = 'lib/features/zz/presentation/widgets';

    List<String> scan(String source, {String path = '$widgets/a.dart'}) =>
        spacerFlexibleProblems({path: source});

    test('finds the pair in the same Row', () {
      expect(
        scan('''
Row(children: [
  Text('a'),
  const Spacer(),
  Flexible(child: Text('b')),
]);
'''),
        hasLength(1),
      );
    });

    test('finds a Spacer with a flex and a Flexible on the same line', () {
      expect(
        scan('Row(children: [Spacer(flex: 2), Flexible(child: x)]);'),
        hasLength(1),
      );
    });

    test('finds the pair as far apart as the window allows, not further', () {
      String gap(int lines) =>
          'Spacer(),\n${'x,\n' * (lines - 1)}Flexible(child: x),';
      expect(scan(gap(_window)), hasLength(1));
      expect(scan(gap(_window + 1)), isEmpty);
    });

    test('a comment or a string that names the pair does not count', () {
      expect(
        scan('''
// Spacer() then Flexible(
/* Spacer(), Flexible( */
const a = 'Spacer() Flexible(';
'''),
        isEmpty,
      );
    });

    test('Expanded, a Flexible before the Spacer and a lone Spacer pass', () {
      expect(
        scan('Row(children: [Text(a), Spacer(), Expanded(child: b)]);'),
        isEmpty,
      );
      expect(
        scan('Row(children: [Flexible(child: a), Spacer(), Text(b)]);'),
        isEmpty,
      );
      expect(
        scan('Row(children: [Text(a), const Spacer(), Icon(b)]);'),
        isEmpty,
      );
    });

    test('a file outside presentation is not scanned', () {
      expect(
        scan('Spacer(),\nFlexible(child: x),', path: 'lib/core/widgets/a.dart'),
        isEmpty,
      );
    });

    test('a name that only ends in Spacer or Flexible does not count', () {
      expect(scan('NoSpacer(),\nInflexible(child: x),'), isEmpty);
    });
  });
}
