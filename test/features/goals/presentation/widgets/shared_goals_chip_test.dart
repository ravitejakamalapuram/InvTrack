// The chip on a goal card: a short plural-aware text, never cut in the middle
// of a word, with the full sentence for the screen reader.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/shared_goals_chip.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../../../helpers/text_geometry.dart';

Widget _app({required Widget chip, double width = 200, double textScale = 1}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: app!,
    ),
    home: Scaffold(
      body: Align(
        alignment: AlignmentDirectional.topStart,
        child: SizedBox(width: width, child: chip),
      ),
    ),
  );
}

void main() {
  group('on a card (compact)', () {
    for (final (count, text) in [
      (1, 'Also in 1 goal'),
      (2, 'Also in 2 goals'),
      (12, 'Also in 12 goals'),
    ]) {
      testWidgets('says "$text" for $count', (tester) async {
        await tester.pumpWidget(_app(chip: SharedGoalsChip(count: count)));
        expect(find.text(text), findsOneWidget);
      });
    }

    testWidgets('is read in full to a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(chip: const SharedGoalsChip(count: 2)));

      expect(
        tester.getSemantics(find.byType(SharedGoalsChip)).label,
        'Also counted in 2 other goals',
      );
      handle.dispose();
    });
  });

  group('on the goal details screen (not compact)', () {
    testWidgets('keeps the long text, and reads the same', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(chip: const SharedGoalsChip(count: 2, compact: false)),
      );

      expect(find.text('Also counted in 2 other goals'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(SharedGoalsChip)).label,
        'Also counted in 2 other goals',
      );
      handle.dispose();
    });
  });

  group('wrapping', () {
    testWidgets('is never cut: no ellipsis, no line limit', (tester) async {
      await tester.pumpWidget(_app(chip: const SharedGoalsChip(count: 12)));

      final text = tester.widget<Text>(
        find.descendant(
          of: find.byType(SharedGoalsChip),
          matching: find.byType(Text),
        ),
      );
      expect(text.maxLines, isNull);
      expect(text.overflow, isNull);
    });

    testWidgets('wraps between words in a narrow slot at 2x text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          chip: const SharedGoalsChip(count: 12, compact: false),
          width: 150,
          textScale: 2,
        ),
      );

      expect(tester.takeException(), isNull);
      final glyphs = glyphRect(
        tester,
        find.descendant(
          of: find.byType(SharedGoalsChip),
          matching: find.byType(Text),
        ),
      );
      // More than one line of text, and it stays inside the 150dp slot.
      expect(glyphs.height, greaterThan(40));
      expect(glyphs.right, lessThanOrEqualTo(150));
    });
  });
}
