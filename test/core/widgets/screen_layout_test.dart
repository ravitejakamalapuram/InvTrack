// The shared pieces that give Overview, Investments, Investment detail and
// Goals one left/right edge and a foot that clears the add button. Every
// measurement is a render box in dp on a 360dp wide, 1dp-per-pixel view, and
// any overflow fails the test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/widgets/screen_layout.dart';

const _width = 360.0;
const _height = 780.0;
const _edge = AppSpacing.screenEdge;

final _content = GlobalKey();

/// A scroll view on a 360 x 780dp view with [slivers], in [direction], at
/// [textScale], with [bottomInset] as the system bottom padding.
Future<ScrollController> _pump(
  WidgetTester tester, {
  required List<Widget> slivers,
  TextDirection direction = TextDirection.ltr,
  double textScale = 1.0,
  double bottomInset = 0,
}) async {
  tester.view
    ..physicalSize = const Size(_width, _height)
    ..devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAllTestValues();
  });
  final controller = ScrollController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => Directionality(
        textDirection: direction,
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(padding: EdgeInsets.only(bottom: bottomInset)),
          child: child!,
        ),
      ),
      home: Material(
        child: CustomScrollView(controller: controller, slivers: slivers),
      ),
    ),
  );
  return controller;
}

Future<void> _toEnd(WidgetTester tester, ScrollController controller) async {
  controller.jumpTo(controller.position.maxScrollExtent);
  await tester.pump();
}

/// How far the viewport's bottom is below [finder]'s bottom.
double _gapBelow(WidgetTester tester, Finder finder) =>
    tester.getRect(find.byType(CustomScrollView)).bottom -
    tester.getRect(finder).bottom;

Widget _tall() =>
    SliverToBoxAdapter(child: SizedBox(key: _content, height: 1500));

void main() {
  for (final direction in TextDirection.values) {
    group('ScreenSliver in ${direction.name}', () {
      testWidgets('starts and ends its content on the screen edge', (
        tester,
      ) async {
        await _pump(
          tester,
          direction: direction,
          slivers: [ScreenSliver(sliver: _tall())],
        );
        final rect = tester.getRect(find.byKey(_content));
        expect(rect.left, closeTo(_edge, 0.01));
        expect(rect.right, closeTo(_width - _edge, 0.01));
      });

      testWidgets('leaves md above the first item and md below the last', (
        tester,
      ) async {
        final controller = await _pump(
          tester,
          direction: direction,
          slivers: [ScreenSliver(sliver: _tall())],
        );
        expect(tester.getRect(find.byKey(_content)).top, closeTo(16, 0.01));
        await _toEnd(tester, controller);
        expect(_gapBelow(tester, find.byKey(_content)), closeTo(16, 0.01));
      });

      testWidgets('clearsFab leaves the FAB clearance below the last item', (
        tester,
      ) async {
        final controller = await _pump(
          tester,
          direction: direction,
          slivers: [ScreenSliver(clearsFab: true, sliver: _tall())],
        );
        await _toEnd(tester, controller);
        expect(
          _gapBelow(tester, find.byKey(_content)),
          closeTo(AppSpacing.fabBottomPadding, 0.01),
        );
        expect(AppSpacing.fabBottomPadding, 80);
      });

      testWidgets('clearsFab adds the bottom inset when nothing consumed it', (
        tester,
      ) async {
        final controller = await _pump(
          tester,
          direction: direction,
          bottomInset: 34,
          slivers: [ScreenSliver(clearsFab: true, sliver: _tall())],
        );
        await _toEnd(tester, controller);
        expect(_gapBelow(tester, find.byKey(_content)), closeTo(80 + 34, 0.01));
      });
    });

    group('ScreenEdge in ${direction.name}', () {
      testWidgets('insets its child by the edge on both sides', (tester) async {
        await _pump(
          tester,
          direction: direction,
          slivers: [
            SliverToBoxAdapter(
              child: ScreenEdge(
                top: 4,
                bottom: 8,
                child: SizedBox(key: _content, height: 50),
              ),
            ),
          ],
        );
        final rect = tester.getRect(find.byKey(_content));
        expect(rect.left, closeTo(_edge, 0.01));
        expect(rect.right, closeTo(_width - _edge, 0.01));
        expect(rect.top, closeTo(4, 0.01));
        expect(
          tester.getSize(find.byType(ScreenEdge)).height,
          closeTo(62, 0.01),
        );
      });
    });

    group('SliverFabClearance in ${direction.name}', () {
      testWidgets('is the FAB clearance high', (tester) async {
        final controller = await _pump(
          tester,
          direction: direction,
          slivers: [_tall(), const SliverFabClearance()],
        );
        await _toEnd(tester, controller);
        expect(_gapBelow(tester, find.byKey(_content)), closeTo(80, 0.01));
      });

      testWidgets('adds the bottom inset when nothing consumed it', (
        tester,
      ) async {
        final controller = await _pump(
          tester,
          direction: direction,
          bottomInset: 34,
          slivers: [_tall(), const SliverFabClearance()],
        );
        await _toEnd(tester, controller);
        expect(_gapBelow(tester, find.byKey(_content)), closeTo(80 + 34, 0.01));
      });
    });
  }

  group('ScreenSectionHeader', () {
    final badge = GlobalKey();

    Future<void> pumpHeader(
      WidgetTester tester, {
      required double textScale,
      required String badgeText,
      TextDirection direction = TextDirection.ltr,
    }) => _pump(
      tester,
      direction: direction,
      textScale: textScale,
      slivers: [
        SliverToBoxAdapter(
          child: ScreenEdge(
            child: ScreenSectionHeader(
              title: 'Goals',
              trailing: Container(key: badge, child: Text(badgeText)),
            ),
          ),
        ),
      ],
    );

    for (final direction in TextDirection.values) {
      testWidgets(
        'title starts on the edge, badge ends on it (${direction.name})',
        (tester) async {
          await pumpHeader(
            tester,
            textScale: 1.0,
            badgeText: '3 of 5',
            direction: direction,
          );
          final title = tester.getRect(find.text('Goals'));
          final trailing = tester.getRect(find.byKey(badge));
          if (direction == TextDirection.ltr) {
            expect(title.left, closeTo(_edge, 0.01));
            expect(trailing.right, closeTo(_width - _edge, 0.01));
          } else {
            expect(title.right, closeTo(_width - _edge, 0.01));
            expect(trailing.left, closeTo(_edge, 0.01));
          }
          // One line: the badge is level with the title.
          expect(trailing.center.dy, closeTo(title.center.dy, 1.0));
        },
      );
    }

    testWidgets('is a heading for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await pumpHeader(tester, textScale: 1.0, badgeText: '3 of 5');
        final node = tester.getSemantics(find.text('Goals'));
        expect(node.flagsCollection.isHeader, isTrue);
        expect(node.label, contains('Goals'));
      } finally {
        handle.dispose();
      }
    });

    testWidgets(
      'a long badge wraps below the title at text x2.0 without overflow',
      (tester) async {
        await pumpHeader(
          tester,
          textScale: 2.0,
          badgeText: '3 of 5 goals achieved so far this year',
        );
        final title = tester.getRect(find.text('Goals'));
        final trailing = tester.getRect(find.byKey(badge));
        expect(title.left, closeTo(_edge, 0.01));
        expect(trailing.top, greaterThanOrEqualTo(title.bottom - 0.01));
        expect(trailing.right, lessThanOrEqualTo(_width - _edge + 0.01));
      },
    );
  });
}
