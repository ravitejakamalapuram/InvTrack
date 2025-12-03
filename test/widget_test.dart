// Basic Flutter widget test for InvTracker app.

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/app/app.dart';

void main() {
  testWidgets('App renders correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const InvTrackerApp());

    // Verify that the app title is displayed.
    expect(find.text('InvTracker'), findsWidgets);

    // Verify that the tagline is displayed.
    expect(find.text('Your Personal Investment Tracker'), findsOneWidget);

    // Verify that the version is displayed.
    expect(find.text('v1.0.0 - Foundation Setup Complete'), findsOneWidget);
  });
}
