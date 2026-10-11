// The change line of a MetricTile paints the status colour of the theme it is
// in. In dark the light green and red lose their contrast on the dark card once
// the light values deepen, so the dark tile reads the dark values. The arrow
// and the text still say up or down, so colour is not the only carrier.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_theme.dart';
import 'package:inv_tracker/core/widgets/metric_tile.dart';

import '../../helpers/contrast.dart';

Future<void> _pump(
  WidgetTester tester,
  ThemeData theme, {
  required bool positive,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: MetricTile(
          label: 'Total Return',
          value: '12%',
          change: '+3%',
          isPositive: positive,
        ),
      ),
    ),
  );
}

Color _arrow(WidgetTester tester, IconData icon) =>
    tester.widget<Icon>(find.byIcon(icon)).color!;

Color _change(WidgetTester tester) =>
    tester.widget<Text>(find.text('+3%')).style!.color!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('a rising tile', () {
    testWidgets('in dark: arrow and change are the dark green', (tester) async {
      await _pump(tester, AppTheme.darkTheme, positive: true);

      expect(_arrow(tester, Icons.trending_up_rounded), AppColors.successDark);
      expect(_change(tester), AppColors.successDark);
      expect(
        contrastRatio(_change(tester), AppColors.cardDark),
        greaterThanOrEqualTo(kMinText),
      );
    });

    testWidgets('in light: unchanged, the light green', (tester) async {
      await _pump(tester, AppTheme.lightTheme, positive: true);

      expect(_arrow(tester, Icons.trending_up_rounded), AppColors.successLight);
      expect(_change(tester), AppColors.successLight);
    });
  });

  group('a falling tile', () {
    testWidgets('in dark: arrow and change are the dark red', (tester) async {
      await _pump(tester, AppTheme.darkTheme, positive: false);

      expect(_arrow(tester, Icons.trending_down_rounded), AppColors.dangerDark);
      expect(_change(tester), AppColors.dangerDark);
      expect(
        contrastRatio(_change(tester), AppColors.cardDark),
        greaterThanOrEqualTo(kMinText),
      );
    });

    testWidgets('in light: unchanged, the light red', (tester) async {
      await _pump(tester, AppTheme.lightTheme, positive: false);

      expect(
        _arrow(tester, Icons.trending_down_rounded),
        AppColors.dangerLight,
      );
      expect(_change(tester), AppColors.dangerLight);
    });
  });
}
