// A40 (#783) PR-2: the layout of the add investment form behind the first
// investment flow. At phone width, at 320dp with text at 1.8x, with a 250dp
// keyboard, in light and dark: nothing overflows, every slot can be scrolled
// to, and the submit button is pinned above the keyboard and can be tapped.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/app_text_field.dart';
import 'package:inv_tracker/core/widgets/more_details_tile.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/add_investment_keys.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/first_investment_form_view.dart';

import '../../../../helpers/inter_font.dart';

class _Case {
  const _Case(this.name, this.size, this.textScale, this.keyboard);
  final String name;
  final Size size;
  final double textScale;
  final double keyboard;
}

const _cases = [
  _Case('411 x 842', Size(411, 842), 1.0, 0),
  _Case('411 x 842, keyboard', Size(411, 842), 1.0, 250),
  _Case('320 x 568, text 1.8x, keyboard', Size(320, 568), 1.8, 250),
];

Widget _host({
  required Brightness brightness,
  required double textScale,
  required VoidCallback onSubmit,
  required VoidCallback onClose,
  bool moreOpen = true,
  bool isLoading = false,
  Widget? customType,
}) {
  final formKey = GlobalKey<FormState>();
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: FirstInvestmentFormView(
      formKey: formKey,
      title: 'Add Investment',
      closeTooltip: 'Close',
      onClose: onClose,
      typeLabel: 'Investment Type',
      typeRow: const SizedBox(
        key: Key('slot-type-row'),
        height: 64,
        child: Center(child: Text('chips')),
      ),
      customType: customType,
      name: const AppTextField(
        key: Key('slot-name'),
        label: 'Investment Name',
        hint: 'e.g. LenDenClub, Grip Invest',
      ),
      amount: const AppTextField(
        key: Key('slot-amount'),
        label: 'Amount invested in INR',
        prefixText: '₹',
      ),
      startDate: const AppTextField(
        key: Key('slot-date'),
        label: 'Start Date',
        readOnly: true,
      ),
      moreDetails: MoreDetailsTile(
        key: const Key('slot-more'),
        title: 'More details',
        summary: 'Currency, rate, term, notes and more',
        expanded: moreOpen,
        onChanged: (_) {},
        children: [
          for (var i = 0; i < 6; i++) ...[
            AppTextField(label: 'Optional field $i'),
            const SizedBox(height: 20),
          ],
          const Text('LAST SLOT', key: Key('slot-last')),
        ],
      ),
      submitLabel: 'Add Investment',
      isLoading: isLoading,
      onSubmit: onSubmit,
    ),
  );
}

