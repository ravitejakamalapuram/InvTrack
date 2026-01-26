import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/presentation/extensions/fire_entity_ui_extensions.dart';

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
  });
}
