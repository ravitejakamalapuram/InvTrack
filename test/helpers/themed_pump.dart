// Shared by the widget tests that measure a pair from
// test/core/theme/contrast_pairs.dart: pump a widget in one theme and read the
// colour it really paints and the ground it really sits on.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/theme/app_theme.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import 'contrast.dart';

ThemeData themeFor(Brightness brightness) =>
    brightness == Brightness.dark ? AppTheme.darkTheme : AppTheme.lightTheme;

/// Pumps [child] under the app theme of [brightness], with the app's strings
/// and a provider scope.
Future<void> pumpThemed(
  WidgetTester tester,
  Widget child, {
  required Brightness brightness,
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: themeFor(brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: child)),
      ),
    ),
  );
  await tester.pump();
}

/// The colour [finder]'s text is really painted in, after the default text
/// style it inherits.
Color paintedTextColor(WidgetTester tester, Finder finder) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  return paragraph.text.style!.color!;
}

/// The colour an [Icon] is really painted in, after the icon theme.
Color paintedIconColor(WidgetTester tester, Finder finder) {
  final icon = tester.widget<Icon>(finder);
  if (icon.color != null) return icon.color!;
  return IconTheme.of(tester.element(finder)).color!;
}

/// The ground behind [target]: the fills of the decorated boxes around it,
/// outermost first, each composed over what is under it, starting from [page].
Color groundBehind(WidgetTester tester, Finder target, Color page) {
  final fills = <Color>[];
  for (final element
      in find
          .ancestor(of: target, matching: find.byType(DecoratedBox))
          .evaluate()) {
    final decoration = (element.widget as DecoratedBox).decoration;
    if (decoration is BoxDecoration && decoration.color != null) {
      fills.add(decoration.color!);
    }
  }
  var ground = page;
  for (final fill in fills.reversed) {
    ground = composeOver(fill, ground);
  }
  return ground;
}
