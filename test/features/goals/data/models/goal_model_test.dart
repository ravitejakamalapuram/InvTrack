import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/goals/data/models/goal_model.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/ui_extensions/goal_type_ui.dart';

void main() {
  final testDate = DateTime(2024, 6, 15);
  final testTimestamp = Timestamp.fromDate(testDate);

  GoalEntity _makeGoal({
    List<int> milestones = const [],
    String currency = 'INR',
  }) {
    return GoalEntity(
      id: 'goal-model-1',
      name: 'Test Model Goal',
      type: GoalType.targetAmount,
      targetAmount: 200000,
      trackingMode: GoalTrackingMode.all,
      icon: GoalIcons.defaultIcon,
      colorValue: GoalColors.defaultColor.toARGB32(),
      isArchived: false,
      createdAt: testDate,
      updatedAt: testDate,
      currency: currency,
      notificationMilestonesSent: milestones,
    );
  }

  Map<String, dynamic> _baseFirestoreData() {
    return {
      'name': 'Test Model Goal',
      'type': 'targetAmount',
      'targetAmount': 200000.0,
      'targetMonthlyIncome': null,
      'targetDate': null,
      'trackingMode': 'all',
      'linkedInvestmentIds': <String>[],
      'linkedTypes': <String>[],
      'icon': GoalIcons.defaultIcon,
      'colorValue': GoalColors.defaultColor.toARGB32(),
      'isArchived': false,
      'currency': 'INR',
      'notificationMilestonesSent': <dynamic>[],
      'createdAt': testTimestamp,
      'updatedAt': testTimestamp,
    };
  }

  group('GoalModel.toFirestore', () {
    test('includes notificationMilestonesSent when empty', () {
      final goal = _makeGoal();
      final doc = GoalModel.toFirestore(goal);

      expect(doc.containsKey('notificationMilestonesSent'), isTrue);
      expect(doc['notificationMilestonesSent'], isEmpty);
    });

    test('includes notificationMilestonesSent with single milestone', () {
      final goal = _makeGoal(milestones: [25]);
      final doc = GoalModel.toFirestore(goal);

      expect(doc['notificationMilestonesSent'], equals([25]));
    });

    test('includes notificationMilestonesSent with multiple milestones', () {
      final goal = _makeGoal(milestones: [25, 50, 75]);
      final doc = GoalModel.toFirestore(goal);

      expect(doc['notificationMilestonesSent'], equals([25, 50, 75]));
    });

    test('includes all four standard milestones', () {
      final goal = _makeGoal(milestones: [25, 50, 75, 100]);
      final doc = GoalModel.toFirestore(goal);

      expect(doc['notificationMilestonesSent'], containsAll([25, 50, 75, 100]));
      expect(doc['notificationMilestonesSent'].length, 4);
    });

    test('includes currency field', () {
      final goal = _makeGoal(currency: 'USD');
      final doc = GoalModel.toFirestore(goal);

      expect(doc['currency'], 'USD');
    });

    test('updatedAt uses server timestamp', () {
      final goal = _makeGoal();
      final doc = GoalModel.toFirestore(goal);

      expect(doc['updatedAt'], FieldValue.serverTimestamp());
    });

    test('createdAt converts DateTime to Timestamp', () {
      final goal = _makeGoal();
      final doc = GoalModel.toFirestore(goal);

      expect(doc['createdAt'], isA<Timestamp>());
      expect((doc['createdAt'] as Timestamp).toDate(), testDate);
    });
  });

  group('GoalModel.fromFirestore', () {
    test('parses notificationMilestonesSent with values', () {
      final data = {
        ..._baseFirestoreData(),
        'notificationMilestonesSent': <dynamic>[25, 50],
      };

      final goal = GoalModel.fromFirestore(data, 'goal-model-1');

      expect(goal.notificationMilestonesSent, equals([25, 50]));
    });

    test('parses notificationMilestonesSent with all four milestones', () {
      final data = {
        ..._baseFirestoreData(),
        'notificationMilestonesSent': <dynamic>[25, 50, 75, 100],
      };

      final goal = GoalModel.fromFirestore(data, 'goal-model-1');

      expect(goal.notificationMilestonesSent, equals([25, 50, 75, 100]));
    });

    test('backward compat: returns empty list when notificationMilestonesSent is null', () {
      final data = {
        ..._baseFirestoreData(),
        'notificationMilestonesSent': null,
      };

      final goal = GoalModel.fromFirestore(data, 'goal-model-1');

      expect(goal.notificationMilestonesSent, isEmpty);
    });

    test('backward compat: returns empty list when notificationMilestonesSent key is absent', () {
      final data = Map<String, dynamic>.from(_baseFirestoreData())
        ..remove('notificationMilestonesSent');

      final goal = GoalModel.fromFirestore(data, 'goal-model-1');

      expect(goal.notificationMilestonesSent, isEmpty);
    });

    test('parses empty notificationMilestonesSent list', () {
      final data = {
        ..._baseFirestoreData(),
        'notificationMilestonesSent': <dynamic>[],
      };

      final goal = GoalModel.fromFirestore(data, 'goal-model-1');

      expect(goal.notificationMilestonesSent, isEmpty);
    });

    test('sets correct goal id from document id parameter', () {
      final data = _baseFirestoreData();

      final goal = GoalModel.fromFirestore(data, 'specific-doc-id');

      expect(goal.id, 'specific-doc-id');
    });

    test('parses currency field with backward compat default', () {
      final data = Map<String, dynamic>.from(_baseFirestoreData())
        ..remove('currency');

      final goal = GoalModel.fromFirestore(data, 'goal-model-1');

      expect(goal.currency, 'USD');
    });

    test('round-trips notificationMilestonesSent through toFirestore and fromFirestore', () {
      final originalGoal = _makeGoal(milestones: [25, 50]);
      final doc = GoalModel.toFirestore(originalGoal);

      // Simulate reading back from Firestore (replace FieldValue with Timestamp for updatedAt)
      final firestoreDoc = {
        ...doc,
        'createdAt': testTimestamp,
        'updatedAt': testTimestamp,
      };

      final restoredGoal = GoalModel.fromFirestore(firestoreDoc, 'goal-model-1');

      expect(restoredGoal.notificationMilestonesSent, equals([25, 50]));
      expect(restoredGoal.name, originalGoal.name);
      expect(restoredGoal.targetAmount, originalGoal.targetAmount);
    });
  });
}