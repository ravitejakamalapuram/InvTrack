// A11 (#755, PLAN-05, GAP2-01): FIRE settings store a birth year instead of a
// frozen age, and the currency their amounts are in. Documents written
// before this change stay readable.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/fire_number/data/models/fire_settings_model.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';

void main() {
  group('legacy documents (schema 1)', () {
    final legacy = <String, dynamic>{
      'monthlyExpenses': 50000,
      'safeWithdrawalRate': 4.0,
      'currentAge': 30,
      'targetFireAge': 45,
      'fireType': 'coast',
      'isSetupComplete': true,
      'schemaVersion': 1,
      'createdAt': Timestamp.fromDate(DateTime(2024, 10, 1)),
      'updatedAt': Timestamp.fromDate(DateTime(2026, 3, 1)),
    };

    test('derive the birth year from the age and the year it was entered', () {
      final settings = FireSettingsModel.fromFirestore(legacy, 'settings');

      expect(settings.birthYear, 1994);
      // The age advances: 32 in 2026, so 13 years to 45 rather than 15.
      expect(settings.ageAt(DateTime(2026, 10, 2)), 32);
      expect(settings.yearsToFireAt(DateTime(2026, 10, 2)), 13);
    });

    test('have no currency, no other assets and no declared SIP', () {
      final settings = FireSettingsModel.fromFirestore(legacy, 'settings');

      expect(settings.currency, isNull);
      expect(settings.otherAssets, 0);
      expect(settings.monthlySip, isNull);
    });

    test('still parse Coast FIRE, which now targets like Regular', () {
      final settings = FireSettingsModel.fromFirestore(legacy, 'settings');

      expect(settings.fireType, FireType.coast);
      expect(settings.fireType.effective, FireType.regular);
      expect(FireType.selectable, [
        FireType.lean,
        FireType.regular,
        FireType.fat,
      ]);
    });
  });

  group('schema 2', () {
    final settings = FireSettingsEntity(
      id: 'settings',
      monthlyExpenses: 75000,
      birthYear: 1990,
      targetFireAge: 50,
      isSetupComplete: true,
      currency: 'INR',
      otherAssets: 1500000,
      monthlySip: 40000,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    test('writes the birth year, the currency and the new amounts', () {
      final data = FireSettingsModel.toFirestore(settings);

      expect(data['schemaVersion'], 2);
      expect(data['birthYear'], 1990);
      expect(data['currency'], 'INR');
      expect(data['otherAssets'], 1500000);
      expect(data['monthlySip'], 40000);
      // Older app versions read currentAge as a required int.
      expect(data['currentAge'], DateTime.now().year - 1990);
    });

    test('round-trips through Firestore', () {
      final data = FireSettingsModel.toFirestore(settings)
        ..['updatedAt'] = Timestamp.fromDate(DateTime(2026, 1, 1));

      final read = FireSettingsModel.fromFirestore(data, 'settings');

      expect(read, settings);
      expect(read.birthYear, 1990);
      expect(read.currency, 'INR');
      expect(read.otherAssets, 1500000);
      expect(read.monthlySip, 40000);
    });

    test('round-trips through the export JSON', () {
      final read = FireSettingsEntity.fromJson(settings.toJson());

      expect(read, settings);
      expect(read.monthlySip, 40000);
    });

    test('an export written before this change is read as the old one', () {
      final read = FireSettingsEntity.fromJson({
        'id': 'old',
        'monthlyExpenses': 50000.0,
        'currentAge': 30,
        'targetFireAge': 45,
        'createdAt': '2024-01-01T00:00:00.000',
        'updatedAt': '2024-01-01T00:00:00.000',
      });

      expect(read.birthYear, 1994);
      expect(read.currency, isNull);
    });
  });
}
