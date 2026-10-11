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

bool _isScreen(String path) =>
    RegExp(r'/presentation/screens/[^/]+\.dart$').hasMatch(path);

String _noClearance(String path) =>
    '$path declares a floating action button but does not use the shared FAB '
    'clearance: wrap its scrolling content in ScreenSliver(clearsFab: true), '
    'end it with SliverFabClearance, or add AppSpacing.fabClearance(context). '
    'See "Screen edge and FAB clearance" in design/system/README.md.';

String _strayFab(String path) =>
    '$path fills a Scaffold floatingActionButton slot outside '
    'presentation/screens, where the FAB clearance check does not look. Move '
    'it into a screen, or allow it in this test with a reason.';

void main() {
  late final Map<String, String> code;

  setUpAll(() {
    code = {
      for (final path in libDartFiles())
        path: stripCommentsAndStrings(File(path).readAsStringSync()),
    };
  });

  group('FAB clearance', () {
    test('every screen with a FAB uses the shared FAB clearance', () {
      final missing = [
        for (final entry in code.entries)
          if (_isScreen(entry.key) &&
              _declaresFab.hasMatch(entry.value) &&
              !_usesClearance.hasMatch(entry.value))
            entry.key,
      ];
      expect(missing, isEmpty, reason: missing.map(_noClearance).join('\n'));
    });

    test('no Scaffold FAB hides outside presentation/screens', () {
      final stray = [
        for (final entry in code.entries)
          if (!_isScreen(entry.key) &&
              _usesFabSlot.hasMatch(entry.value) &&
              !_slotOutsideScreens.contains(entry.key))
            entry.key,
      ];
      expect(stray, isEmpty, reason: stray.map(_strayFab).join('\n'));
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
