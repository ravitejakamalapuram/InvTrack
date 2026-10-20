/// Regression tests for Crashlytics Google Fonts loading failure
///
/// Crashlytics Issue Fixed: db8b8ac28264602be9b88d553f00969d
///
/// Bug: Exception: Failed to load font with url: https://fonts.gstatic.com/...
/// Root Cause: Network failures when loading fonts from Google Fonts CDN
/// Solution: Added _safeGoogleFont() wrapper with try-catch fallback to bundled fonts
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';

void main() {
  group('Google Fonts Fallback Regression Tests', () {
    testWidgets('AppTypography loads without crashing when offline',
        (tester) async {
      // Regression test for Crashlytics issue db8b8ac28264602be9b88d553f00969d
      // This test verifies that typography works even if Google Fonts CDN fails

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text('Display Large', style: AppTypography.displayLarge),
                Text('Display', style: AppTypography.display),
                Text('Display Small', style: AppTypography.displaySmall),
                Text('Heading 1', style: AppTypography.h1),
                Text('Heading 2', style: AppTypography.h2),
                Text('Heading 3', style: AppTypography.h3),
                Text('Heading 4', style: AppTypography.h4),
                Text('Body Large', style: AppTypography.bodyLarge),
                Text('Body', style: AppTypography.body),
                Text('Body Medium', style: AppTypography.bodyMedium),
                Text('Label', style: AppTypography.label),
                Text('Label Medium', style: AppTypography.labelMedium),
                Text('Caption', style: AppTypography.caption),
                Text('Small', style: AppTypography.small),
                Text('Tiny', style: AppTypography.tiny),
                Text('Number Large', style: AppTypography.numberLarge),
                Text('Number', style: AppTypography.number),
                Text('Number Small', style: AppTypography.numberSmall),
                Text('Percentage', style: AppTypography.percentage),
                Text('Button Large', style: AppTypography.buttonLarge),
                Text('Button', style: AppTypography.button),
                Text('Button Small', style: AppTypography.buttonSmall),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // All typography styles should render without crashing
      expect(find.text('Display Large'), findsOneWidget);
      expect(find.text('Heading 1'), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
      expect(find.text('Button'), findsOneWidget);
    });

    test('AppTypography text styles have correct font families', () {
      // Verify that Plus Jakarta Sans styles have correct fallback
      // Google Fonts adds suffixes like '_800', '_700' to font family names
      expect(AppTypography.displayLarge.fontFamily, isNotNull);
      expect(AppTypography.displayLarge.fontFamily, contains('PlusJakartaSans'));

      expect(AppTypography.h1.fontFamily, isNotNull);
      expect(AppTypography.h1.fontFamily, contains('PlusJakartaSans'));

      expect(AppTypography.numberLarge.fontFamily, isNotNull);
      expect(AppTypography.numberLarge.fontFamily, contains('PlusJakartaSans'));

      // Verify that Inter styles have correct fallback
      expect(AppTypography.body.fontFamily, isNotNull);
      expect(AppTypography.body.fontFamily, contains('Inter'));

      expect(AppTypography.label.fontFamily, isNotNull);
      expect(AppTypography.label.fontFamily, contains('Inter'));

      expect(AppTypography.button.fontFamily, isNotNull);
      expect(AppTypography.button.fontFamily, contains('Inter'));
    });

    test('AppTypography text styles have correct font sizes', () {
      // Verify font sizes are correct regardless of fallback
      expect(AppTypography.displayLarge.fontSize, 48);
      expect(AppTypography.display.fontSize, 36);
      expect(AppTypography.displaySmall.fontSize, 28);
      expect(AppTypography.h1.fontSize, 24);
      expect(AppTypography.h2.fontSize, 20);
      expect(AppTypography.h3.fontSize, 18);
      expect(AppTypography.h4.fontSize, 16);
      expect(AppTypography.body.fontSize, 16);
      expect(AppTypography.bodyMedium.fontSize, 15);
      expect(AppTypography.label.fontSize, 14);
      expect(AppTypography.small.fontSize, 12);
    });

    test('AppTypography text styles have correct font weights', () {
      // Verify font weights are preserved in fallback
      expect(AppTypography.displayLarge.fontWeight, FontWeight.w800);
      expect(AppTypography.display.fontWeight, FontWeight.w700);
      expect(AppTypography.h1.fontWeight, FontWeight.w700);
      expect(AppTypography.h2.fontWeight, FontWeight.w600);
      expect(AppTypography.body.fontWeight, FontWeight.w400);
      expect(AppTypography.label.fontWeight, FontWeight.w500);
    });

    testWidgets('Typography renders correctly in both light and dark themes',
        (tester) async {
      // Test light theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Text('Test Light', style: AppTypography.h1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Test Light'), findsOneWidget);

      // Test dark theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Text('Test Dark', style: AppTypography.h1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Test Dark'), findsOneWidget);
    });
  });
}
