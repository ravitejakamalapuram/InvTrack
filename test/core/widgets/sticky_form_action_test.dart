// A40 (#783) PR-2: the submit action of a long form stays in view. It has its
// own background and a hairline above it, keeps clear of the system bars, and
// lets the form scroll behind it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/widgets/sticky_form_action.dart';

Widget _host({Brightness brightness = Brightness.light, double? width}) =>
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: Column(
          children: [
            const Expanded(child: SizedBox.expand()),
            SizedBox(
              width: width,
              child: StickyFormAction(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text('Add Investment'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

void main() {
  testWidgets('wraps the action in 16 x 24 padding and a 1px top border', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 842);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host());

    final bar = tester.getRect(find.byType(StickyFormAction));
    final button = tester.getRect(find.byType(ElevatedButton));
    expect(bar.width, 411.0);
    expect(button.left - bar.left, 24.0);
    expect(bar.right - button.right, 24.0);
    // 16 + 56 + 16; the 1px line is painted inside the top padding.
    expect(bar.height, 88.0);
    expect(button.top - bar.top, 16.0);
    expect(bar.bottom, 842.0);
  });

  testWidgets('keeps the action clear of a system bar at the bottom', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 842);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host());

    final button = tester.getRect(find.byType(ElevatedButton));
    expect(button.bottom, 842.0 - 34 - 16);
  });

  testWidgets('as a Scaffold bottom bar it rides above the keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 842);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(bottom: 34);
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: StickyFormAction(
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('Add Investment'),
              ),
            ),
          ),
        ),
      ),
    );

    final button = tester.getRect(find.byType(ElevatedButton));
    // 16 below the button, then the keyboard; the system bar is under it.
    expect(button.bottom, 842.0 - 250 - 16);
  });

  testWidgets('a floating snackbar appears above the bar, not over it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 842);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    late BuildContext context;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) {
              context = c;
              return const SizedBox.expand();
            },
          ),
          bottomNavigationBar: StickyFormAction(
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('Add Investment'),
              ),
            ),
          ),
        ),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not add this investment.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await tester.pumpAndSettle();

    final bar = tester.getRect(find.byType(StickyFormAction));
    final snack = tester.getRect(find.byType(SnackBar));
    expect(snack.bottom, lessThanOrEqualTo(bar.top));
  });

  testWidgets('has an opaque background of the screen, in both themes', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    var material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(StickyFormAction),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, AppColors.backgroundLight);

    await tester.pumpWidget(_host(brightness: Brightness.dark));
    await tester.pumpAndSettle(); // the theme change animates
    material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(StickyFormAction),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, AppColors.backgroundDark);
  });

  testWidgets('the action can be tapped', (tester) async {
    tester.view.physicalSize = const Size(411, 842);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const Expanded(child: SizedBox.expand()),
              StickyFormAction(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => taps++,
                    child: const Text('Add Investment'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Add Investment'));

    expect(taps, 1);
  });
}
