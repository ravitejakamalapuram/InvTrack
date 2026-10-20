/// A66 (#813): the report export code (CSV/PDF exporters, export button and
/// providers) was unreachable from the app and has been deleted together with
/// the `pdf` package. These plain file checks keep it from coming back by
/// accident: a report export would need a new, reachable entry point.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const removedFiles = [
    'lib/features/reports/data/services/report_csv_exporter.dart',
    'lib/features/reports/data/services/report_pdf_exporter.dart',
    'lib/features/reports/domain/services/report_export_service.dart',
    'lib/features/reports/presentation/providers/report_export_providers.dart',
    'lib/features/reports/presentation/widgets/report_export_button.dart',
    'lib/features/reports/presentation/providers/goal_progress_provider.dart',
  ];

  test('the unreachable report export files stay deleted', () {
    for (final path in removedFiles) {
      expect(File(path).existsSync(), isFalse, reason: '$path was re-added');
    }
  });

  test('the pdf package is not a dependency and nothing imports it', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(RegExp(r'^\s+pdf:', multiLine: true).hasMatch(pubspec), isFalse);

    // Only import/export directives count, not comments or strings.
    final directive = RegExp(
      r'''^\s*(?:import|export)\s+['"]package:pdf/''',
      multiLine: true,
    );
    final importers = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => directive.hasMatch(f.readAsStringSync()))
        .map((f) => f.path)
        .toList();
    expect(importers, isEmpty);
  });
}
