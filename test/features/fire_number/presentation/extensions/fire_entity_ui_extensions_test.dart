import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/presentation/extensions/fire_entity_ui_extensions.dart';

import '../../../../helpers/contrast.dart';

void main() {
  group('FireTypeUIExtension', () {
    test('icon returns correct icons for each FireType', () {
      expect(FireType.lean.icon, Icons.eco_outlined);
      expect(FireType.regular.icon, Icons.balance_outlined);
      expect(FireType.fat.icon, Icons.diamond_outlined);
      expect(FireType.coast.icon, Icons.beach_access_outlined);
      expect(FireType.barista.icon, Icons.coffee_outlined);
    });

    test('all FireTypes have valid icons', () {
      for (final type in FireType.values) {
        expect(type.icon, isA<IconData>());
      }
    });
  });

  group('FireProgressStatusUIExtension', () {
    test('color returns correct colors for each status', () {
      // Uses AppColors design system colors
      expect(FireProgressStatus.notStarted.color, AppColors.neutral500Light);
      expect(FireProgressStatus.behind.color, AppColors.warningLight);
      expect(FireProgressStatus.onTrack.color, AppColors.accentLight);
      expect(FireProgressStatus.ahead.color, AppColors.successLight);
      expect(FireProgressStatus.achieved.color, AppColors.successLight);
      expect(FireProgressStatus.coasting.color, AppColors.graphTeal);
    });

    test('all FireProgressStatus values have valid colors', () {
      for (final status in FireProgressStatus.values) {
        expect(status.color, isA<Color>());
      }
    });

    group('colorForBrightness', () {
      // The dark value of each status, from the design tokens.
      const dark = {
        FireProgressStatus.notStarted: AppColors.neutral400Dark,
        FireProgressStatus.notEnoughHistory: AppColors.neutral400Dark,
        FireProgressStatus.behind: AppColors.warningDark,
        FireProgressStatus.onTrack: AppColors.accentDark,
        FireProgressStatus.ahead: AppColors.successDark,
        FireProgressStatus.achieved: AppColors.successDark,
        FireProgressStatus.coasting: AppColors.graphTeal,
      };

      test('every status has a dark value', () {
        expect(dark.keys.toSet(), FireProgressStatus.values.toSet());
      });

      test('light brightness gives color, dark gives the dark token', () {
        for (final status in FireProgressStatus.values) {
          expect(status.colorForBrightness(Brightness.light), status.color);
          expect(status.colorForBrightness(Brightness.dark), dark[status]);
          expect(status.colorDark, dark[status]);
        }
      });

      test('the dark value reads at least 4.5:1 on the dark card', () {
        for (final status in FireProgressStatus.values) {
          expect(
            contrastRatio(
              status.colorForBrightness(Brightness.dark),
              AppColors.cardDark,
            ),
            greaterThanOrEqualTo(kMinText),
            reason: '${status.name} in dark',
          );
        }
      });
    });
  });
}
