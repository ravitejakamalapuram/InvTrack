// A64 (#811): GoalModel, the Firestore mapper for goals. A goal carries a
// target amount and a currency, so the tests pin every field, the defaults for
// optional fields, and that a malformed document fails loudly.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/goals/data/models/goal_model.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/ui_extensions/goal_type_ui.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

void main() {
  final created = DateTime(2026, 1, 5);
  final updated = DateTime(2026, 2, 6);
  final target = DateTime(2030, 4, 1);

  final full = GoalEntity(
    id: 'goal-1',
    name: 'House',
    type: GoalType.targetDate,
    targetAmount: 2500000.5,
    targetMonthlyIncome: 12000.25,
    targetDate: target,
    trackingMode: GoalTrackingMode.byType,
    linkedInvestmentIds: const ['inv-1', 'inv-2'],
    linkedTypes: const [InvestmentType.fixedDeposit, InvestmentType.bonds],
    icon: '🏠',
    colorValue: 0xFF112233,
    isArchived: true,
    currency: 'EUR',
    createdAt: created,
    updatedAt: updated,
  );

  Map<String, dynamic> minimalDoc() => {
    'name': 'Rainy day',
    'type': 'targetAmount',
    'targetAmount': 50000,
    'trackingMode': 'all',
    'createdAt': Timestamp.fromDate(created),
  };

  GoalEntity map(Map<String, dynamic> data, {String base = 'INR'}) =>
      GoalModel.fromFirestore(data, 'goal-1', baseCurrency: base);

  group('GoalModel.toFirestore', () {
    test('writes every field of a full goal', () {
      final data = GoalModel.toFirestore(full);

      expect(data['name'], 'House');
      expect(data['type'], 'targetDate');
      expect(data['targetAmount'], 2500000.5);
      expect(data['targetMonthlyIncome'], 12000.25);
      expect(data['targetDate'], equals(Timestamp.fromDate(target)));
      expect(data['trackingMode'], 'byType');
      expect(data['linkedInvestmentIds'], equals(['inv-1', 'inv-2']));
      expect(data['linkedTypes'], equals(['fixedDeposit', 'bonds']));
      expect(data['icon'], '🏠');
      expect(data['colorValue'], 0xFF112233);
      expect(data['isArchived'], isTrue);
      expect(data['currency'], 'EUR');
      expect(data['createdAt'], equals(Timestamp.fromDate(created)));
      expect(data['updatedAt'], isA<FieldValue>());
      expect(data.keys, hasLength(14));
    });

    test('writes null target date and income for a goal without them', () {
      final goal = GoalEntity(
        id: 'g',
        name: 'Plain',
        type: GoalType.targetAmount,
        targetAmount: 10,
        trackingMode: GoalTrackingMode.all,
        icon: GoalIcons.defaultIcon,
        colorValue: 1,
        createdAt: created,
        updatedAt: updated,
        currency: 'INR',
      );

      final data = GoalModel.toFirestore(goal);

      expect(data['targetMonthlyIncome'], isNull);
      expect(data['targetDate'], isNull);
      expect(data['isArchived'], isFalse);
      expect(data['linkedInvestmentIds'], isEmpty);
      expect(data['linkedTypes'], isEmpty);
    });
  });

  group('GoalModel.fromFirestore', () {
    test('a full document round-trips to an equal goal', () {
      final doc = {
        ...GoalModel.toFirestore(full),
        'updatedAt': Timestamp.fromDate(updated),
      };

      expect(map(doc), equals(full));
    });

    test('a minimal document takes the documented defaults', () {
      final goal = map(minimalDoc());

      expect(goal.id, 'goal-1');
      expect(goal.name, 'Rainy day');
      expect(goal.type, GoalType.targetAmount);
      expect(goal.targetAmount, 50000.0);
      expect(goal.targetMonthlyIncome, isNull);
      expect(goal.targetDate, isNull);
      expect(goal.trackingMode, GoalTrackingMode.all);
      expect(goal.linkedInvestmentIds, isEmpty);
      expect(goal.linkedTypes, isEmpty);
      expect(goal.icon, GoalIcons.defaultIcon);
      expect(goal.colorValue, GoalColors.defaultColor.toARGB32());
      expect(goal.isArchived, isFalse);
      expect(goal.currency, 'INR');
      expect(goal.currencyAssumed, isTrue);
      expect(goal.createdAt, equals(created));
    });

    test('a missing updatedAt becomes about now', () {
      final before = DateTime.now();
      final goal = map(minimalDoc());
      final after = DateTime.now();

      expect(goal.updatedAt.isBefore(before), isFalse);
      expect(goal.updatedAt.isAfter(after), isFalse);
    });

    test('a missing currency takes the base currency, never USD', () {
      final goal = map(minimalDoc(), base: 'GBP');

      expect(goal.currency, 'GBP');
      expect(goal.currencyAssumed, isTrue);
    });

    test('a stored currency wins over the base and is not assumed', () {
      final goal = map({...minimalDoc(), 'currency': 'JPY'}, base: 'GBP');

      expect(goal.currency, 'JPY');
      expect(goal.currencyAssumed, isFalse);
    });

    test('an explicit null currency is treated as missing', () {
      final goal = map({...minimalDoc(), 'currency': null});

      expect(goal.currency, 'INR');
      expect(goal.currencyAssumed, isTrue);
    });

    test('integer and double amounts both map to double', () {
      expect(
        map({...minimalDoc(), 'targetAmount': 7}).targetAmount,
        equals(7.0),
      );
      expect(
        map({
          ...minimalDoc(),
          'targetAmount': 7.75,
          'targetMonthlyIncome': 3,
        }).targetMonthlyIncome,
        equals(3.0),
      );
    });

    test('unknown enum values fall back instead of throwing', () {
      final goal = map({
        ...minimalDoc(),
        'type': 'futureType',
        'trackingMode': 'futureMode',
        'linkedTypes': ['fixedDeposit', 'notARealType'],
      });

      expect(goal.type, GoalType.targetAmount);
      expect(goal.trackingMode, GoalTrackingMode.all);
      expect(goal.linkedTypes, [
        InvestmentType.fixedDeposit,
        InvestmentType.other,
      ]);
    });

    test('an archived flag in the document is kept', () {
      expect(map({...minimalDoc(), 'isArchived': true}).isArchived, isTrue);
    });
  });

  group('GoalModel.fromFirestore with a malformed document', () {
    test('a missing name throws', () {
      expect(
        () => map({...minimalDoc()}..remove('name')),
        throwsA(isA<TypeError>()),
      );
    });

    test('a missing target amount throws', () {
      expect(
        () => map({...minimalDoc()}..remove('targetAmount')),
        throwsA(isA<TypeError>()),
      );
    });

    test('a missing createdAt throws', () {
      expect(
        () => map({...minimalDoc()}..remove('createdAt')),
        throwsA(isA<TypeError>()),
      );
    });

    test('a missing type throws', () {
      expect(
        () => map({...minimalDoc()}..remove('type')),
        throwsA(isA<TypeError>()),
      );
    });

    test('a missing tracking mode throws', () {
      expect(
        () => map({...minimalDoc()}..remove('trackingMode')),
        throwsA(isA<TypeError>()),
      );
    });

    test('a string target amount throws instead of becoming zero', () {
      expect(
        () => map({...minimalDoc(), 'targetAmount': '50000'}),
        throwsA(isA<TypeError>()),
      );
    });

    test('a numeric name throws', () {
      expect(
        () => map({...minimalDoc(), 'name': 42}),
        throwsA(isA<TypeError>()),
      );
    });

    test('a createdAt that is not a Timestamp throws', () {
      expect(
        () => map({...minimalDoc(), 'createdAt': '2026-01-05'}),
        throwsA(isA<TypeError>()),
      );
    });

    test('a targetDate that is not a Timestamp throws', () {
      expect(
        () => map({...minimalDoc(), 'targetDate': 20300401}),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
