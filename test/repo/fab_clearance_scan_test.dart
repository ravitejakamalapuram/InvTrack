/// A screen with a floating action button (FAB) must end its scroll with the
/// shared FAB clearance, so its last item can be scrolled clear of the button.
///
/// These are plain file checks (no Flutter bindings), like platforms_test.dart.
/// A failure names the file: either it declares a FAB and does not use
/// `ScreenSliver(clearsFab: true)`, `SliverFabClearance` or
/// `AppSpacing.fabClearance`, or it puts a Scaffold FAB outside a
/// `presentation/screens` folder, where this check would not look.
///
/// Code, not comments or strings, is what counts: a comment that names the
/// helper does not satisfy the check (see the scanner tests below).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../layout/guarded_screens.dart';

/// Any FAB: the Scaffold slot or the widget.
final _declaresFab = RegExp(
  r'\bfloatingActionButton\s*:|\bFloatingActionButton\b',
);

/// A FAB put into a Scaffold slot.
final _usesFabSlot = RegExp(r'\bfloatingActionButton\s*:');

/// The shared clearance, in any of its three spellings.
final _usesClearance = RegExp(
  r'\bclearsFab\s*:\s*true\b|\bSliverFabClearance\b|'
  r'\bAppSpacing\.fabClearance\b',
);

/// Files outside `presentation/screens` that may fill the Scaffold FAB slot.
/// Empty today; adding a path here needs a reason next to it.
const _slotOutsideScreens = <String>{};

/// [source] with comments and the inside of string literals removed. Handles
/// nested block comments, raw and triple-quoted strings. Newlines stay, so
/// line numbers hold.
String stripCommentsAndStrings(String source) {
  final out = StringBuffer();
  var i = 0;
  final n = source.length;
  while (i < n) {
    final c = source[i];
    final next = i + 1 < n ? source[i + 1] : '';
    if (c == '/' && next == '/') {
      while (i < n && source[i] != '\n') {
        i++;
      }
    } else if (c == '/' && next == '*') {
      var depth = 1;
      i += 2;
      while (i < n && depth > 0) {
        if (source.startsWith('/*', i)) {
          depth++;
          i += 2;
        } else if (source.startsWith('*/', i)) {
          depth--;
          i += 2;
        } else {
          if (source[i] == '\n') out.write('\n');
          i++;
        }
      }
    } else if (c == "'" || c == '"') {
      final raw = i > 0 && source[i - 1] == 'r';
      final triple = source.startsWith(c * 3, i);
      final quote = triple ? c * 3 : c;
      out.write(quote);
      i += quote.length;
      while (i < n && !source.startsWith(quote, i)) {
        if (!raw && source[i] == r'\' && i + 1 < n) {
          i += 2;
        } else {
          if (source[i] == '\n') out.write('\n');
          i++;
        }
        // A one-line string never runs past its line.
        if (!triple && i < n && source[i] == '\n') break;
      }
      if (i < n && source.startsWith(quote, i)) {
        out.write(quote);
        i += quote.length;
      }
    } else {
      out.write(c);
      i++;
    }
  }
  return out.toString();
}

/// Regular Dart files under `lib/`, as `/`-separated paths. Links and anything
/// else that is not a regular file are skipped, so a link cannot make a file
/// count twice or hide one.
List<String> libDartFiles() {
  final files = <String>[];
  for (final entity in Directory(
    'lib',
  ).listSync(recursive: true, followLinks: false)) {
    final path = entity.path.replaceAll(r'\', '/');
    if (!path.endsWith('.dart') || path.endsWith('.g.dart')) continue;
    if (FileSystemEntity.typeSync(entity.path, followLinks: false) !=
        FileSystemEntityType.file) {
      continue;
    }
    files.add(path);
  }
  return files..sort();
}

/// Any Dart file below a `presentation/screens` folder, however deep.
bool _isScreen(String path) =>
    RegExp(r'/presentation/screens/(?:[^/]+/)*[^/]+\.dart$').hasMatch(path);

/// The code of each class, mixin and extension in [code], then whatever is
/// left outside them. A FAB and its clearance must sit in the same one, so a
/// clearance used by an unrelated widget in the same file does not count.
List<String> scopes(String code) {
  final scopes = <String>[];
  final outside = StringBuffer();
  final header = RegExp(r'\b(?:class|mixin|extension)\b[^{;]*\{');
  var copied = 0;
  for (final match in header.allMatches(code)) {
    if (match.start < copied) continue; // inside a body already taken
    var depth = 1;
    var end = match.end;
    while (end < code.length && depth > 0) {
      if (code[end] == '{') depth++;
      if (code[end] == '}') depth--;
      end++;
    }
    outside.write(code.substring(copied, match.start));
    scopes.add(code.substring(match.start, end));
    copied = end;
  }
  outside.write(code.substring(copied));
  return [...scopes, outside.toString()];
}

String _noClearance(String path) =>
    '$path declares a floating action button but does not use the shared FAB '
    'clearance in the same class: wrap its scrolling content in '
    'ScreenSliver(clearsFab: true), end it with SliverFabClearance, or add '
    'AppSpacing.fabClearance(context). See "Screen edge and FAB clearance" in '
    'design/system/README.md.';

String _strayFab(String path) =>
    '$path fills a Scaffold floatingActionButton slot outside '
    'presentation/screens, where the FAB clearance check does not look. Move '
    'it into a screen, or allow it in this test with a reason.';

String _unguarded(String path) =>
    '$path declares a floating action button, but guardedFabScreens in '
    'test/layout/guarded_screens.dart does not list it, so no geometry test '
    'measures that its last item clears the button. Add it there and measure '
    'it in test/layout/layout_guard_harness.dart.';

String _staleGuard(String path, {required bool exists}) =>
    '$path is listed in guardedFabScreens but ${exists ? 'no longer declares '
              'a FAB' : 'does not exist'}. Remove it from '
    'test/layout/guarded_screens.dart.';

