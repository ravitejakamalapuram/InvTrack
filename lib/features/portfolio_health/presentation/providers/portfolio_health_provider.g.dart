// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'portfolio_health_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for Health Score Repository

@ProviderFor(healthScoreRepository)
const healthScoreRepositoryProvider = HealthScoreRepositoryProvider._();

/// Provider for Health Score Repository

final class HealthScoreRepositoryProvider
    extends
        $FunctionalProvider<
          HealthScoreRepository,
          HealthScoreRepository,
          HealthScoreRepository
        >
    with $Provider<HealthScoreRepository> {
  /// Provider for Health Score Repository
  const HealthScoreRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'healthScoreRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$healthScoreRepositoryHash();

  @$internal
  @override
  $ProviderElement<HealthScoreRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  HealthScoreRepository create(Ref ref) {
    return healthScoreRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HealthScoreRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HealthScoreRepository>(value),
    );
  }
}

String _$healthScoreRepositoryHash() =>
    r'1067203be826aee7ce4ba7c5427daa2f1de327a7';

/// Provider for auto-save service

@ProviderFor(healthScoreAutoSaveService)
const healthScoreAutoSaveServiceProvider =
    HealthScoreAutoSaveServiceProvider._();

/// Provider for auto-save service

final class HealthScoreAutoSaveServiceProvider
    extends
        $FunctionalProvider<
          HealthScoreAutoSaveService,
          HealthScoreAutoSaveService,
          HealthScoreAutoSaveService
        >
    with $Provider<HealthScoreAutoSaveService> {
  /// Provider for auto-save service
  const HealthScoreAutoSaveServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'healthScoreAutoSaveServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$healthScoreAutoSaveServiceHash();

  @$internal
  @override
  $ProviderElement<HealthScoreAutoSaveService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  HealthScoreAutoSaveService create(Ref ref) {
    return healthScoreAutoSaveService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HealthScoreAutoSaveService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HealthScoreAutoSaveService>(value),
    );
  }
}

String _$healthScoreAutoSaveServiceHash() =>
    r'749bd1e4b7f5f0014f3d61149f9176c3ed8aec14';

/// Provider for Portfolio Health Score
///
/// Calculates health score based on:
/// - Returns Performance (30%): XIRR vs inflation
/// - Diversification (25%): Herfindahl index
/// - Liquidity (20%): % maturing in 90 days
/// - Goal Alignment (15%): % goals on-track
/// - Action Readiness (10%): Overdue renewals, stale investments

@ProviderFor(PortfolioHealth)
const portfolioHealthProvider = PortfolioHealthProvider._();

/// Provider for Portfolio Health Score
///
/// Calculates health score based on:
/// - Returns Performance (30%): XIRR vs inflation
/// - Diversification (25%): Herfindahl index
/// - Liquidity (20%): % maturing in 90 days
/// - Goal Alignment (15%): % goals on-track
/// - Action Readiness (10%): Overdue renewals, stale investments
final class PortfolioHealthProvider
    extends $AsyncNotifierProvider<PortfolioHealth, PortfolioHealthScore?> {
  /// Provider for Portfolio Health Score
  ///
  /// Calculates health score based on:
  /// - Returns Performance (30%): XIRR vs inflation
  /// - Diversification (25%): Herfindahl index
  /// - Liquidity (20%): % maturing in 90 days
  /// - Goal Alignment (15%): % goals on-track
  /// - Action Readiness (10%): Overdue renewals, stale investments
  const PortfolioHealthProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'portfolioHealthProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$portfolioHealthHash();

  @$internal
  @override
  PortfolioHealth create() => PortfolioHealth();
}

String _$portfolioHealthHash() => r'3fe703e9a1126deeaede0b0a2017d7c3ff1e3e70';

/// Provider for Portfolio Health Score
///
/// Calculates health score based on:
/// - Returns Performance (30%): XIRR vs inflation
/// - Diversification (25%): Herfindahl index
/// - Liquidity (20%): % maturing in 90 days
/// - Goal Alignment (15%): % goals on-track
/// - Action Readiness (10%): Overdue renewals, stale investments

