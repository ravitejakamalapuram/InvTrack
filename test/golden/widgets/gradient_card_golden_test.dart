// Golden tests for GradientCard widget.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/widgets/gradient_card.dart';

import '../golden_test_helper.dart';

void main() {
  setUpAll(() {
    GoldenTestConfig.setup();
  });

  group('GradientCard Golden Tests', () {
    testWidgets('hero gradient - light theme', (tester) async {
      await tester.setGoldenSize(GoldenTestConfig.cardSize);
      await tester.pumpGoldenWidget(
        const Padding(
          padding: EdgeInsets.all(16),
          child: GradientCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total Portfolio',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '₹45,00,000',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '+12.5% all time',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        isDark: false,
        size: GoldenTestConfig.cardSize,
      );
      await expectLater(
        find.byType(GradientCard),
        matchesGoldenFile('goldens/gradient_card_hero_light.png'),
      );
    });

    testWidgets('custom gradient - light theme', (tester) async {
      await tester.setGoldenSize(GoldenTestConfig.cardSize);
      await tester.pumpGoldenWidget(
        Padding(
          padding: const EdgeInsets.all(16),
          child: GradientCard(
            gradient: LinearGradient(
              colors: [
                AppColors.successLight,
                AppColors.successLight.withValues(alpha: 0.7),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_up, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Best Performer',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  'HDFC Flexi Cap',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '+24.5% returns',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        isDark: false,
        size: GoldenTestConfig.cardSize,
      );
      await expectLater(
        find.byType(GradientCard),
        matchesGoldenFile('goldens/gradient_card_custom_light.png'),
      );
    });

    testWidgets('no glow - dark theme', (tester) async {
      await tester.setGoldenSize(GoldenTestConfig.cardSize);
      await tester.pumpGoldenWidget(
        const Padding(
          padding: EdgeInsets.all(16),
          child: GradientCard(
            showGlow: false,
            child: Center(
              child: Text(
                'No Glow Effect',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
        ),
        isDark: true,
        size: GoldenTestConfig.cardSize,
      );
      await expectLater(
        find.byType(GradientCard),
        matchesGoldenFile('goldens/gradient_card_no_glow_dark.png'),
      );
    });
  });
}

