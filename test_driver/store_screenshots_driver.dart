// Driver for `flutter drive` that persists integration_test screenshots to
// disk. The plain `integrationDriver()` used by test_driver/integration_test.dart
// discards screenshot bytes; this one writes each to SCREENSHOT_OUTPUT_DIR
// (falls back to build/store_screenshots) as `<name>.png`.
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final outputDir =
      Platform.environment['SCREENSHOT_OUTPUT_DIR'] ?? 'build/store_screenshots';
  await Directory(outputDir).create(recursive: true);

  await integrationDriver(
    onScreenshot: (String name, List<int> image, [Map<String, Object?>? args]) async {
      final file = File('$outputDir/$name.png');
      await file.writeAsBytes(image);
      // ignore: avoid_print
      print('Saved screenshot: ${file.path}');
      return true;
    },
  );
}
