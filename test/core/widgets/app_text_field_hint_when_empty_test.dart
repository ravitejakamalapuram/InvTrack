// A40 (#783) PR-2: an AppTextField can show its hint and its prefix while it is
// empty and not focused (showHintWhenEmpty), as the add investment form's
// "e.g. 1,00,000" under a rupee sign. By default the label sits inside the
// empty field and hides both until the field is focused, as before.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/app_text_field.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

Widget _host({
  bool showHintWhenEmpty = false,
  TextEditingController? controller,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: AppTextField(
      controller: controller,
      label: 'Amount invested in INR',
      hint: 'e.g. 1,00,000',
      prefixText: '₹',
      showHintWhenEmpty: showHintWhenEmpty,
    ),
  ),
);

double _opacityOf(WidgetTester tester, String text) => tester
    .widget<AnimatedOpacity>(
      find
          .ancestor(of: find.text(text), matching: find.byType(AnimatedOpacity))
          .first,
    )
    .opacity;

void main() {
  testWidgets('default: the empty field hides its hint and prefix', (
    tester,
  ) async {
    await tester.pumpWidget(_host());

    expect(_opacityOf(tester, 'e.g. 1,00,000'), 0.0);
    expect(_opacityOf(tester, '₹'), 0.0);
    // The label sits inside the field as well as above it.
    expect(find.text('Amount invested in INR'), findsNWidgets(2));
  });

  testWidgets('showHintWhenEmpty: hint and prefix show, one label only', (
    tester,
  ) async {
    await tester.pumpWidget(_host(showHintWhenEmpty: true));

    expect(_opacityOf(tester, 'e.g. 1,00,000'), 1.0);
    expect(_opacityOf(tester, '₹'), 1.0);
    expect(find.text('Amount invested in INR'), findsOneWidget);
  });

  testWidgets('showHintWhenEmpty: typing hides the hint, keeps the prefix', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(showHintWhenEmpty: true, controller: controller),
    );

    await tester.enterText(find.byType(TextField), '5');
    await tester.pumpAndSettle();

    expect(_opacityOf(tester, '₹'), 1.0);
    expect(controller.text, '5');
    expect(_opacityOf(tester, 'e.g. 1,00,000'), 0.0);
  });

  testWidgets('showHintWhenEmpty: a screen reader still hears the label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(showHintWhenEmpty: true));

    final data = tester
        .getSemantics(
          find.bySemanticsLabel(RegExp('Amount invested in INR')).first,
        )
        .getSemanticsData();

    // The hint, an example, is read after the label.
    expect(data.label, 'Amount invested in INR\ne.g. 1,00,000');
    expect(data.flagsCollection.isTextField, isTrue);
    handle.dispose();
  });

  testWidgets('the label comes first for a screen reader either way', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host());
    final before = tester
        .getSemantics(
          find.bySemanticsLabel(RegExp('Amount invested in INR')).first,
        )
        .label
        .trim();

    await tester.pumpWidget(_host(showHintWhenEmpty: true));
    final after = tester
        .getSemantics(
          find.bySemanticsLabel(RegExp('Amount invested in INR')).first,
        )
        .label
        .trim();

    expect(after, startsWith(before));
    handle.dispose();
  });
}
