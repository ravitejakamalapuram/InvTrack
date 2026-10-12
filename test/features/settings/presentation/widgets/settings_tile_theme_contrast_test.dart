// A settings tile paints its icon on a 15% disc of the same colour. When the
// icon needs a deeper colour to read (the danger zone's amber), the disc keeps
// the bright one: [SettingsNavTile.iconTint]. Without it the disc follows the
// icon, as before.
//
// This tests the tile with colours it is handed. That the shipped screens hand
// it the right ones is measured in
// screens/data_management_theme_contrast_test.dart, which pumps them.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_theme.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_tile.dart';

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

  testWidgets('iconTint tints the disc and iconColor colours the icon', (
    tester,
  ) async {
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

    final icon = tester.widget<Icon>(find.byIcon(Icons.person_remove_outlined));
    expect(icon.color, AppColors.warningTextLight);
    expect(_disc(tester), AppColors.warningLight.withValues(alpha: 0.15));
    // The tile is titled: colour is not the only carrier.
    expect(find.text('Delete guest data'), findsOneWidget);
  });

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
