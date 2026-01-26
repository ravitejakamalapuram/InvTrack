import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/security/presentation/widgets/privacy_protection_wrapper.dart';

void main() {
  group('PrivacyProtectionWrapper', () {
    /// Finder for the overlay's positioned container (uses Positioned.fill)
    Finder findPrivacyOverlay() {
      return find.byWidgetPredicate(
        (widget) =>
            widget is Positioned &&
            widget.left == 0 &&
            widget.right == 0 &&
            widget.top == 0 &&
            widget.bottom == 0,
      );
    }

    testWidgets('shows overlay when inactive/paused', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PrivacyProtectionWrapper(
            child: Scaffold(body: Center(child: Text('Content'))),
          ),
        ),
      );

      // Initial state: Content should be visible, no overlay
      expect(find.text('Content'), findsOneWidget);
      expect(findPrivacyOverlay(), findsNothing);

      // Simulate AppLifecycleState.inactive
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      // Overlay should be visible
      expect(findPrivacyOverlay(), findsOneWidget);

      // Simulate AppLifecycleState.paused
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // Overlay should still be visible
      expect(findPrivacyOverlay(), findsOneWidget);

      // Simulate AppLifecycleState.resumed
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      // Overlay should be gone
      expect(findPrivacyOverlay(), findsNothing);
    });

    testWidgets('does nothing if disabled', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PrivacyProtectionWrapper(
            enabled: false,
            child: Scaffold(body: Center(child: Text('Content'))),
          ),
        ),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      // No overlay should appear when disabled
      expect(findPrivacyOverlay(), findsNothing);
    });

    testWidgets('overlay contains ColoredBox with app colors', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PrivacyProtectionWrapper(
            child: Scaffold(body: Center(child: Text('Content'))),
          ),
        ),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      // Should show privacy overlay
      expect(findPrivacyOverlay(), findsOneWidget);

      // Overlay should contain a ColoredBox
      final positionedWidget = tester.widget<Positioned>(findPrivacyOverlay());
      expect(positionedWidget.child, isA<ColoredBox>());
    });

    testWidgets('child widget remains in tree when overlay is shown', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PrivacyProtectionWrapper(
            child: Scaffold(body: Center(child: Text('Sensitive Content'))),
          ),
        ),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      // Child content should still be in tree (just covered)
      expect(find.text('Sensitive Content'), findsOneWidget);
      // And overlay is also present
      expect(findPrivacyOverlay(), findsOneWidget);
    });

    testWidgets('responds to detached state', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PrivacyProtectionWrapper(
            child: Scaffold(body: Center(child: Text('Content'))),
          ),
        ),
      );

      // detached state should NOT show overlay (only inactive/paused)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
      await tester.pump();

      expect(findPrivacyOverlay(), findsNothing);
    });
  });
}
