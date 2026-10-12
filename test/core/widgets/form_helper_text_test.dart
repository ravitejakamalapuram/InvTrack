// A40 (#783) PR-2: the 12px line under a form field (a hint, a readout, a
// helper). It is muted, sits 6px under the box and 16px in from its edge, and
// says to a screen reader what it shows, or what the caller says instead.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/widgets/form_helper_text.dart';

Widget _host(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: child),
      ),
    );

void main() {
  testWidgets('shows its text 16px in and 6px down', (tester) async {
    await tester.pumpWidget(_host(const FormHelperText('Optional.')));

    final rect = tester.getRect(find.text('Optional.'));
    expect(find.text('Optional.'), findsOneWidget);
    expect(rect.left, 16.0);
    expect(rect.top, 6.0);
  });

  testWidgets('is 12px, muted in light, muted in dark', (tester) async {
    await tester.pumpWidget(_host(const FormHelperText('Optional.')));
    var style = tester.widget<Text>(find.text('Optional.')).style!;
    expect(style.fontSize, 12.0);
    expect(style.fontWeight, FontWeight.w400);
    expect(style.height, 1.4);
    expect(style.color, AppColors.neutral500Light);

    await tester.pumpWidget(
      _host(const FormHelperText('Optional.'), brightness: Brightness.dark),
    );
    await tester.pumpAndSettle(); // the theme change animates
    style = tester.widget<Text>(find.text('Optional.')).style!;
    expect(style.color, AppColors.neutral400Dark);
  });

  testWidgets('emphasized is heavier and darker', (tester) async {
    await tester.pumpWidget(
      _host(const FormHelperText('₹1 L', emphasized: true)),
    );

    final style = tester.widget<Text>(find.text('₹1 L')).style!;
    expect(style.fontWeight, FontWeight.w600);
    expect(style.color, AppColors.neutral600Light);
  });

  testWidgets('a screen reader hears the label when there is one', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        const FormHelperText(
          '₹1.5 L',
          emphasized: true,
          semanticsLabel: '1.5 lakh rupees',
        ),
      ),
    );

    expect(find.bySemanticsLabel('1.5 lakh rupees'), findsOneWidget);
    expect(find.bySemanticsLabel('₹1.5 L'), findsNothing);
    handle.dispose();
  });

  testWidgets('wraps long text instead of overflowing', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        const FormHelperText(
          'Today. Also the date of your first cash flow, which is why it '
          'cannot be after today.',
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.byType(FormHelperText)).right,
      lessThanOrEqualTo(320),
    );
  });
}
