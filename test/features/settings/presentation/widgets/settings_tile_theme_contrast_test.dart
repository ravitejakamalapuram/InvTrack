// A settings tile paints its icon on a 15% disc of the same colour. When the
// icon needs a deeper colour to read (the danger zone's amber), the disc keeps
// the bright one: [SettingsNavTile.iconTint]. Without it the disc follows the
// icon, as before.
//
// The ids in the test names are rows of test/core/theme/contrast_pairs.dart;
// the guard finds them here.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_theme.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_tile.dart';

import '../../../../helpers/contrast.dart';

Future<void> _pump(WidgetTester tester, Widget tile) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: tile),
  ),
);

Color _disc(WidgetTester tester) {
  final box = tester
      .widgetList<Container>(
        find.ancestor(
          of: find.byIcon(Icons.person_remove_outlined),
          matching: find.byType(Container),
        ),
      )
      .map((c) => c.decoration)
      .whereType<BoxDecoration>()
      .firstWhere((d) => d.color != null);
  return box.color!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets(
    'settings-tile-warning-icon-light@tint15: the icon takes the amber text '
    'colour and the disc keeps the bright amber',
    (tester) async {
      await _pump(
        tester,
        SettingsNavTile(
          icon: Icons.person_remove_outlined,
          iconColor: AppColors.warningTextLight,
          iconTint: AppColors.warningLight,
          title: 'Delete guest data',
          onTap: () {},
        ),
      );

      final icon = tester.widget<Icon>(
        find.byIcon(Icons.person_remove_outlined),
      );
      expect(icon.color, AppColors.warningTextLight);
      final disc = _disc(tester);
      expect(disc, AppColors.warningLight.withValues(alpha: 0.15));
      expect(
        contrastRatio(
          AppColors.warningTextLight,
          composeOver(disc, AppColors.cardLight),
        ),
        greaterThanOrEqualTo(kMinGraphic),
        reason: 'settings-tile-warning-icon-light@tint15',
      );
      // The tile is titled: colour is not the only carrier.
      expect(find.text('Delete guest data'), findsOneWidget);
    },
  );

  testWidgets('without iconTint the disc follows the icon colour', (
    tester,
  ) async {
    await _pump(
      tester,
      SettingsNavTile(
        icon: Icons.person_remove_outlined,
        iconColor: AppColors.successLight,
        title: 'Demo',
        onTap: () {},
      ),
    );

    expect(_disc(tester), AppColors.successLight.withValues(alpha: 0.15));
  });

  testWidgets('without either, the icon and disc are the primary colour', (
    tester,
  ) async {
    await _pump(
      tester,
      SettingsNavTile(
        icon: Icons.person_remove_outlined,
        title: 'Demo',
        onTap: () {},
      ),
    );

    expect(
      tester.widget<Icon>(find.byIcon(Icons.person_remove_outlined)).color,
      AppColors.primaryLight,
    );
    expect(_disc(tester), AppColors.primaryLight.withValues(alpha: 0.15));
  });
}
