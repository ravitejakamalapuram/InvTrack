// The archive swipe paints a glyph at the left edge of an amber gradient. The
// glyph is the ink colour there, because white on the amber start is 2.15:1;
// the unarchive swipe keeps white on the green gradient.
//
// The id below is a row of test/core/theme/contrast_pairs.dart; the guard
// finds it here.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/widgets/swipe_actions.dart';

import '../../helpers/contrast.dart';

Future<Color> _glyph(
  WidgetTester tester,
  IconData icon, {
  required bool isArchived,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            SwipeActions(
              itemKey: 'item',
              archiveConfig: ArchiveActionConfig(
                confirmTitle: 'Archive?',
                confirmMessage: 'Sure?',
                onArchive: () {},
                successMessage: 'Done',
                isArchived: isArchived,
              ),
              child: const SizedBox(height: 80, child: Text('Item')),
            ),
          ],
        ),
      ),
    ),
  );
  // Drag part of the way so the background is built.
  final drag = await tester.startGesture(tester.getCenter(find.text('Item')));
  await drag.moveBy(const Offset(40, 0));
  await tester.pump();
  await drag.moveBy(const Offset(80, 0));
  await tester.pump();
  final colour = tester.widget<Icon>(find.byIcon(icon)).color!;
  await drag.up();
  await tester.pumpAndSettle();
  return colour;
}

void main() {
  testWidgets(
    'archive-gradient-start-light: the archive glyph reads on the amber',
    (tester) async {
      final glyph = await _glyph(
        tester,
        Icons.archive_rounded,
        isArchived: false,
      );
      expect(glyph, AppColors.neutral900Light);
      expect(
        contrastRatio(glyph, AppColors.archiveGradient.colors.first),
        greaterThanOrEqualTo(kMinGraphic),
        reason: 'archive-gradient-start-light',
      );
    },
  );

  testWidgets('the unarchive glyph stays white on the green', (tester) async {
    final glyph = await _glyph(
      tester,
      Icons.unarchive_rounded,
      isArchived: true,
    );
    expect(glyph, Colors.white);
    expect(
      contrastRatio(glyph, AppColors.successGradient.colors.first),
      greaterThanOrEqualTo(kMinGraphic),
    );
  });
}
