// The "Back online" toast is a success-coloured fill under a wifi icon and a
// label. In dark the fill is the bright green, so both take the ink colour
// (white was 1.92:1); in light they stay white on the deep green.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/connectivity_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/widgets/connectivity_listener.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../helpers/contrast.dart';

Future<void> _check(
  WidgetTester tester,
  Brightness brightness,
  Color fill,
  Color ink,
) async {
  final controller = StreamController<bool>();
  addTearDown(controller.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        connectivityStatusProvider.overrideWith((ref) => controller.stream),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(brightness: brightness),
        home: const ConnectivityListener(child: Scaffold(body: Text('App'))),
      ),
    ),
  );
  controller.add(false);
  await tester.pump();
  controller.add(true);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));

  final icon = tester.widget<Icon>(find.byIcon(Icons.wifi_rounded)).color!;
  final label = tester.widget<Text>(find.text('Back online')).style!.color!;
  expect(icon, ink);
  expect(label, ink);
  expect(contrastRatio(icon, fill), greaterThanOrEqualTo(kMinGraphic));
  expect(contrastRatio(label, fill), greaterThanOrEqualTo(kMinText));
  await tester.pump(const Duration(seconds: 4));
}

void main() {
  testWidgets('in dark the icon and label are ink on the bright green', (
    tester,
  ) async {
    await _check(
      tester,
      Brightness.dark,
      AppColors.successDark,
      AppColors.neutral900Light,
    );
  });

  testWidgets('in light they stay white on the deep green', (tester) async {
    await _check(
      tester,
      Brightness.light,
      AppColors.successLight,
      Colors.white,
    );
  });
}
