// A21 / ANLY-07: the health score is worked out from one complete converted
// snapshot. While the snapshot is still converting there is no score, and a
// partial score never reaches auto-save. An empty portfolio has no score.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/portfolio_health/data/repositories/health_score_repository.dart';
import 'package:inv_tracker/features/portfolio_health/data/services/health_score_auto_save_service.dart';
import 'package:inv_tracker/features/portfolio_health/domain/entities/portfolio_health_score.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/providers/portfolio_health_provider.dart';

/// USD → INR at 88.0, held until [gate] completes.
class _GatedUsdInr implements CurrencyConversionService {
  final gate = Completer<void>();

  @override
  Future<double> getRate({
    required String from,
    required String to,
    DateTime? date,
  }) async => from == to ? 1.0 : 88.0;

  @override
  Future<Map<String, double>> batchConvertHistorical({
    required Map<String, ConversionRequest> requests,
    required String to,
  }) async {
    await gate.future;
    return {
      for (final e in requests.entries)
        e.key: e.value.from == to ? e.value.amount : e.value.amount * 88.0,
    };
  }

  @override
  Future<double?> getLastKnownRate({
    required String from,
    required String to,
  }) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records what the provider hands to auto-save.
class _RecordingAutoSave implements HealthScoreAutoSaveService {
  final updates = <PortfolioHealthScore>[];
  var clears = 0;

  /// The score auto-save would write next, as the real service holds it.
  PortfolioHealthScore? held;

  @override
  void updateScore(PortfolioHealthScore score) {
    updates.add(score);
    held = score;
  }

  @override
  void clearScore() {
    clears++;
    held = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records the snapshots auto-save writes.
class _RecordingRepository implements HealthScoreRepository {
  final saved = <PortfolioHealthScore>[];

  @override
  Future<void> saveSnapshot(PortfolioHealthScore score) async =>
      saved.add(score);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ComponentScore _component(String name, double weight) => ComponentScore(
  name: name,
  score: 70,
  weight: weight,
  description: name,
  suggestions: const [],
);

/// A score worked out earlier, still held by auto-save.
PortfolioHealthScore _heldScore() => PortfolioHealthScore(
  overallScore: 70,
  returnsPerformance: _component('Returns Performance', 0.30),
  diversification: _component('Diversification', 0.25),
  liquidity: _component('Liquidity', 0.20),
  goalAlignment: _component('Goal Alignment', 0.15),
  actionReadiness: _component('Action Readiness', 0.10),
  calculatedAt: DateTime(2026, 10, 3),
);

final _usdBond = InvestmentEntity(
  id: 'bond',
  name: 'US bond',
  type: InvestmentType.bonds,
  status: InvestmentStatus.closed,
  currency: 'USD',
  createdAt: DateTime(2025, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

final _usdFlows = [
  CashFlowEntity(
    id: 'b1',
    investmentId: 'bond',
    type: CashFlowType.invest,
    amount: 1000,
    currency: 'USD',
    date: DateTime(2025, 1, 1),
    createdAt: DateTime(2025, 1, 1),
  ),
  CashFlowEntity(
    id: 'b2',
    investmentId: 'bond',
    type: CashFlowType.returnFlow,
    amount: 1080,
    currency: 'USD',
    date: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
  ),
];

ProviderContainer _container({
  required List<InvestmentEntity> investments,
  required List<CashFlowEntity> flows,
  required CurrencyConversionService conversion,
  required _RecordingAutoSave autoSave,
}) {
  final container = ProviderContainer(
    overrides: [
      isAuthenticatedProvider.overrideWith((ref) => true),
      allInvestmentsProvider.overrideWith((ref) => Stream.value(investments)),
      archivedInvestmentsProvider.overrideWith((ref) => Stream.value(const [])),
      allCashFlowsStreamProvider.overrideWith((ref) => Stream.value(flows)),
      for (final inv in investments)
        cashFlowsByInvestmentProvider(inv.id).overrideWith(
          (ref) => Stream.value([
            for (final cf in flows)
              if (cf.investmentId == inv.id) cf,
          ]),
        ),
      currencyCodeProvider.overrideWith((ref) => 'INR'),
      currencyConversionServiceProvider.overrideWith((ref) => conversion),
      allGoalsProgressProvider.overrideWithValue(const AsyncValue.data([])),
      healthScoreAutoSaveServiceProvider.overrideWithValue(autoSave),
      valuationDateProvider.overrideWithValue(DateTime(2026, 10, 4)),
    ],
  );
  addTearDown(container.dispose);
  container.listen(portfolioHealthProvider, (_, _) {});
  return container;
}

Future<void> _settle() async {
  for (var i = 0; i < 25; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  test(
    'no score is produced or saved while the snapshot is converting',
    () async {
      final conversion = _GatedUsdInr();
      final autoSave = _RecordingAutoSave();
      final container = _container(
        investments: [_usdBond],
        flows: _usdFlows,
        conversion: conversion,
        autoSave: autoSave,
      );
      await _settle();

      expect(container.read(portfolioHealthProvider).isLoading, isTrue);
      expect(autoSave.updates, isEmpty);

      // Once converted, the whole portfolio is scored and saved once.
      conversion.gate.complete();
      await _settle();

      final score = container.read(portfolioHealthProvider).requireValue!;
      // 8% for a year: 60 + ((0.08 − 0.06) / 0.05) × 20 = 68.
      expect(score.returnsPerformance.score, closeTo(68.0, 1e-6));
      expect(autoSave.updates, [score]);
    },
  );

  test('a score held from before is dropped as soon as a new snapshot '
      'starts loading', () async {
    // For example the previous account's score after switching accounts, or
    // the score from before an edit, while the new snapshot converts.
    final conversion = _GatedUsdInr();
    final autoSave = _RecordingAutoSave()..held = _heldScore();
    final container = _container(
      investments: [_usdBond],
      flows: _usdFlows,
      conversion: conversion,
      autoSave: autoSave,
    );
    await _settle();

    expect(container.read(portfolioHealthProvider).isLoading, isTrue);
    expect(autoSave.held, isNull);
    conversion.gate.complete();
  });

  test('an empty portfolio has no score, and nothing is saved', () async {
    final autoSave = _RecordingAutoSave();
    final container = _container(
      investments: const [],
      flows: const [],
      conversion: _GatedUsdInr(),
      autoSave: autoSave,
    );
    await _settle();

    expect(container.read(portfolioHealthProvider).value, isNull);
    expect(container.read(portfolioHealthProvider).hasValue, isTrue);
    expect(autoSave.updates, isEmpty);
    expect(autoSave.clears, isPositive);
    expect(autoSave.held, isNull);
  });

  test('a new account gets a new auto-save service, so the score of the '
      'previous account is never saved under it', () async {
    final users = StreamController<UserEntity?>();
    final repository = _RecordingRepository();
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => users.stream),
        healthScoreRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(users.close);
    container.listen(healthScoreAutoSaveServiceProvider, (_, _) {});

    users.add(const UserEntity(id: 'a', email: 'a@example.com'));
    await _settle();
    final first = container.read(healthScoreAutoSaveServiceProvider)
      ..updateScore(_heldScore());

    users.add(const UserEntity(id: 'b', email: 'b@example.com'));
    await _settle();
    final second = container.read(healthScoreAutoSaveServiceProvider);
    await second.forceSave();
    await first.forceSave();

    expect(second, isNot(same(first)));
    expect(repository.saved, isEmpty);
  });
}
