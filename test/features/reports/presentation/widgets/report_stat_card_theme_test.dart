// ReportStatCard's default icon colour is the primary colour of the theme it is
// in: the deep indigo on the light card and the soft violet on the dark card.
// It was the other way round, so each theme painted the colour made for the
// other (violet at 3.3:1 on the white card, indigo at 2.99:1 on the dark one).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_theme.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/report_stat_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';

import '../../../../helpers/contrast.dart';

Future<void> _pump(
  WidgetTester tester,
  ThemeData theme, {
  Color? iconColor,
}) async {
  SharedPreferences.setMockInitialValues({'privacy_mode_enabled': false});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        theme: theme,
        home: Scaffold(
          body: ReportStatCard(
            icon: Icons.pie_chart_rounded,
            label: 'Invested',
            value: '12',
            iconColor: iconColor,
            isPrivacySensitive: false,
          ),
        ),
      ),
    ),
  );
}

Color _icon(WidgetTester tester) =>
    tester.widget<Icon>(find.byIcon(Icons.pie_chart_rounded)).color!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('in light the icon is primaryLight', (tester) async {
    await _pump(tester, AppTheme.lightTheme);
    expect(_icon(tester), AppColors.primaryLight);
    expect(
      contrastRatio(_icon(tester), AppColors.cardLight),
      greaterThanOrEqualTo(kMinGraphic),
    );
  });

  testWidgets('in dark the icon is primaryDark', (tester) async {
    await _pump(tester, AppTheme.darkTheme);
    expect(_icon(tester), AppColors.primaryDark);
    expect(
      contrastRatio(_icon(tester), AppColors.cardDark),
      greaterThanOrEqualTo(kMinGraphic),
    );
  });

  testWidgets('an icon colour the caller passes is kept in both themes', (
    tester,
  ) async {
    await _pump(tester, AppTheme.darkTheme, iconColor: AppColors.accentDark);
    expect(_icon(tester), AppColors.accentDark);
    await _pump(tester, AppTheme.lightTheme, iconColor: AppColors.accentLight);
    expect(_icon(tester), AppColors.accentLight);
  });
}
