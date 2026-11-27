// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'multi_currency_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for batch currency converter
///
/// **BUG FIX (2026-05-04)**: Handle null conversion service when unauthenticated
/// Returns a no-op converter that doesn't crash the app

@ProviderFor(batchCurrencyConverter)
const batchCurrencyConverterProvider = BatchCurrencyConverterProvider._();

/// Provider for batch currency converter
///
/// **BUG FIX (2026-05-04)**: Handle null conversion service when unauthenticated
/// Returns a no-op converter that doesn't crash the app

final class BatchCurrencyConverterProvider
    extends
        $FunctionalProvider<
          BatchCurrencyConverter?,
          BatchCurrencyConverter?,
          BatchCurrencyConverter?
        >
    with $Provider<BatchCurrencyConverter?> {
  /// Provider for batch currency converter
  ///
  /// **BUG FIX (2026-05-04)**: Handle null conversion service when unauthenticated
  /// Returns a no-op converter that doesn't crash the app
  const BatchCurrencyConverterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'batchCurrencyConverterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$batchCurrencyConverterHash();

  @$internal
  @override
  $ProviderElement<BatchCurrencyConverter?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BatchCurrencyConverter? create(Ref ref) {
    return batchCurrencyConverter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BatchCurrencyConverter? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BatchCurrencyConverter?>(value),
    );
  }
}

String _$batchCurrencyConverterHash() =>
    r'238b3f56fd6ec0ff133ad1d4627e5c267bb25bef';

/// Stats for one active investment, in the user's base currency.
///
/// Read from the same converted snapshot as the list cards, the sort and the
/// Overview ([convertedCashFlowsSnapshotProvider]), so the detail screen
/// always shows the same net and XIRR as the card.
///
/// **Parameters:**
/// - [investmentId]: Investment ID
///
/// **Returns:**
/// - InvestmentStats with amounts in user's base currency
/// - InvestmentStats.empty() when the investment has no active cash flows
///   and no dated valuation (an opening baseline needs no cash flows)

@ProviderFor(multiCurrencyInvestmentStats)
const multiCurrencyInvestmentStatsProvider =
    MultiCurrencyInvestmentStatsFamily._();

/// Stats for one active investment, in the user's base currency.
///
/// Read from the same converted snapshot as the list cards, the sort and the
/// Overview ([convertedCashFlowsSnapshotProvider]), so the detail screen
/// always shows the same net and XIRR as the card.
///
/// **Parameters:**
/// - [investmentId]: Investment ID
///
/// **Returns:**
/// - InvestmentStats with amounts in user's base currency
/// - InvestmentStats.empty() when the investment has no active cash flows
///   and no dated valuation (an opening baseline needs no cash flows)

final class MultiCurrencyInvestmentStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<InvestmentStats>,
          InvestmentStats,
          FutureOr<InvestmentStats>
        >
    with $FutureModifier<InvestmentStats>, $FutureProvider<InvestmentStats> {
  /// Stats for one active investment, in the user's base currency.
  ///
  /// Read from the same converted snapshot as the list cards, the sort and the
  /// Overview ([convertedCashFlowsSnapshotProvider]), so the detail screen
  /// always shows the same net and XIRR as the card.
  ///
  /// **Parameters:**
  /// - [investmentId]: Investment ID
  ///
  /// **Returns:**
  /// - InvestmentStats with amounts in user's base currency
  /// - InvestmentStats.empty() when the investment has no active cash flows
  ///   and no dated valuation (an opening baseline needs no cash flows)
  const MultiCurrencyInvestmentStatsProvider._({
    required MultiCurrencyInvestmentStatsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'multiCurrencyInvestmentStatsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$multiCurrencyInvestmentStatsHash();

  @override
  String toString() {
    return r'multiCurrencyInvestmentStatsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<InvestmentStats> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<InvestmentStats> create(Ref ref) {
    final argument = this.argument as String;
    return multiCurrencyInvestmentStats(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MultiCurrencyInvestmentStatsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$multiCurrencyInvestmentStatsHash() =>
    r'8ef746b0d5429de6ac4c5c5a6378e2f96218160a';

/// Stats for one active investment, in the user's base currency.
///
/// Read from the same converted snapshot as the list cards, the sort and the
/// Overview ([convertedCashFlowsSnapshotProvider]), so the detail screen
/// always shows the same net and XIRR as the card.
///
/// **Parameters:**
/// - [investmentId]: Investment ID
///
/// **Returns:**
/// - InvestmentStats with amounts in user's base currency
/// - InvestmentStats.empty() when the investment has no active cash flows
///   and no dated valuation (an opening baseline needs no cash flows)

final class MultiCurrencyInvestmentStatsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<InvestmentStats>, String> {
  const MultiCurrencyInvestmentStatsFamily._()
    : super(
        retry: null,
        name: r'multiCurrencyInvestmentStatsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Stats for one active investment, in the user's base currency.
  ///
  /// Read from the same converted snapshot as the list cards, the sort and the
  /// Overview ([convertedCashFlowsSnapshotProvider]), so the detail screen
  /// always shows the same net and XIRR as the card.
  ///
  /// **Parameters:**
  /// - [investmentId]: Investment ID
  ///
  /// **Returns:**
  /// - InvestmentStats with amounts in user's base currency
  /// - InvestmentStats.empty() when the investment has no active cash flows
  ///   and no dated valuation (an opening baseline needs no cash flows)

  MultiCurrencyInvestmentStatsProvider call(String investmentId) =>
      MultiCurrencyInvestmentStatsProvider._(
        argument: investmentId,
        from: this,
      );

  @override
  String toString() => r'multiCurrencyInvestmentStatsProvider';
}

/// Stats for one archived investment, in the user's base currency.
///
/// Archived investments are left out of totals, but their detail screen still
/// shows amounts under the base-currency symbol, so their cash flows must be
/// converted like those of active investments.

@ProviderFor(multiCurrencyArchivedInvestmentStats)
const multiCurrencyArchivedInvestmentStatsProvider =
    MultiCurrencyArchivedInvestmentStatsFamily._();

/// Stats for one archived investment, in the user's base currency.
///
/// Archived investments are left out of totals, but their detail screen still
/// shows amounts under the base-currency symbol, so their cash flows must be
/// converted like those of active investments.

final class MultiCurrencyArchivedInvestmentStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<InvestmentStats>,
          InvestmentStats,
          FutureOr<InvestmentStats>
        >
    with $FutureModifier<InvestmentStats>, $FutureProvider<InvestmentStats> {
  /// Stats for one archived investment, in the user's base currency.
  ///
  /// Archived investments are left out of totals, but their detail screen still
  /// shows amounts under the base-currency symbol, so their cash flows must be
  /// converted like those of active investments.
  const MultiCurrencyArchivedInvestmentStatsProvider._({
    required MultiCurrencyArchivedInvestmentStatsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'multiCurrencyArchivedInvestmentStatsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() =>
      _$multiCurrencyArchivedInvestmentStatsHash();

  @override
  String toString() {
    return r'multiCurrencyArchivedInvestmentStatsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<InvestmentStats> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<InvestmentStats> create(Ref ref) {
    final argument = this.argument as String;
    return multiCurrencyArchivedInvestmentStats(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MultiCurrencyArchivedInvestmentStatsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$multiCurrencyArchivedInvestmentStatsHash() =>
    r'016899a762c820d1fd3dd8963e1d7f84f443fbd3';

/// Stats for one archived investment, in the user's base currency.
///
/// Archived investments are left out of totals, but their detail screen still
/// shows amounts under the base-currency symbol, so their cash flows must be
/// converted like those of active investments.

final class MultiCurrencyArchivedInvestmentStatsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<InvestmentStats>, String> {
  const MultiCurrencyArchivedInvestmentStatsFamily._()
    : super(
        retry: null,
        name: r'multiCurrencyArchivedInvestmentStatsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Stats for one archived investment, in the user's base currency.
  ///
  /// Archived investments are left out of totals, but their detail screen still
  /// shows amounts under the base-currency symbol, so their cash flows must be
  /// converted like those of active investments.

  MultiCurrencyArchivedInvestmentStatsProvider call(String investmentId) =>
      MultiCurrencyArchivedInvestmentStatsProvider._(
        argument: investmentId,
        from: this,
      );

  @override
  String toString() => r'multiCurrencyArchivedInvestmentStatsProvider';
}

/// Provider for multi-currency global stats
///
/// Calculates global statistics across all investments with proper currency conversion.
/// All cash flows are converted to user's base currency before aggregation.
///
/// Uses optimized batch conversion with deduplication for performance.
///
/// **Returns:**
/// - InvestmentStats with amounts in user's base currency
/// - InvestmentStats.empty() if user is not authenticated (converter is null)

@ProviderFor(multiCurrencyGlobalStats)
const multiCurrencyGlobalStatsProvider = MultiCurrencyGlobalStatsProvider._();

/// Provider for multi-currency global stats
///
/// Calculates global statistics across all investments with proper currency conversion.
/// All cash flows are converted to user's base currency before aggregation.
///
/// Uses optimized batch conversion with deduplication for performance.
///
/// **Returns:**
/// - InvestmentStats with amounts in user's base currency
/// - InvestmentStats.empty() if user is not authenticated (converter is null)

final class MultiCurrencyGlobalStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<InvestmentStats>,
          InvestmentStats,
          FutureOr<InvestmentStats>
        >
    with $FutureModifier<InvestmentStats>, $FutureProvider<InvestmentStats> {
  /// Provider for multi-currency global stats
  ///
  /// Calculates global statistics across all investments with proper currency conversion.
  /// All cash flows are converted to user's base currency before aggregation.
  ///
  /// Uses optimized batch conversion with deduplication for performance.
  ///
  /// **Returns:**
  /// - InvestmentStats with amounts in user's base currency
  /// - InvestmentStats.empty() if user is not authenticated (converter is null)
  const MultiCurrencyGlobalStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'multiCurrencyGlobalStatsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$multiCurrencyGlobalStatsHash();

  @$internal
  @override
  $FutureProviderElement<InvestmentStats> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<InvestmentStats> create(Ref ref) {
    return multiCurrencyGlobalStats(ref);
  }
}

String _$multiCurrencyGlobalStatsHash() =>
    r'd83158387cb314810e51a0500bb3334586637d8f';

/// Provider for multi-currency open investments stats
///
/// Calculates statistics for open investments with proper currency conversion.
/// All cash flows are converted to user's base currency before aggregation.
///
/// **Returns:**
/// - InvestmentStats with amounts in user's base currency

@ProviderFor(multiCurrencyOpenStats)
const multiCurrencyOpenStatsProvider = MultiCurrencyOpenStatsProvider._();

/// Provider for multi-currency open investments stats
///
/// Calculates statistics for open investments with proper currency conversion.
/// All cash flows are converted to user's base currency before aggregation.
///
/// **Returns:**
/// - InvestmentStats with amounts in user's base currency

final class MultiCurrencyOpenStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<InvestmentStats>,
          InvestmentStats,
          FutureOr<InvestmentStats>
        >
    with $FutureModifier<InvestmentStats>, $FutureProvider<InvestmentStats> {
  /// Provider for multi-currency open investments stats
  ///
  /// Calculates statistics for open investments with proper currency conversion.
  /// All cash flows are converted to user's base currency before aggregation.
  ///
  /// **Returns:**
  /// - InvestmentStats with amounts in user's base currency
  const MultiCurrencyOpenStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'multiCurrencyOpenStatsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$multiCurrencyOpenStatsHash();

  @$internal
  @override
  $FutureProviderElement<InvestmentStats> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<InvestmentStats> create(Ref ref) {
    return multiCurrencyOpenStats(ref);
  }
}

String _$multiCurrencyOpenStatsHash() =>
    r'1134ec7bd704e381c9a040a149770f8f41d6e42b';

/// Provider for multi-currency closed investments stats
///
/// Calculates statistics for closed investments with proper currency conversion.
/// All cash flows are converted to user's base currency before aggregation.
///
/// **Returns:**
/// - InvestmentStats with amounts in user's base currency

@ProviderFor(multiCurrencyClosedStats)
const multiCurrencyClosedStatsProvider = MultiCurrencyClosedStatsProvider._();

/// Provider for multi-currency closed investments stats
///
/// Calculates statistics for closed investments with proper currency conversion.
/// All cash flows are converted to user's base currency before aggregation.
///
/// **Returns:**
/// - InvestmentStats with amounts in user's base currency

final class MultiCurrencyClosedStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<InvestmentStats>,
          InvestmentStats,
          FutureOr<InvestmentStats>
        >
    with $FutureModifier<InvestmentStats>, $FutureProvider<InvestmentStats> {
  /// Provider for multi-currency closed investments stats
  ///
  /// Calculates statistics for closed investments with proper currency conversion.
  /// All cash flows are converted to user's base currency before aggregation.
  ///
  /// **Returns:**
  /// - InvestmentStats with amounts in user's base currency
  const MultiCurrencyClosedStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'multiCurrencyClosedStatsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$multiCurrencyClosedStatsHash();

  @$internal
  @override
  $FutureProviderElement<InvestmentStats> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<InvestmentStats> create(Ref ref) {
    return multiCurrencyClosedStats(ref);
  }
}

String _$multiCurrencyClosedStatsHash() =>
    r'73d935acc4466dbb180201afbd8dd4b2795d911f';
