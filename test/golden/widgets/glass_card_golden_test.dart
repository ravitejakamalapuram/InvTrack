/// Golden tests for GlassCard widget.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';

import '../golden_test_helper.dart';

void main() {
  setUpAll(() {
    GoldenTestConfig.setup();
  });

  group('GlassCard Golden Tests', () {
    testWidgets('basic card - light theme', (tester) async {
      await tester.setGoldenSize(GoldenTestConfig.cardSize);
      await tester.pumpGoldenWidget(
        Padding(
          padding: const EdgeInsets.all(16),
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Card Title',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('This is card content that demonstrates the glass effect.'),
              ],
            ),
          ),
        ),
        isDark: false,
        size: GoldenTestConfig.cardSize,
      );
      await expectLater(
        find.byType(GlassCard),
        matchesGoldenFile('goldens/glass_card_basic_light.png'),
      );
    });

    testWidgets('basic card - dark theme', (tester) async {
      await tester.setGoldenSize(GoldenTestConfig.cardSize);
      await tester.pumpGoldenWidget(
        Padding(
          padding: const EdgeInsets.all(16),
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Card Title',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('This is card content that demonstrates the glass effect.'),
              ],
            ),
          ),
        ),
        isDark: true,
        size: GoldenTestConfig.cardSize,
      );
      await expectLater(
        find.byType(GlassCard),
        matchesGoldenFile('goldens/glass_card_basic_dark.png'),
      );
    });

    testWidgets('with icon row - light theme', (tester) async {
      await tester.setGoldenSize(GoldenTestConfig.cardSize);
      await tester.pumpGoldenWidget(
        Padding(
          padding: const EdgeInsets.all(16),
          child: GlassCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance_wallet, color: Colors.blue),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total Investments',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '₹12,50,000',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
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
        find.byType(GlassCard),
        matchesGoldenFile('goldens/glass_card_icon_row_light.png'),
      );
    });
  });
}