/// Every problem in [sources] (raw file text by `/`-separated path), one
/// message per file and rule, each naming the file. [guarded] is the set of
/// screens the geometry guard measures.
List<String> fabProblems(
  Map<String, String> sources, {
  required Set<String> guarded,
}) {
  final problems = <String>[];
  final screensWithFab = <String>{};
  for (final entry in sources.entries) {
    final path = entry.key;
    final code = stripCommentsAndStrings(entry.value);
    if (_isScreen(path)) {
      if (!_declaresFab.hasMatch(code)) continue;
      screensWithFab.add(path);
      // Each class that fills the Scaffold slot clears the button itself, and
      // some class holds a FAB together with the clearance (a FAB built by a
      // small widget of its own is fine beside such a class).
      final inScope = scopes(code);
      final cleared =
          inScope.every(
            (s) => !_usesFabSlot.hasMatch(s) || _usesClearance.hasMatch(s),
          ) &&
          inScope.any(
            (s) => _declaresFab.hasMatch(s) && _usesClearance.hasMatch(s),
          );
      if (!cleared) problems.add(_noClearance(path));
      if (!guarded.contains(path)) problems.add(_unguarded(path));
    } else if (_usesFabSlot.hasMatch(code) &&
        !_slotOutsideScreens.contains(path)) {
      problems.add(_strayFab(path));
    }
  }
  for (final path in guarded) {
    if (!screensWithFab.contains(path)) {
      problems.add(_staleGuard(path, exists: sources.containsKey(path)));
    }
  }
  return problems;
}

