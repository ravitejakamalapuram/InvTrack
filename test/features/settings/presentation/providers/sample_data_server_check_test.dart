// A121 (#895): "Try Sample Data" wrote sample investments straight into the
// account. When Overview had wrongly decided the account was empty (an empty
// offline cache), they landed in a real portfolio. activateSampleData must
// first ask the server and write nothing unless both investment collections
// and both goal collections are empty there: sample data includes a goal.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/settings/data/services/sample_data_service.dart';
import 'package:inv_tracker/features/settings/presentation/providers/sample_data_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/mock_analytics_service.dart';
import '../../../goals/data/repositories/mock_goal_repository.dart';
import '../../../investment/data/repositories/mock_investment_repository.dart';

class _SpySampleDataService extends SampleDataService {
  _SpySampleDataService(super.investments, super.goals);

  int createCalls = 0;

  @override
  Future<SampleDataResult> createSampleData({
    required String baseCurrency,
    DateTime? asOf,
  }) {
    createCalls++;
    return super.createSampleData(baseCurrency: baseCurrency, asOf: asOf);
  }
}

/// A repository whose server cannot be reached.
class _OfflineInvestmentRepository extends FakeInvestmentRepository {
  @override
  Future<bool> hasAnyInvestmentOnServer() async {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
      message: 'The service is currently unavailable.',
    );
  }
}

/// A repository whose server rejects the read (a rules or App Check change).
class _DeniedInvestmentRepository extends FakeInvestmentRepository {
  @override
  Future<bool> hasAnyInvestmentOnServer() async {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
  }
}

/// A repository whose server check times out.
class _TimedOutInvestmentRepository extends FakeInvestmentRepository {
  @override
  Future<bool> hasAnyInvestmentOnServer() async {
    throw TimeoutException('Server check timed out.');
  }
}

/// A goal repository whose server cannot be reached.
class _OfflineGoalRepository extends FakeGoalRepository {
  @override
  Future<bool> hasAnyGoalOnServer() async {
    throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
  }
}

final _existingGoal = GoalEntity(
  id: 'goal-real',
  name: 'House',
  type: GoalType.targetAmount,
  targetAmount: 5000000,
  trackingMode: GoalTrackingMode.all,
  icon: GoalIcons.defaultIcon,
  colorValue: 0xFF4CAF50,
  createdAt: DateTime(2025, 4, 1),
  updatedAt: DateTime(2025, 4, 1),
  currency: 'INR',
);

final _existing = InvestmentEntity(
  id: 'inv-real',
  name: 'HDFC FD',
  type: InvestmentType.fixedDeposit,
  status: InvestmentStatus.open,
  currency: 'INR',
  createdAt: DateTime(2025, 4, 1),
  updatedAt: DateTime(2025, 4, 1),
);

