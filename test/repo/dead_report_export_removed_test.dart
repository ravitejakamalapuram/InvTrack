/// A66 (#813): the report export code (CSV/PDF exporters, export button and
/// providers) was unreachable from the app and has been deleted together with
/// the `pdf` package. These plain file checks keep it from coming back by
/// accident: a report export would need a new, reachable entry point.
///
/// #800 adds exactly that: the Tax-Year PDF, imported by the report screen
/// through [FyPdfExportButton]. The `pdf` package is therefore allowed, but
/// only in that one service, and the service must stay reachable.
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

  test('the pdf package is used only by the reachable Tax-Year PDF service', () {
    const allowed =
        'lib/features/reports/data/services/fy_report_pdf_service.dart';

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
    expect(importers, [allowed]);

    // Reachable: the report screen imports the button, which imports the
    // service.
    expect(
      File(
        'lib/features/reports/presentation/screens/dynamic_report_screen.dart',
      ).readAsStringSync(),
      contains('fy_pdf_export_button.dart'),
    );
    expect(
      File(
        'lib/features/reports/presentation/widgets/fy_pdf_export_button.dart',
      ).readAsStringSync(),
      contains('fy_report_pdf_service.dart'),
    );
  });
}
