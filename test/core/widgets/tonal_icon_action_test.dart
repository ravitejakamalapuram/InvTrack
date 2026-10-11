// The tonal chip used for every app bar action on the four main screens: a
// 36dp chip inside a 48dp tap box, labelled for screen readers, placed so the
// first and last chip sit on the screen edge and only the transparent box
// hangs into the gutter. Measurements are render boxes in dp on a 360dp wide,
// 1dp-per-pixel view; any overflow fails the test.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/widgets/tonal_icon_action.dart';

const _width = 360.0;
const _edge = AppSpacing.screenEdge;

void _sizeView(WidgetTester tester, double textScale) {
  tester.view
    ..physicalSize = const Size(_width, 780)
    ..devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAllTestValues();
  });
}

Future<void> _pumpAction(
  WidgetTester tester,
  TonalIconAction action, {
  Brightness brightness = Brightness.light,
}) async {
  _sizeView(tester, 1.0);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: Center(child: action)),
    ),
  );
}

BoxDecoration _chipDecoration(WidgetTester tester) =>
    tester.widget<Container>(find.byKey(TonalIconAction.chipKey)).decoration!
        as BoxDecoration;

void main() {
  group('TonalIconAction', () {
    testWidgets('is a 36dp chip centred in a tap box of at least 48 x 48', (
      tester,
    ) async {
      await _pumpAction(
        tester,
        TonalIconAction(
          icon: Icons.add_rounded,
          tooltip: 'Add Goal',
          onPressed: () {},
        ),
      );
      final box = tester.getRect(find.byType(IconButton));
      final chip = tester.getRect(find.byKey(TonalIconAction.chipKey));
      expect(box.width, greaterThanOrEqualTo(48));
      expect(box.height, greaterThanOrEqualTo(48));
      expect(chip.size, const Size(36, 36));
      expect(chip.center.dx, closeTo(box.center.dx, 0.01));
      expect(chip.center.dy, closeTo(box.center.dy, 0.01));
    });

    testWidgets('a tap on the box outside the chip fires onPressed', (
      tester,
    ) async {
      var taps = 0;
      await _pumpAction(
        tester,
        TonalIconAction(
          icon: Icons.add_rounded,
          tooltip: 'Add Goal',
          onPressed: () => taps++,
        ),
      );
      final box = tester.getRect(find.byType(IconButton));
      final chip = tester.getRect(find.byKey(TonalIconAction.chipKey));
      // 2dp inside the box corner is 4dp outside the chip on both axes.
      final outside = box.topLeft + const Offset(2, 2);
      expect(chip.contains(outside), isFalse);
      await tester.tapAt(outside);
      expect(taps, 1);
    });

    testWidgets('the button exposes its tooltip on its semantics node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await _pumpAction(
          tester,
          TonalIconAction(
            icon: Icons.add_rounded,
            tooltip: 'Add Goal',
            onPressed: () {},
          ),
        );
        expect(find.byTooltip('Add Goal'), findsOneWidget);
        // Flutter exposes a button's tooltip as its semantics tooltip, which
        // TalkBack reads when a button has no label of its own. The label
        // stays empty on purpose (a second label would be read twice); how
        // the oldest Android versions announce a tooltip is not checked here.
        final node = tester.getSemantics(find.byType(IconButton));
        expect(node.tooltip, 'Add Goal');
        expect(node.flagsCollection.isButton, isTrue);
        expect(node.flagsCollection.isEnabled, Tristate.isTrue);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('surface tone: a 10% tint, selected is solid', (tester) async {
      await _pumpAction(
        tester,
        TonalIconAction(
          icon: Icons.checklist_rounded,
          tooltip: 'Select',
          onPressed: () {},
        ),
      );
      expect(
        _chipDecoration(tester).color,
        AppColors.primaryLight.withValues(alpha: 0.1),
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.checklist_rounded)).color,
        AppColors.neutral700Light,
      );

      await _pumpAction(
        tester,
        TonalIconAction(
          icon: Icons.close_rounded,
          tooltip: 'Exit',
          selected: true,
          onPressed: () {},
        ),
      );
      expect(_chipDecoration(tester).color, AppColors.primaryLight);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.close_rounded)).color,
        Colors.white,
      );
    });

    testWidgets('surface tone in the dark theme is a white 10% tint', (
      tester,
    ) async {
      await _pumpAction(
        tester,
        TonalIconAction(
          icon: Icons.checklist_rounded,
          tooltip: 'Select',
          onPressed: () {},
        ),
        brightness: Brightness.dark,
      );
      expect(
        _chipDecoration(tester).color,
        Colors.white.withValues(alpha: 0.1),
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.checklist_rounded)).color,
        Colors.white,
      );
    });

    testWidgets('onHero tone: a black 20% scrim with a white icon', (
      tester,
    ) async {
      await _pumpAction(
        tester,
        TonalIconAction(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Back',
          tone: TonalIconActionTone.onHero,
          onPressed: () {},
        ),
      );
      expect(
        _chipDecoration(tester).color,
        Colors.black.withValues(alpha: 0.2),
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.arrow_back_rounded)).color,
        Colors.white,
      );
    });
  });

  for (final direction in TextDirection.values) {
    for (final scale in const [1.0, 2.0]) {
      testWidgets('in an app bar the first and last chip sit on the edge '
          '(${direction.name}, text x$scale)', (tester) async {
        _sizeView(tester, scale);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) =>
                Directionality(textDirection: direction, child: child!),
            home: Scaffold(
              body: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    leading: TonalIconAction.leading(
                      TonalIconAction(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        onPressed: () {},
                      ),
                    ),
                    leadingWidth: AppSpacing.appBarLeadingWidth,
                    title: const Text(
                      'A rather long investment name that cannot fit',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    actions: [
                      TonalIconAction(
                        icon: Icons.sort_rounded,
                        tooltip: 'Sort',
                        onPressed: () {},
                      ),
                      TonalIconAction(
                        icon: Icons.more_vert_rounded,
                        tooltip: 'More options',
                        onPressed: () {},
                      ),
                    ],
                    actionsPadding: const EdgeInsetsDirectional.only(
                      end: AppSpacing.appBarTrailingGap,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 1000)),
                ],
              ),
            ),
          ),
        );

        final chips = find.byKey(TonalIconAction.chipKey);
        expect(chips, findsNWidgets(3));
        final first = tester.getRect(chips.first);
        final last = tester.getRect(chips.last);
        final lead = tester.getRect(find.byTooltip('Back'));
        final tail = tester.getRect(find.byTooltip('More options'));

        if (direction == TextDirection.ltr) {
          expect(first.left, closeTo(_edge, 0.01));
          expect(last.right, closeTo(_width - _edge, 0.01));
        } else {
          expect(first.right, closeTo(_width - _edge, 0.01));
          expect(last.left, closeTo(_edge, 0.01));
        }
        // The tap boxes are 48dp wide and 48dp high, and only the boxes hang
        // into the 16dp gutter, by 6dp.
        expect(lead.width, greaterThanOrEqualTo(47.99));
        expect(tail.width, greaterThanOrEqualTo(47.99));
        expect(lead.height, greaterThanOrEqualTo(47.99));
        expect(tail.height, greaterThanOrEqualTo(47.99));
        expect(
          direction == TextDirection.ltr ? lead.left : _width - lead.right,
          closeTo(_edge - AppSpacing.actionInset, 0.01),
        );
        expect(
          direction == TextDirection.ltr ? _width - tail.right : tail.left,
          closeTo(_edge - AppSpacing.actionInset, 0.01),
        );
      });
    }
  }
}