void _size(WidgetTester tester, _Case c) {
  tester.view.physicalSize = c.size;
  tester.view.devicePixelRatio = 1.0;
  tester.view.viewInsets = FakeViewPadding(bottom: c.keyboard);
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(loadInterFont);

  for (final brightness in Brightness.values) {
    for (final c in _cases) {
      group('${brightness.name}, ${c.name}', () {
        testWidgets('lays out without an overflow', (tester) async {
          _size(tester, c);
          await tester.pumpWidget(
            _host(
              brightness: brightness,
              textScale: c.textScale,
              onSubmit: () {},
              onClose: () {},
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Add Investment'), findsWidgets);
        });

        testWidgets('the submit button is above the keyboard and taps once', (
          tester,
        ) async {
          _size(tester, c);
          var submits = 0;
          await tester.pumpWidget(
            _host(
              brightness: brightness,
              textScale: c.textScale,
              onSubmit: () => submits++,
              onClose: () {},
            ),
          );
          await tester.pumpAndSettle();

          final button = tester.getRect(find.byKey(AddInvestmentKeys.submit));
          expect(button.bottom, lessThanOrEqualTo(c.size.height - c.keyboard));
          expect(button.left, greaterThanOrEqualTo(24.0));
          expect(button.right, lessThanOrEqualTo(c.size.width - 24.0));
          expect(button.height, greaterThanOrEqualTo(48.0));

          // No warnIfMissed: false. The tap must land on the button.
          await tester.tap(find.byKey(AddInvestmentKeys.submit));
          expect(submits, 1);
        });

        testWidgets('every slot can be scrolled to, the button stays put', (
          tester,
        ) async {
          _size(tester, c);
          await tester.pumpWidget(
            _host(
              brightness: brightness,
              textScale: c.textScale,
              onSubmit: () {},
              onClose: () {},
            ),
          );
          await tester.pumpAndSettle();
          final before = tester.getRect(find.byKey(AddInvestmentKeys.submit));

          for (final key in const [
            Key('slot-type-row'),
            Key('slot-name'),
            Key('slot-amount'),
            Key('slot-date'),
            Key('slot-more'),
            Key('slot-last'),
          ]) {
            await tester.ensureVisible(find.byKey(key));
            await tester.pumpAndSettle();
            final rect = tester.getRect(find.byKey(key));
            final visibleBottom = before.top;
            expect(rect.top, lessThan(visibleBottom), reason: '$key');
            expect(tester.takeException(), isNull, reason: '$key');
          }
          expect(tester.getRect(find.byKey(AddInvestmentKeys.submit)), before);
          // The last slot ends above the pinned button.
          expect(
            tester.getRect(find.byKey(const Key('slot-last'))).bottom,
            lessThanOrEqualTo(before.top),
          );
        });
      });
    }
  }

  testWidgets('slots sit 24px in, with one form gap between them', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(
        brightness: Brightness.light,
        textScale: 1.0,
        onSubmit: () {},
        onClose: () {},
        moreOpen: false,
      ),
    );
    await tester.pumpAndSettle();

    final name = tester.getRect(find.byKey(const Key('slot-name')));
    final amount = tester.getRect(find.byKey(const Key('slot-amount')));
    final date = tester.getRect(find.byKey(const Key('slot-date')));
    final more = tester.getRect(find.byKey(const Key('slot-more')));
    for (final rect in [name, amount, date, more]) {
      expect(rect.left, 24.0);
      expect(rect.right, 411.0 - 24.0);
    }
    expect(amount.top - name.bottom, 20.0);
    expect(date.top - amount.bottom, 20.0);
    expect(more.top - date.bottom, 20.0);
    // The chip row is full width: it runs to both screen edges.
    final row = tester.getRect(find.byKey(const Key('slot-type-row')));
    expect(row.left, 0.0);
    expect(row.right, 411.0);
  });

  testWidgets('the custom type field comes before the name when given', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(
        brightness: Brightness.light,
        textScale: 1.0,
        onSubmit: () {},
        onClose: () {},
        moreOpen: false,
        customType: const SizedBox(key: Key('slot-custom'), height: 80),
      ),
    );
    await tester.pumpAndSettle();

    final custom = tester.getRect(find.byKey(const Key('slot-custom')));
    final name = tester.getRect(find.byKey(const Key('slot-name')));
    expect(custom.bottom, lessThan(name.top));
    expect(name.top - custom.bottom, 20.0);
  });

  testWidgets('a pending save shows the progress and blocks the button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 842);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    var submits = 0;
    await tester.pumpWidget(
      _host(
        brightness: Brightness.light,
        textScale: 1.0,
        onSubmit: () => submits++,
        onClose: () {},
        isLoading: true,
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byKey(AddInvestmentKeys.submit), warnIfMissed: false);
    expect(submits, 0);
  });

  testWidgets('the close button calls onClose, and has a tooltip', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 842);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    var closes = 0;
    await tester.pumpWidget(
      _host(
        brightness: Brightness.light,
        textScale: 1.0,
        onSubmit: () {},
        onClose: () => closes++,
      ),
    );

    await tester.tap(find.byTooltip('Close'));

    expect(closes, 1);
  });

  testWidgets('the form scrolls under the pinned button, not over it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(
        brightness: Brightness.light,
        textScale: 1.0,
        onSubmit: () {},
        onClose: () {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MoreDetailsTile), findsOneWidget);
    final scroll = tester.getRect(find.byType(SingleChildScrollView));
    final button = tester.getRect(find.byKey(AddInvestmentKeys.submit));
    expect(scroll.bottom, lessThanOrEqualTo(button.top));
  });
}
