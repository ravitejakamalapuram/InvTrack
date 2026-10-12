// The import screen paints its header icon and the "fill in your data" icon in
// the accent. In light they are the deeper blue text colour, which reads on the
// card; in dark the dark blue. The step number's circle is a fill and keeps the
// bright blue.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_theme.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/bulk_import/presentation/screens/bulk_import_screen.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../../../helpers/contrast.dart';

class _TestSecurityNotifier extends SecurityNotifier {
  @override
  SecurityState build() => const SecurityState();
}

class _Privacy extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

Future<void> _pump(WidgetTester tester, ThemeData theme) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currencyCodeProvider.overrideWithValue('INR'),
        securityProvider.overrideWith(_TestSecurityNotifier.new),
        privacyModeProvider.overrideWith(_Privacy.new),
        allInvestmentsProvider.overrideWith((ref) => Stream.value(const [])),
        allCashFlowsStreamProvider.overrideWith(
          (ref) => Stream.value(const []),
        ),
        archivedInvestmentsProvider.overrideWith(
          (ref) => Stream.value(const []),
        ),
      ],
      child: MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const BulkImportScreen(),
      ),
    ),
  );
  await tester.pump();
}

Color _icon(WidgetTester tester, IconData icon) =>
    tester.widget<Icon>(find.byIcon(icon).first).color!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('in light the icons are the deeper blue and read on the card', (
    tester,
  ) async {
    await _pump(tester, AppTheme.lightTheme);

    for (final icon in [Icons.upload_file_rounded, Icons.edit_document]) {
      final color = _icon(tester, icon);
      expect(color, AppColors.accentTextLight, reason: '$icon');
      expect(
        contrastRatio(color, AppColors.cardLight),
        greaterThanOrEqualTo(kMinGraphic),
        reason: '$icon on the card',
      );
    }
    // The step circles are fills: the bright blue under a white digit.
    final circles = tester.widgetList<CircleAvatar>(find.byType(CircleAvatar));
    expect(circles, isNotEmpty);
    expect(
      circles.where((c) => c.backgroundColor == AppColors.accentLight),
      isNotEmpty,
    );
  });

  testWidgets('in dark the icons are the dark blue', (tester) async {
    await _pump(tester, AppTheme.darkTheme);

    for (final icon in [Icons.upload_file_rounded, Icons.edit_document]) {
      expect(_icon(tester, icon), AppColors.accentDark, reason: '$icon');
    }
  });
}
