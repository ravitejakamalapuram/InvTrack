import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/security/presentation/widgets/privacy_protection_wrapper.dart';

void main() {
  testWidgets('PrivacyProtectionWrapper shows overlay when inactive/paused', (WidgetTester tester) async {
    // Build the widget
    await tester.pumpWidget(
      const MaterialApp(
        home: PrivacyProtectionWrapper(
          child: Scaffold(
            body: Center(child: Text('Content')),
          ),
        ),
      ),
    );

    // Initial state: Content should be visible, overlay hidden
    expect(find.text('Content'), findsOneWidget);
    expect(find.byIcon(Icons.security), findsNothing);
    expect(find.text('InvTracker'), findsNothing);

    // Simulate AppLifecycleState.inactive
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    // Overlay should be visible
    // Note: The 'Content' is still in the tree, just covered.
    // 'InvTracker' text or Icon should be visible.
    // Since we use Image.asset which might fail in test env without assets loaded,
    // it falls back to Icon(Icons.security) or just fails to load image.
    // However, the text 'InvTracker' is always there.
    expect(find.text('InvTracker'), findsOneWidget);

    // Simulate AppLifecycleState.paused
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    // Overlay should still be visible
    expect(find.text('InvTracker'), findsOneWidget);

    // Simulate AppLifecycleState.resumed
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    // Overlay should be gone
    expect(find.text('InvTracker'), findsNothing);
  });

  testWidgets('PrivacyProtectionWrapper does nothing if disabled', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PrivacyProtectionWrapper(
          enabled: false,
          child: Scaffold(
            body: Center(child: Text('Content')),
          ),
        ),
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(find.text('InvTracker'), findsNothing);
  });
}
