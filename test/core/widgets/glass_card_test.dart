import 'package:flutter/material.dart';
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
        matchesSemantics(
          isButton: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
          label: 'Content',
        ),
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
      expect(semantics.flagsCollection.isButton, isFalse);
      handle.dispose();
    });

    testWidgets('excludes child semantics when semanticLabel is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassCard(
              onTap: () {},
              semanticLabel: 'Custom Label',
              child: const Text('Child Content'),
            ),
          ),
        ),
      );

      final handle = tester.ensureSemantics();

      // Should match the custom label exactly, implying child text is excluded/overridden
      expect(
        tester.getSemantics(find.byType(GlassCard)),
        matchesSemantics(
          isButton: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
          label: 'Custom Label',
        ),
      );
      handle.dispose();
    });

    testWidgets('GlassCard with blur: 0 removes shadows for performance', (
      tester,
    ) async {
      // Build GlassCard with blur: 0 (list mode)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GlassCard(blur: 0, child: const Text('Test'))),
        ),
      );

      // Find the container that holds the decoration
      final containerFinder = find.descendant(
        of: find.byType(GlassCard),
        matching: find.byWidgetPredicate(
          (widget) => widget is Container && widget.decoration is BoxDecoration,
        ),
      );

      // Verify we found at least one container
      expect(containerFinder, findsWidgets);

      final containers = tester.widgetList<Container>(containerFinder);
      BoxDecoration? decoration;

      // Look for the container that matches the GlassCard structure.
      for (final container in containers) {
        if (container.decoration is BoxDecoration) {
          decoration = container.decoration as BoxDecoration;
          break;
        }
      }

      // OPTIMIZED STATE ASSERTION:
      // The decoration should exist (for color/border), but shadows must be empty/null.
      expect(decoration, isNotNull);
      expect(
        decoration!.boxShadow,
        anyOf(isNull, isEmpty),
        reason: 'Shadows should be removed for performance',
      );
    });

    testWidgets('supports selected state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassCard(
              onTap: () {},
              selected: true,
              child: const Text('Content'),
            ),
          ),
        ),
      );

      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byType(GlassCard)),
        matchesSemantics(
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
          label: 'Content',
        ),
      );
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
      expect(
        tester.getSemantics(find.byType(GlassHeroCard)),
        matchesSemantics(
          isButton: true,
          hasTapAction: true,
          label: 'Hero Content',
        ),
      );
      handle.dispose();
    });

    testWidgets('excludes child semantics when semanticLabel is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassHeroCard(
              onTap: () {},
              semanticLabel: 'Hero Custom Label',
              child: const Text('Hero Child Content'),
            ),
          ),
        ),
      );

      final handle = tester.ensureSemantics();

      // Should match the custom label exactly
      expect(
        tester.getSemantics(find.byType(GlassHeroCard)),
        matchesSemantics(
          isButton: true,
          hasTapAction: true,
          label: 'Hero Custom Label',
        ),
      );
      handle.dispose();
    });

    testWidgets('supports selected state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassHeroCard(
              onTap: () {},
              selected: true,
              child: const Text('Hero Content'),
            ),
          ),
        ),
      );

      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byType(GlassHeroCard)),
        matchesSemantics(
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
          label: 'Hero Content',
        ),
      );
      handle.dispose();
    });
  });
}
