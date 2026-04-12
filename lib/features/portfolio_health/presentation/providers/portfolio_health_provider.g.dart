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
    r'c14eaf50c268915a06d675bbbd981091ee74125b';

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
    r'a7549913c268710b3c78c6a2c03113afba737bcc';

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

String _$portfolioHealthHash() => r'08b557c43445a3d982aaaff94852a8c8b3441d03';

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
    r'9d1336bbf32cbe5dd60f3bdc2db10c1326b201a0';

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
    r'8ea34a10ade8e7de1f62c8c3390c02b26aadd9a3';

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
    r'213e97b9bfa6f78c6c8fd3106a3c55283b98d695';

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
    r'42e226ef43356254a65ae24a7d687929ebcbad4a';
