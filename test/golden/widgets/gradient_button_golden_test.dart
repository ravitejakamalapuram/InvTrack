// Golden tests for GradientButton widget.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/gradient_button.dart';

import '../golden_test_helper.dart';

void main() {
  setUpAll(() {
    GoldenTestConfig.setup();
  });

  group('GradientButton Golden Tests', () {
    testWidgets('default state - light theme', (tester) async {
      await tester.setGoldenSize(GoldenTestConfig.buttonSize);
      await tester.pumpGoldenWidget(
        Padding(
          padding: const EdgeInsets.all(16),
          child: GradientButton(
            onPressed: () {},
            label: 'Add Investment',
          ),
        ),
        isDark: false,
        size: GoldenTestConfig.buttonSize,
      );
      await expectLater(
        find.byType(GradientButton),
        matchesGoldenFile('goldens/gradient_button_default_light.png'),
      );
    });

    testWidgets('default state - dark theme', (tester) async {
      await tester.setGoldenSize(GoldenTestConfig.buttonSize);
      await tester.pumpGoldenWidget(
        Padding(
          padding: const EdgeInsets.all(16),
          child: GradientButton(
            onPressed: () {},
            label: 'Add Investment',
          ),
        ),
        isDark: true,
        size: GoldenTestConfig.buttonSize,
      );
      await expectLater(
        find.byType(GradientButton),
        matchesGoldenFile('goldens/gradient_button_default_dark.png'),
      );
    });

    testWidgets('with icon - light theme', (tester) async {
      await tester.setGoldenSize(GoldenTestConfig.buttonSize);
      await tester.pumpGoldenWidget(
        Padding(
          padding: const EdgeInsets.all(16),
          child: GradientButton(
            onPressed: () {},
            label: 'Add Investment',
            icon: Icons.add,
          ),
        ),
        isDark: false,
        size: GoldenTestConfig.buttonSize,
      );
      await expectLater(
        find.byType(GradientButton),
        matchesGoldenFile('goldens/gradient_button_with_icon_light.png'),
      );
    });

    testWidgets('loading state - light theme', (tester) async {
      await tester.setGoldenSize(GoldenTestConfig.buttonSize);
      await tester.pumpGoldenWidget(
        const Padding(
          padding: EdgeInsets.all(16),
          child: GradientButton(
            onPressed: null,
            label: 'Loading...',
            isLoading: true,
          ),
        ),
        isDark: false,
        size: GoldenTestConfig.buttonSize,
      );
      await expectLater(
        find.byType(GradientButton),
        matchesGoldenFile('goldens/gradient_button_loading_light.png'),
      );
    });

    testWidgets('loading state - dark theme', (tester) async {
      await tester.setGoldenSize(GoldenTestConfig.buttonSize);
      await tester.pumpGoldenWidget(
        const Padding(
          padding: EdgeInsets.all(16),
          child: GradientButton(
            onPressed: null,
            label: 'Loading...',
            isLoading: true,
          ),
        ),
        isDark: true,
        size: GoldenTestConfig.buttonSize,
      );
      await expectLater(
        find.byType(GradientButton),
        matchesGoldenFile('goldens/gradient_button_loading_dark.png'),
      );
    });
  });
}
