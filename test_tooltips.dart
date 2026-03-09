import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    final content = file.readAsStringSync();

    // Find all IconButton widget constructions
    var pattern = RegExp(r'IconButton\s*\(');
    var matches = pattern.allMatches(content);

    for (var match in matches) {
      var index = match.start;

      // Find matching closing parenthesis
      var parenCount = 0;
      var closeIndex = index;
      var started = false;
      while (closeIndex < content.length) {
        if (content[closeIndex] == '(') {
          parenCount++;
          started = true;
        }
        else if (content[closeIndex] == ')') {
          parenCount--;
        }
        closeIndex++;
        if (started && parenCount == 0) break;
      }

      final body = content.substring(index, closeIndex);
      if (!body.contains('tooltip:')) {
        print('${file.path}:\n$body\n---\n');
      }
    }
  }
}