void main() {
  late final Map<String, String> sources;
  late final Map<String, String> code;

  setUpAll(() {
    sources = {
      for (final path in libDartFiles()) path: File(path).readAsStringSync(),
    };
    code = {
      for (final e in sources.entries) e.key: stripCommentsAndStrings(e.value),
    };
  });

  group('FAB clearance', () {
    test('every screen with a FAB uses the shared FAB clearance', () {
      final problems = fabProblems(
        sources,
        guarded: guardedFabScreens.keys.toSet(),
      );
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('controls: the four main screens and the helper are in the scan', () {
      const mainScreens = [
        'lib/features/overview/presentation/screens/overview_screen.dart',
        'lib/features/investment/presentation/screens/investment_list_screen.dart',
        'lib/features/investment/presentation/screens/investment_detail_screen.dart',
        'lib/features/goals/presentation/screens/goals_screen.dart',
      ];
      for (final path in mainScreens) {
        expect(code.keys, contains(path), reason: 'the scan lost $path');
        expect(
          _declaresFab.hasMatch(code[path]!),
          isTrue,
          reason: '$path no longer declares a FAB, so the scan checks nothing',
        );
      }
      expect(
        code['lib/core/widgets/screen_layout.dart'] ?? '',
        contains('class SliverFabClearance'),
        reason: 'the shared FAB clearance widget is gone',
      );
    });
  });

  // Fake files that try to get past the scan. Each one names the rule it
  // breaks; a clean one proves the rule is not just "always fail".
  group('bypass attempts', () {
    const screens = 'lib/features/zz/presentation/screens';
    const slot = 'Scaffold(floatingActionButton: fab, body: body);';

    // By default every fake file is known to the geometry guard, so each test
    // sees only the rule it is about.
    List<String> scan(Map<String, String> files, {Set<String>? only}) =>
        fabProblems(files, guarded: only ?? files.keys.toSet());

    test('a FAB with no clearance is flagged', () {
      final problems = scan({'$screens/a_screen.dart': 'class A { $slot }'});
      expect(problems.single, contains('$screens/a_screen.dart'));
    });

    test('a FAB in a screens subfolder is scanned like any screen', () {
      final problems = scan({
        '$screens/sub/zz_nested_screen.dart':
            'class A { Widget b() => Positioned(child: FloatingActionButton('
            'onPressed: null)); }',
      });
      expect(problems.single, contains('$screens/sub/zz_nested_screen.dart'));
      expect(problems.single, contains('does not use the shared FAB'));
    });

    test('a clearance in another class does not cover the FAB', () {
      final problems = scan({
        '$screens/zz_unrelated_use.dart':
            'class Other { Widget b() => ScreenSliver(clearsFab: true, '
            'sliver: s); }\n'
            'class Screen { $slot }',
      });
      expect(problems.single, contains('$screens/zz_unrelated_use.dart'));
    });

    test('a clearance in the same class as the FAB passes', () {
      final problems = scan(
        {
          '$screens/ok_screen.dart':
              'class Screen { Widget b() => ScreenSliver(clearsFab: true, '
              'sliver: s); Widget c() => $slot }',
        },
        only: {'$screens/ok_screen.dart'},
      );
      expect(problems, isEmpty);
    });

    test(
      'a FAB widget in its own class beside a screen that clears passes',
      () {
        final problems = scan({
          '$screens/split_screen.dart':
              'class _AddFab { Widget b() => FloatingActionButton('
              'onPressed: null); }\n'
              'class Screen { Widget b() => SliverFabClearance(); $slot }',
        });
        expect(problems, isEmpty);
      },
    );

    test('a FAB widget with no clearance next to it is flagged', () {
      final problems = scan({
        '$screens/split_screen.dart':
            'class _AddFab { Widget b() => FloatingActionButton('
            'onPressed: null); }\n'
            'class Other { Widget b() => SliverFabClearance(); }',
      });
      expect(problems.single, contains('$screens/split_screen.dart'));
    });

    test('a FAB screen the geometry guard does not know is flagged', () {
      final problems = scan({
        '$screens/new_screen.dart':
            'class Screen { Widget b() => SliverFabClearance(); $slot }',
      }, only: {});
      expect(problems.single, contains('$screens/new_screen.dart'));
      expect(problems.single, contains('guardedFabScreens'));
    });

    test('a guarded screen that lost its FAB is flagged', () {
      final problems = scan(
        {'$screens/old_screen.dart': 'class Screen {}'},
        only: {'$screens/old_screen.dart'},
      );
      expect(problems.single, contains('$screens/old_screen.dart'));
      expect(problems.single, contains('no longer declares a FAB'));
    });

    test('a guarded screen that no longer exists is flagged', () {
      final problems = scan({}, only: {'$screens/gone_screen.dart'});
      expect(problems.single, contains('$screens/gone_screen.dart'));
    });

    test('a helper named only in a comment does not count', () {
      final problems = scan({
        '$screens/c_screen.dart':
            '// ScreenSliver(clearsFab: true)\nclass A { $slot }',
      });
      expect(problems.single, contains('$screens/c_screen.dart'));
    });

    test('a Scaffold FAB slot outside presentation/screens is flagged', () {
      for (final folder in ['pages', 'widgets', 'screens_old']) {
        final path = 'lib/features/zz/presentation/$folder/p.dart';
        final problems = scan({path: 'class A { $slot }'}, only: {});
        expect(problems.single, contains(path), reason: folder);
      }
    });
  });

  group('scanner', () {
    test('a comment or a string that names the helper does not count', () {
      const source = '''
// ScreenSliver(clearsFab: true)
/* SliverFabClearance /* nested */ AppSpacing.fabClearance */
const a = 'clearsFab: true';
const b = r'AppSpacing.fabClearance';
const c = """
SliverFabClearance
""";
Scaffold(floatingActionButton: fab);
''';
      final stripped = stripCommentsAndStrings(source);
      expect(_usesClearance.hasMatch(stripped), isFalse);
      expect(_declaresFab.hasMatch(stripped), isTrue);
    });

    test('code after a URL string or a comment on the line above is kept', () {
      const source = '''
final url = 'https://example.com'; ScreenSliver(clearsFab: true);
// a comment
const SliverFabClearance();
''';
      final stripped = stripCommentsAndStrings(source);
      expect(_usesClearance.hasMatch(stripped), isTrue);
      expect(stripped, contains('const SliverFabClearance();'));
    });

    test('a theme or location name is not a FAB slot', () {
      final stripped = stripCommentsAndStrings(
        'floatingActionButtonTheme: x, floatingActionButtonLocation: y,',
      );
      expect(_usesFabSlot.hasMatch(stripped), isFalse);
      expect(_declaresFab.hasMatch(stripped), isFalse);
    });
  });
}
