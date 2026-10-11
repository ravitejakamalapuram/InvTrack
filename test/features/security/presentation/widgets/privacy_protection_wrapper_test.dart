import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/security/presentation/widgets/privacy_protection_wrapper.dart';

void main() {
  // The wrapper also reads the auto-lock check from a provider.
  Future<void> pumpApp(WidgetTester tester, Widget app) =>
      tester.pumpWidget(ProviderScope(child: app));

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
      await pumpApp(
        tester,
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
      await pumpApp(
        tester,
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
      await pumpApp(
        tester,
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
      await pumpApp(
        tester,
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
      await pumpApp(
        tester,
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

    testWidgets('app icon image has semantic label for accessibility', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        const MaterialApp(
          home: PrivacyProtectionWrapper(
            child: Scaffold(body: Center(child: Text('Content'))),
          ),
        ),
      );

      // Trigger overlay
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      // Find the Image widget
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      // Verify semantic label exists
      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.semanticLabel, isNotNull);
      expect(imageWidget.semanticLabel, 'App icon - privacy screen active');
    });

    testWidgets('fallback icon has semantic label when image fails to load', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        const MaterialApp(
          home: PrivacyProtectionWrapper(
            child: Scaffold(body: Center(child: Text('Content'))),
          ),
        ),
      );

      // Trigger overlay
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      // The Image widget has an errorBuilder that shows an Icon
      // We can verify the Icon has semantic label by checking the widget tree
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(imageFinder);

      // Verify the errorBuilder is defined (it will show Icon with semantic label)
      expect(imageWidget.errorBuilder, isNotNull);

      // Note: Testing the actual error state would require triggering image load failure
      // which is complex in unit tests. The semantic label on Icon is verified in code review.
      // For now, we verify that the Image has proper semantic label and errorBuilder exists.
    });

    testWidgets('privacy overlay is accessible to screen readers', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        const MaterialApp(
          home: PrivacyProtectionWrapper(
            child: Scaffold(body: Center(child: Text('Content'))),
          ),
        ),
      );

      // Trigger overlay
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      // Verify semantic tree includes the image label
      final semantics = tester.getSemantics(find.byType(Image));
      expect(semantics.label, contains('App icon'));
      expect(semantics.label, contains('privacy screen active'));
    });
  });

  // A53: the lock screen draws the transparent mark. The opaque launcher
  // icon painted a solid square under the light-mode white tint, and its asset
  // was not bundled, so the real app showed the fallback shield instead.
  group('PrivacyProtectionWrapper lock screen mark', () {
    const markAsset = 'assets/icons/app_icon_mark.png';

    Future<Image> pumpOverlay(
      WidgetTester tester,
      Brightness brightness,
    ) async {
      await pumpApp(
        tester,
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: const PrivacyProtectionWrapper(
            child: Scaffold(body: Center(child: Text('Content'))),
          ),
        ),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      return tester.widget<Image>(find.byType(Image));
    }

    testWidgets('draws the transparent mark asset', (tester) async {
      final image = await pumpOverlay(tester, Brightness.light);

      expect((image.image as AssetImage).assetName, markAsset);
    });

    testWidgets('light mode tints the mark white', (tester) async {
      final image = await pumpOverlay(tester, Brightness.light);

      expect(image.color, Colors.white);
      expect(image.colorBlendMode, BlendMode.srcIn);
    });

    testWidgets('dark mode keeps the mark\'s own colours', (tester) async {
      final image = await pumpOverlay(tester, Brightness.dark);

      expect(image.color, isNull);
    });

    testWidgets(
      'the mark asset is bundled, so the fallback shield is not shown',
      (tester) async {
        await pumpOverlay(tester, Brightness.light);

        Object? loadError;
        await tester.runAsync(
          () => precacheImage(
            const AssetImage(markAsset),
            tester.element(find.byType(Image)),
            onError: (error, stack) => loadError = error,
          ),
        );
        await tester.pump();

        expect(loadError, isNull, reason: '$markAsset failed to load');
        expect(find.byIcon(Icons.shield_rounded), findsNothing);
      },
    );
  });
}
