import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/expandable_text.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

Widget _wrap(Widget child, {double width = 200}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Center(
      child: SizedBox(width: width, child: child),
    ),
  ),
);

void main() {
  const long =
      'A long tip body that goes on and on and on and on and on and on '
      'and on and on and on and on and on and on and on and on and on.';

  testWidgets('short text shows no toggle', (tester) async {
    await tester.pumpWidget(_wrap(const ExpandableText('Short')));
    expect(find.text('Read more'), findsNothing);
  });

  testWidgets('long text is cut to 3 lines, toggles, and keeps all text', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const ExpandableText(long)));
    expect(find.text('Read more'), findsOneWidget);
    expect(tester.widget<Text>(find.text(long)).maxLines, 3);

    await tester.tap(find.text('Read more'));
    await tester.pump();
    expect(tester.widget<Text>(find.text(long)).maxLines, isNull);
    expect(find.text('Show less'), findsOneWidget);

    await tester.tap(find.text('Show less'));
    await tester.pump();
    expect(find.text('Read more'), findsOneWidget);
  });

  testWidgets('toggle has a button role and 48dp height', (tester) async {
    final h = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(const ExpandableText(long)));
    expect(
      tester.getSize(find.byType(InkWell)).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSemantics(find.text('Read more')),
      matchesSemantics(
        label: 'Read more',
        isButton: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );
    h.dispose();
  });

  testWidgets('new text starts collapsed again', (tester) async {
    await tester.pumpWidget(_wrap(const ExpandableText(long)));
    await tester.tap(find.text('Read more'));
    await tester.pump();
    expect(find.text('Show less'), findsOneWidget);

    await tester.pumpWidget(_wrap(ExpandableText('$long next day')));
    expect(find.text('Read more'), findsOneWidget);
  });
}
