// Golden tests for EmptyStateWidget.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/widgets/empty_state_widget.dart';

import '../golden_test_helper.dart';

void main() {
  setUpAll(() {
    GoldenTestConfig.setup();
  });

  group('EmptyStateWidget Golden Tests', () {
    testWidgets('basic empty state - light theme', (tester) async {
      await tester.setGoldenSize(GoldenTestConfig.defaultSize);
      await tester.pumpGoldenWidget(
        const EmptyStateWidget(
          title: 'No Investments Yet',
          message: 'Start tracking your portfolio by adding your first investment.',
          icon: Icons.account_balance_wallet_outlined,
        ),
        isDark: false,
        size: GoldenTestConfig.defaultSize,
      );
      await expectLater(
        find.byType(EmptyStateWidget),
        matchesGoldenFile('goldens/empty_state_basic_light.png'),
      );
    });

    testWidgets('basic empty state - dark theme', (tester) async {
      await tester.setGoldenSize(GoldenTestConfig.defaultSize);
      await tester.pumpGoldenWidget(
        const EmptyStateWidget(
          title: 'No Investments Yet',
          message: 'Start tracking your portfolio by adding your first investment.',
          icon: Icons.account_balance_wallet_outlined,
        ),
        isDark: true,
        size: GoldenTestConfig.defaultSize,
      );
      await expectLater(
        find.byType(EmptyStateWidget),
        matchesGoldenFile('goldens/empty_state_basic_dark.png'),
      );
    });

    testWidgets('with action button - light theme', (tester) async {
      await tester.setGoldenSize(GoldenTestConfig.defaultSize);
      await tester.pumpGoldenWidget(
        EmptyStateWidget(
          title: 'No Goals Set',
          message: 'Create financial goals to track your progress.',
          icon: Icons.flag_outlined,
          actionLabel: 'Create Goal',
          actionIcon: Icons.add,
          onAction: () {},
        ),
        isDark: false,
        size: GoldenTestConfig.defaultSize,
      );
      await expectLater(
        find.byType(EmptyStateWidget),
        matchesGoldenFile('goldens/empty_state_with_action_light.png'),
      );
    });

    testWidgets('with gradient background - light theme', (tester) async {
      await tester.setGoldenSize(GoldenTestConfig.defaultSize);
      await tester.pumpGoldenWidget(
        EmptyStateWidget(
          title: 'Welcome!',
          message: 'Get started with InvTrack',
          icon: Icons.rocket_launch_outlined,
          iconBackgroundGradient: [
            AppColors.primaryLight,
            AppColors.accentLight,
          ],
          actionLabel: 'Get Started',
          onAction: () {},
        ),
        isDark: false,
        size: GoldenTestConfig.defaultSize,
      );
      await expectLater(
        find.byType(EmptyStateWidget),
        matchesGoldenFile('goldens/empty_state_gradient_light.png'),
      );
    });

    testWidgets('compact mode - light theme', (tester) async {
      await tester.setGoldenSize(GoldenTestConfig.compactSize);
      await tester.pumpGoldenWidget(
        const EmptyStateWidget(
          title: 'No Data',
          message: 'Nothing to show here.',
          icon: Icons.inbox_outlined,
          compact: true,
        ),
        isDark: false,
        size: GoldenTestConfig.compactSize,
      );
      await expectLater(
        find.byType(EmptyStateWidget),
        matchesGoldenFile('goldens/empty_state_compact_light.png'),
      );
    });
  });
}
