// The FY PDF is deliberately unmasked, so with privacy mode on the export must
// first ask the user to confirm; Cancel must not start the export.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/reports/presentation/providers/fy_report_provider.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/fy_pdf_export_button.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('privacy on: confirm dialog shows; Cancel does not export', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'privacy_mode_enabled': true});
    final prefs = await SharedPreferences.getInstance();
    var reportReads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          fyReportProvider.overrideWith((ref, year) {
            reportReads++;
            return Future.any<Never>([]);
          }),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: FyPdfExportButton(fyYear: 2025)),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.picture_as_pdf_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Export anyway'), findsOneWidget);
    expect(
      find.textContaining('even though privacy mode is on'),
      findsOneWidget,
    );
    for (final label in ['Cancel', 'Export anyway']) {
      final size = tester.getSize(find.widgetWithText(TextButton, label));
      expect(size.height, greaterThanOrEqualTo(48));
    }

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Export anyway'), findsNothing);
    expect(reportReads, 0);
  });
}
