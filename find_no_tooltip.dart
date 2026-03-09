import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    final content = file.readAsStringSync();
    final regex = RegExp(r'IconButton\s*\((.*?)\)', dotAll: true);
    final matches = regex.allMatches(content);
    for (final match in matches) {
      final body = match.group(1)!;
      if (!body.contains('tooltip:')) {
        print('${file.path}: \n$body\n---');
      }
    }
  }
}
