// A49 (#806, UX-09): a screen reader reads a slider's real value ("30 years",
// "4.0%"), not its position in the range ("23%", "60%").
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/fire_number/presentation/screens/fire_setup_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('FIRE setup sliders announce years, not a percentage of the '
      'range', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currencyCodeProvider.overrideWith((ref) => 'INR'),
          currencySymbolProvider.overrideWith((ref) => '₹'),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const FireSetupScreen()),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final values = [
      for (final e in tester.widgetList<Slider>(find.byType(Slider)))
        tester.getSemantics(find.byWidget(e)).value,
    ];
    expect(values, isNotEmpty);
    for (final v in values) {
      expect(v, contains('years'), reason: 'read "$v"');
    }
    handle.dispose();
  });
}