abstract class _$PortfolioHealth extends $AsyncNotifier<PortfolioHealthScore?> {
  FutureOr<PortfolioHealthScore?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<AsyncValue<PortfolioHealthScore?>, PortfolioHealthScore?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<PortfolioHealthScore?>,
                PortfolioHealthScore?
              >,
              AsyncValue<PortfolioHealthScore?>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Provider for historical health score snapshots (last 12 weeks)

@ProviderFor(historicalHealthScores)
const historicalHealthScoresProvider = HistoricalHealthScoresProvider._();

/// Provider for historical health score snapshots (last 12 weeks)

final class HistoricalHealthScoresProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<HealthScoreSnapshotModel>>,
          List<HealthScoreSnapshotModel>,
          Stream<List<HealthScoreSnapshotModel>>
        >
    with
        $FutureModifier<List<HealthScoreSnapshotModel>>,
        $StreamProvider<List<HealthScoreSnapshotModel>> {
  /// Provider for historical health score snapshots (last 12 weeks)
  const HistoricalHealthScoresProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'historicalHealthScoresProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$historicalHealthScoresHash();

  @$internal
  @override
  $StreamProviderElement<List<HealthScoreSnapshotModel>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<HealthScoreSnapshotModel>> create(Ref ref) {
    return historicalHealthScores(ref);
  }
}

String _$historicalHealthScoresHash() =>
    r'f68c92d62710ddd247cf1e8ce9f9ce7c55f13a57';

/// Provider for chart data (simplified for trend visualization)

@ProviderFor(healthScoreChartData)
const healthScoreChartDataProvider = HealthScoreChartDataProvider._();

/// Provider for chart data (simplified for trend visualization)

final class HealthScoreChartDataProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Map<String, dynamic>>>,
          List<Map<String, dynamic>>,
          Stream<List<Map<String, dynamic>>>
        >
    with
        $FutureModifier<List<Map<String, dynamic>>>,
        $StreamProvider<List<Map<String, dynamic>>> {
  /// Provider for chart data (simplified for trend visualization)
  const HealthScoreChartDataProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'healthScoreChartDataProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$healthScoreChartDataHash();

  @$internal
  @override
  $StreamProviderElement<List<Map<String, dynamic>>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Map<String, dynamic>>> create(Ref ref) {
    return healthScoreChartData(ref);
  }
}

String _$healthScoreChartDataHash() =>
    r'7306e3e9052efe9b811c41ae579c3271a2fbc449';

/// Provider for latest health score value (for quick access)

@ProviderFor(latestHealthScoreValue)
const latestHealthScoreValueProvider = LatestHealthScoreValueProvider._();

/// Provider for latest health score value (for quick access)

final class LatestHealthScoreValueProvider
    extends $FunctionalProvider<double?, double?, double?>
    with $Provider<double?> {
  /// Provider for latest health score value (for quick access)
  const LatestHealthScoreValueProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'latestHealthScoreValueProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$latestHealthScoreValueHash();

  @$internal
  @override
  $ProviderElement<double?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  double? create(Ref ref) {
    return latestHealthScoreValue(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double?>(value),
    );
  }
}

String _$latestHealthScoreValueHash() =>
    r'ff4e2ea8c17a5435e98bb63dffddef32a939b669';

/// Provider for latest health score tier (for color coding)

@ProviderFor(latestHealthScoreTier)
const latestHealthScoreTierProvider = LatestHealthScoreTierProvider._();

/// Provider for latest health score tier (for color coding)

final class LatestHealthScoreTierProvider
    extends $FunctionalProvider<ScoreTier?, ScoreTier?, ScoreTier?>
    with $Provider<ScoreTier?> {
  /// Provider for latest health score tier (for color coding)
  const LatestHealthScoreTierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'latestHealthScoreTierProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$latestHealthScoreTierHash();

  @$internal
  @override
  $ProviderElement<ScoreTier?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ScoreTier? create(Ref ref) {
    return latestHealthScoreTier(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ScoreTier? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ScoreTier?>(value),
    );
  }
}

String _$latestHealthScoreTierHash() =>
    r'a989d2d04b56fd36efdfa039bc8d38ee58b9840a';
