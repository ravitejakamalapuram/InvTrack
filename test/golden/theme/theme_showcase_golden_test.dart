/// Golden tests for theme consistency - showcases key UI patterns.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';

import '../golden_test_helper.dart';

void main() {
  setUpAll(() {
    GoldenTestConfig.setup();
  });

  group('Theme Showcase Golden Tests', () {
    testWidgets('color palette - light theme', (tester) async {
      const size = Size(400, 400);
      await tester.setGoldenSize(size);
      await tester.pumpGoldenWidget(
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Primary Colors', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _ColorRow([
                  _ColorSwatch('Primary', AppColors.primaryLight),
                  _ColorSwatch('Accent', AppColors.accentLight),
                  _ColorSwatch('Success', AppColors.successLight),
                ]),
                const SizedBox(height: 16),
                const Text('Status Colors', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _ColorRow([
                  _ColorSwatch('Warning', AppColors.warningLight),
                  _ColorSwatch('Danger', AppColors.dangerLight),
                  _ColorSwatch('Neutral', AppColors.neutral500Light),
                ]),
                const SizedBox(height: 16),
                const Text('Graph Colors', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (int i = 0; i < 6; i++)
                      Container(
                        width: 50,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.chartPalette[i],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        isDark: false,
        size: size,
      );
      await expectLater(
        find.byType(SingleChildScrollView),
        matchesGoldenFile('goldens/theme_colors_light.png'),
      );
    });

    testWidgets('typography scale - light theme', (tester) async {
      const size = Size(400, 500);
      await tester.setGoldenSize(size);
      await tester.pumpGoldenWidget(
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Display Large', style: AppTypography.displayLarge),
                const SizedBox(height: 8),
                Text('Display', style: AppTypography.display),
                const SizedBox(height: 8),
                Text('Heading 1', style: AppTypography.h1),
                const SizedBox(height: 8),
                Text('Heading 2', style: AppTypography.h2),
                const SizedBox(height: 8),
                Text('Body Large', style: AppTypography.bodyLarge),
                const SizedBox(height: 8),
                Text('Body', style: AppTypography.body),
                const SizedBox(height: 8),
                Text('Caption', style: AppTypography.caption),
                const SizedBox(height: 8),
                Text('₹12,50,000', style: AppTypography.numberLarge),
              ],
            ),
          ),
        ),
        isDark: false,
        size: size,
      );
      await expectLater(
        find.byType(SingleChildScrollView),
        matchesGoldenFile('goldens/theme_typography_light.png'),
      );
    });

    testWidgets('button styles - light theme', (tester) async {
      const size = Size(350, 300);
      await tester.setGoldenSize(size);
      await tester.pumpGoldenWidget(
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(onPressed: () {}, child: const Text('Elevated Button')),
                const SizedBox(height: 12),
                FilledButton(onPressed: () {}, child: const Text('Filled Button')),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: () {}, child: const Text('Outlined Button')),
                const SizedBox(height: 12),
                TextButton(onPressed: () {}, child: const Text('Text Button')),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                  label: const Text('With Icon'),
                ),
              ],
            ),
          ),
        ),
        isDark: false,
        size: size,
      );
      await expectLater(
        find.byType(SingleChildScrollView),
        matchesGoldenFile('goldens/theme_buttons_light.png'),
      );
    });
  });
}

class _ColorRow extends StatelessWidget {
  final List<_ColorSwatch> colors;
  const _ColorRow(this.colors);

  @override
  Widget build(BuildContext context) {
    return Row(children: colors.map((c) => Expanded(child: c)).toList());
  }
}

class _ColorSwatch extends StatelessWidget {
  final String name;
  final Color color;
  const _ColorSwatch(this.name, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 40,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 4),
        Text(name, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}

