import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/gradient_button.dart';
import 'package:inv_tracker/features/fire_number/presentation/providers/fire_notifier.dart';
import 'package:inv_tracker/features/fire_number/presentation/screens/fire_setup_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

// Mock the Notifier by extending it
class MockFireSettingsNotifier extends FireSettingsNotifier {
  @override
  Future<void> saveSettings(dynamic settings) async {
    // Do nothing
  }
}

void main() {
  testWidgets('FireSetupScreen has accessible tooltips on buttons', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currencySymbolProvider.overrideWithValue('₹'),
          fireSettingsNotifierProvider.overrideWith(
            MockFireSettingsNotifier.new,
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FireSetupScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify AppBar Close Button
    final closeButtonFinder = find.widgetWithIcon(IconButton, Icons.close);
    expect(closeButtonFinder, findsOneWidget);
    expect(tester.widget<IconButton>(closeButtonFinder).tooltip, 'Close setup');

    // Verify Current Age Buttons
    final removeIcons = find.widgetWithIcon(
      IconButton,
      Icons.remove_circle_outline,
    );
    final addIcons = find.widgetWithIcon(IconButton, Icons.add_circle_outline);

    expect(removeIcons, findsNWidgets(2)); // Current Age and Target Age
    expect(addIcons, findsNWidgets(2));

    // Current Age buttons (first pair)
    expect(
      tester.widget<IconButton>(removeIcons.first).tooltip,
      'Decrease age',
    );
    expect(tester.widget<IconButton>(addIcons.first).tooltip, 'Increase age');

    // Target Age buttons (second pair)
    expect(
      tester.widget<IconButton>(removeIcons.at(1)).tooltip,
      'Decrease target age',
    );
    expect(
      tester.widget<IconButton>(addIcons.at(1)).tooltip,
      'Increase target age',
    );

    // Navigate to next step to verify Back button
    final continueButton = find.widgetWithText(GradientButton, 'Continue');
    expect(continueButton, findsOneWidget);

    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    // Verify AppBar Back Button
    final backButtonFinder = find.widgetWithIcon(IconButton, Icons.arrow_back);
    expect(backButtonFinder, findsOneWidget);
    expect(tester.widget<IconButton>(backButtonFinder).tooltip, 'Go back');
  });
}
