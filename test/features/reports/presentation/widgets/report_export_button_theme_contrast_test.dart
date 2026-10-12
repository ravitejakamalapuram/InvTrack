// The export menu shows a CSV icon in the primary colour and a PDF icon in the
// accent. The accent in light was the bright blue (2.77:1 on the menu); it is the
// deeper blue now, and the dark blue in dark. Both items are worded.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_theme.dart';
import 'package:inv_tracker/features/reports/domain/services/report_export_service.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/report_export_button.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../../../helpers/contrast.dart';

Future<void> _openMenu(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          appBar: AppBar(
            actions: [
              ReportExportButton(
                reportData: null,
                reportType: ReportType.values.first,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byIcon(Icons.download_rounded));
  await tester.pumpAndSettle();
}

Color _pdfIcon(WidgetTester tester) =>
    tester.widget<Icon>(find.byIcon(Icons.picture_as_pdf_rounded)).color!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets(
    'in light the PDF icon is the deeper blue and reads on the menu',
    (tester) async {
      await _openMenu(tester, AppTheme.lightTheme);

      expect(_pdfIcon(tester), AppColors.accentTextLight);
      expect(
        contrastRatio(_pdfIcon(tester), AppColors.cardLight),
        greaterThanOrEqualTo(kMinGraphic),
      );
      // The item says what it is.
      expect(find.text('Export as PDF'), findsOneWidget);
    },
  );

  testWidgets('in dark the PDF icon is the dark blue, as it was', (
    tester,
  ) async {
    await _openMenu(tester, AppTheme.darkTheme);

    expect(_pdfIcon(tester), AppColors.accentDark);
    expect(_pdfIcon(tester), AppTheme.darkTheme.colorScheme.secondary);
  });
}
