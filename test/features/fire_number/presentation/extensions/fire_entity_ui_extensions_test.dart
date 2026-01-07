import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
      expect(FireProgressStatus.notStarted.color, Colors.grey);
      expect(FireProgressStatus.behind.color, Colors.orange);
      expect(FireProgressStatus.onTrack.color, Colors.blue);
      expect(FireProgressStatus.ahead.color, Colors.green);
      expect(FireProgressStatus.achieved.color, Colors.green);
      expect(FireProgressStatus.coasting.color, Colors.teal);
    });

    test('all FireProgressStatus values have valid colors', () {
      for (final status in FireProgressStatus.values) {
        expect(status.color, isA<Color>());
      }
    });
  });
}

