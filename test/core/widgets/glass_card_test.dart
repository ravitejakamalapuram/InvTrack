import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';

void main() {
  group('GlassCard', () {
    testWidgets('has semantic button when onTap is provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassCard(onTap: () {}, child: const Text('Content')),
          ),
        ),
      );

      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byType(GlassCard)),
        matchesSemantics(isButton: true, hasTapAction: true, label: 'Content'),
      );
      handle.dispose();
    });

    testWidgets('has no semantic button when onTap is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: GlassCard(child: Text('Content'))),
        ),
      );

      final handle = tester.ensureSemantics();
      final semantics = tester.getSemantics(find.byType(GlassCard));
      // Should not be a button
      // ignore: deprecated_member_use
      expect(semantics.hasFlag(SemanticsFlag.isButton), isFalse);
      handle.dispose();
    });
  });

  group('GlassHeroCard', () {
    testWidgets('has semantic button when onTap is provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassHeroCard(
              onTap: () {},
              child: const Text('Hero Content'),
            ),
          ),
        ),
      );

      final handle = tester.ensureSemantics();
      // This verifies that the card identifies itself as a button to accessibility services
      // This is expected to FAIL until we fix GlassHeroCard
      expect(
        tester.getSemantics(find.byType(GlassHeroCard)),
        matchesSemantics(isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });
  });
}