void main() {
  late FakeGoalRepository goals;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    goals = FakeGoalRepository();
  });

  ({ProviderContainer container, _SpySampleDataService service}) build(
    FakeInvestmentRepository investments,
  ) {
    final service = _SpySampleDataService(investments, goals);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        currencyCodeProvider.overrideWithValue('INR'),
        investmentRepositoryProvider.overrideWithValue(investments),
        goalRepositoryProvider.overrideWithValue(goals),
        sampleDataServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, service: service);
  }

  test('refuses when the server has an active investment, and writes '
      'nothing', () async {
    final investments = FakeInvestmentRepository()
      ..seed(investments: [_existing]);
    final (:container, :service) = build(investments);

    final activated = await container
        .read(sampleDataModeProvider.notifier)
        .activateSampleData();

    expect(activated, isFalse);
    expect(service.createCalls, 0);
    expect(investments.investments.map((i) => i.id), ['inv-real']);
    expect(investments.cashFlows, isEmpty);
    expect(goals.goals, isEmpty);
    final state = container.read(sampleDataModeProvider);
    expect(state.isActive, isFalse);
    expect(state.isLoading, isFalse);
    expect(state.error, 'account_not_empty');
    expect(prefs.getBool('sample_data_mode_active'), isNull);
  });

  test('refuses when the server has only an archived investment', () async {
    final investments = FakeInvestmentRepository()
      ..seed(archivedInvestments: [_existing]);
    final (:container, :service) = build(investments);

    final activated = await container
        .read(sampleDataModeProvider.notifier)
        .activateSampleData();

    expect(activated, isFalse);
    expect(service.createCalls, 0);
    expect(investments.investments, isEmpty);
    expect(investments.cashFlows, isEmpty);
    expect(goals.goals, isEmpty);
  });

  test('refuses when the server cannot be reached (offline), and writes '
      'nothing', () async {
    final investments = _OfflineInvestmentRepository();
    final (:container, :service) = build(investments);

    final activated = await container
        .read(sampleDataModeProvider.notifier)
        .activateSampleData();

    expect(activated, isFalse);
    expect(service.createCalls, 0);
    expect(investments.investments, isEmpty);
    expect(investments.cashFlows, isEmpty);
    expect(goals.goals, isEmpty);
    final state = container.read(sampleDataModeProvider);
    expect(state.isActive, isFalse);
    expect(state.isLoading, isFalse);
    expect(state.error, 'server_unreachable');
    expect(prefs.getBool('sample_data_mode_active'), isNull);
  });

  test('reports a timed-out server check as unreachable, and writes '
      'nothing', () async {
    final investments = _TimedOutInvestmentRepository();
    final (:container, :service) = build(investments);

    final activated = await container
        .read(sampleDataModeProvider.notifier)
        .activateSampleData();

    expect(activated, isFalse);
    expect(service.createCalls, 0);
    final state = container.read(sampleDataModeProvider);
    expect(state.isActive, isFalse);
    expect(state.isLoading, isFalse);
    expect(state.error, 'server_unreachable');
  });

  for (final (label, seed) in [
    (
      'an active goal',
      (FakeGoalRepository g) => g.seed(goals: [_existingGoal]),
    ),
    (
      'only an archived goal',
      (FakeGoalRepository g) => g.seed(archivedGoals: [_existingGoal]),
    ),
  ]) {
    test('refuses when the server has $label and no investments, and writes '
        'nothing', () async {
      seed(goals);
      final investments = FakeInvestmentRepository();
      final (:container, :service) = build(investments);

      final activated = await container
          .read(sampleDataModeProvider.notifier)
          .activateSampleData();

      expect(activated, isFalse);
      expect(service.createCalls, 0);
      expect(investments.investments, isEmpty);
      expect(investments.cashFlows, isEmpty);
      expect(goals.goals.length + goals.archivedGoals.length, 1);
      final state = container.read(sampleDataModeProvider);
      expect(state.isActive, isFalse);
      expect(state.isLoading, isFalse);
      expect(prefs.getBool('sample_data_mode_active'), isNull);
    });
  }

  test('refuses when the goals cannot be checked on the server', () async {
    goals = _OfflineGoalRepository();
    final investments = FakeInvestmentRepository();
    final (:container, :service) = build(investments);

    final activated = await container
        .read(sampleDataModeProvider.notifier)
        .activateSampleData();

    expect(activated, isFalse);
    expect(service.createCalls, 0);
    expect(investments.investments, isEmpty);
    expect(goals.goals, isEmpty);
    final state = container.read(sampleDataModeProvider);
    expect(state.isLoading, isFalse);
    expect(state.error, 'server_unreachable');
  });

  test('refuses when the server rejects the check (not just offline), and '
      'writes nothing', () async {
    final investments = _DeniedInvestmentRepository();
    final (:container, :service) = build(investments);

    final activated = await container
        .read(sampleDataModeProvider.notifier)
        .activateSampleData();

    expect(activated, isFalse);
    expect(service.createCalls, 0);
    expect(investments.investments, isEmpty);
    expect(goals.goals, isEmpty);
    final state = container.read(sampleDataModeProvider);
    expect(state.isLoading, isFalse);
    expect(state.error, 'server_check_failed');
  });

  test('creates sample data once when the server confirms every collection '
      'is empty', () async {
    final investments = FakeInvestmentRepository();
    final (:container, :service) = build(investments);

    final activated = await container
        .read(sampleDataModeProvider.notifier)
        .activateSampleData();

    expect(activated, isTrue);
    expect(service.createCalls, 1);
    expect(investments.investments, isNotEmpty);
    final state = container.read(sampleDataModeProvider);
    expect(state.isActive, isTrue);
    expect(
      state.sampleInvestmentIds,
      unorderedEquals(investments.investments.map((i) => i.id)),
    );
    expect(prefs.getBool('sample_data_mode_active'), isTrue);
  });
}
