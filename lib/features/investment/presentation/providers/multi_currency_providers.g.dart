// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'multi_currency_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for multi-currency invested amount calculation
///
/// Converts all outflow cash flows to user's base currency before summing
///
/// **Parameters:**
/// - [investmentId]: Investment ID
///
/// **Returns:**
/// - Total invested amount in user's base currency

@ProviderFor(multiCurrencyInvestedAmount)
const multiCurrencyInvestedAmountProvider =
    MultiCurrencyInvestedAmountFamily._();

/// Provider for multi-currency invested amount calculation
///
/// Converts all outflow cash flows to user's base currency before summing
///
/// **Parameters:**
/// - [investmentId]: Investment ID
///
/// **Returns:**
/// - Total invested amount in user's base currency

final class MultiCurrencyInvestedAmountProvider
    extends $FunctionalProvider<AsyncValue<double>, double, FutureOr<double>>
    with $FutureModifier<double>, $FutureProvider<double> {
  /// Provider for multi-currency invested amount calculation
  ///
  /// Converts all outflow cash flows to user's base currency before summing
  ///
  /// **Parameters:**
  /// - [investmentId]: Investment ID
  ///
  /// **Returns:**
  /// - Total invested amount in user's base currency
  const MultiCurrencyInvestedAmountProvider._({
    required MultiCurrencyInvestedAmountFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'multiCurrencyInvestedAmountProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$multiCurrencyInvestedAmountHash();

  @override
  String toString() {
    return r'multiCurrencyInvestedAmountProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<double> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<double> create(Ref ref) {
    final argument = this.argument as String;
    return multiCurrencyInvestedAmount(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MultiCurrencyInvestedAmountProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$multiCurrencyInvestedAmountHash() =>
    r'947920d051f9935e4b76a6b787ce9ea2b9a3de43';

/// Provider for multi-currency invested amount calculation
///
/// Converts all outflow cash flows to user's base currency before summing
///
/// **Parameters:**
/// - [investmentId]: Investment ID
///
/// **Returns:**
/// - Total invested amount in user's base currency

final class MultiCurrencyInvestedAmountFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<double>, String> {
  const MultiCurrencyInvestedAmountFamily._()
    : super(
        retry: null,
        name: r'multiCurrencyInvestedAmountProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for multi-currency invested amount calculation
  ///
  /// Converts all outflow cash flows to user's base currency before summing
  ///
  /// **Parameters:**
  /// - [investmentId]: Investment ID
  ///
  /// **Returns:**
  /// - Total invested amount in user's base currency

  MultiCurrencyInvestedAmountProvider call(String investmentId) =>
      MultiCurrencyInvestedAmountProvider._(argument: investmentId, from: this);

  @override
  String toString() => r'multiCurrencyInvestedAmountProvider';
}

/// Provider for multi-currency returned amount calculation
///
/// Converts all inflow cash flows to user's base currency before summing
///
/// **Parameters:**
/// - [investmentId]: Investment ID
///
/// **Returns:**
/// - Total returned amount in user's base currency

@ProviderFor(multiCurrencyReturnedAmount)
const multiCurrencyReturnedAmountProvider =
    MultiCurrencyReturnedAmountFamily._();

/// Provider for multi-currency returned amount calculation
///
/// Converts all inflow cash flows to user's base currency before summing
///
/// **Parameters:**
/// - [investmentId]: Investment ID
///
/// **Returns:**
/// - Total returned amount in user's base currency

final class MultiCurrencyReturnedAmountProvider
    extends $FunctionalProvider<AsyncValue<double>, double, FutureOr<double>>
    with $FutureModifier<double>, $FutureProvider<double> {
  /// Provider for multi-currency returned amount calculation
  ///
  /// Converts all inflow cash flows to user's base currency before summing
  ///
  /// **Parameters:**
  /// - [investmentId]: Investment ID
  ///
  /// **Returns:**
  /// - Total returned amount in user's base currency
  const MultiCurrencyReturnedAmountProvider._({
    required MultiCurrencyReturnedAmountFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'multiCurrencyReturnedAmountProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$multiCurrencyReturnedAmountHash();

  @override
  String toString() {
    return r'multiCurrencyReturnedAmountProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<double> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<double> create(Ref ref) {
    final argument = this.argument as String;
    return multiCurrencyReturnedAmount(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MultiCurrencyReturnedAmountProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$multiCurrencyReturnedAmountHash() =>
    r'953b19d1a774de65d09d892ac1f41e1d2daa9095';

/// Provider for multi-currency returned amount calculation
///
/// Converts all inflow cash flows to user's base currency before summing
///
/// **Parameters:**
/// - [investmentId]: Investment ID
///
/// **Returns:**
/// - Total returned amount in user's base currency

final class MultiCurrencyReturnedAmountFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<double>, String> {
  const MultiCurrencyReturnedAmountFamily._()
    : super(
        retry: null,
        name: r'multiCurrencyReturnedAmountProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for multi-currency returned amount calculation
  ///
  /// Converts all inflow cash flows to user's base currency before summing
  ///
  /// **Parameters:**
  /// - [investmentId]: Investment ID
  ///
  /// **Returns:**
  /// - Total returned amount in user's base currency

  MultiCurrencyReturnedAmountProvider call(String investmentId) =>
      MultiCurrencyReturnedAmountProvider._(argument: investmentId, from: this);

  @override
  String toString() => r'multiCurrencyReturnedAmountProvider';
}

/// Provider for multi-currency XIRR calculation
///
/// Converts all cash flows to user's base currency using historical rates
/// before calculating XIRR
///
/// **Parameters:**
/// - [investmentId]: Investment ID
///
/// **Returns:**
/// - XIRR as decimal (e.g., 0.15 = 15% annual return)

@ProviderFor(multiCurrencyXirr)
const multiCurrencyXirrProvider = MultiCurrencyXirrFamily._();

/// Provider for multi-currency XIRR calculation
///
/// Converts all cash flows to user's base currency using historical rates
/// before calculating XIRR
///
/// **Parameters:**
/// - [investmentId]: Investment ID
///
/// **Returns:**
/// - XIRR as decimal (e.g., 0.15 = 15% annual return)

final class MultiCurrencyXirrProvider
    extends $FunctionalProvider<AsyncValue<double>, double, FutureOr<double>>
    with $FutureModifier<double>, $FutureProvider<double> {
  /// Provider for multi-currency XIRR calculation
  ///
  /// Converts all cash flows to user's base currency using historical rates
  /// before calculating XIRR
  ///
  /// **Parameters:**
  /// - [investmentId]: Investment ID
  ///
  /// **Returns:**
  /// - XIRR as decimal (e.g., 0.15 = 15% annual return)
  const MultiCurrencyXirrProvider._({
    required MultiCurrencyXirrFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'multiCurrencyXirrProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$multiCurrencyXirrHash();

  @override
  String toString() {
    return r'multiCurrencyXirrProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<double> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<double> create(Ref ref) {
    final argument = this.argument as String;
    return multiCurrencyXirr(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MultiCurrencyXirrProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$multiCurrencyXirrHash() => r'16e9af6e184f0c17096152dff42030bd3a1dc14a';

/// Provider for multi-currency XIRR calculation
///
/// Converts all cash flows to user's base currency using historical rates
/// before calculating XIRR
///
/// **Parameters:**
/// - [investmentId]: Investment ID
///
/// **Returns:**
/// - XIRR as decimal (e.g., 0.15 = 15% annual return)

final class MultiCurrencyXirrFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<double>, String> {
  const MultiCurrencyXirrFamily._()
    : super(
        retry: null,
        name: r'multiCurrencyXirrProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for multi-currency XIRR calculation
  ///
  /// Converts all cash flows to user's base currency using historical rates
  /// before calculating XIRR
  ///
  /// **Parameters:**
  /// - [investmentId]: Investment ID
  ///
  /// **Returns:**
  /// - XIRR as decimal (e.g., 0.15 = 15% annual return)

  MultiCurrencyXirrProvider call(String investmentId) =>
      MultiCurrencyXirrProvider._(argument: investmentId, from: this);

  @override
  String toString() => r'multiCurrencyXirrProvider';
}

/// Provider for multi-currency portfolio value
///
/// Calculates total portfolio value by summing net cash flow
/// (total returned - total invested) for all investments,
/// converted to user's base currency
///
/// **Returns:**
/// - Total portfolio value in user's base currency

@ProviderFor(multiCurrencyPortfolioValue)
const multiCurrencyPortfolioValueProvider =
    MultiCurrencyPortfolioValueProvider._();

/// Provider for multi-currency portfolio value
///
/// Calculates total portfolio value by summing net cash flow
/// (total returned - total invested) for all investments,
/// converted to user's base currency
///
/// **Returns:**
/// - Total portfolio value in user's base currency

final class MultiCurrencyPortfolioValueProvider
    extends $FunctionalProvider<AsyncValue<double>, double, FutureOr<double>>
    with $FutureModifier<double>, $FutureProvider<double> {
  /// Provider for multi-currency portfolio value
  ///
  /// Calculates total portfolio value by summing net cash flow
  /// (total returned - total invested) for all investments,
  /// converted to user's base currency
  ///
  /// **Returns:**
  /// - Total portfolio value in user's base currency
  const MultiCurrencyPortfolioValueProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'multiCurrencyPortfolioValueProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$multiCurrencyPortfolioValueHash();

  @$internal
  @override
  $FutureProviderElement<double> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<double> create(Ref ref) {
    return multiCurrencyPortfolioValue(ref);
  }
}

String _$multiCurrencyPortfolioValueHash() =>
    r'cf9d646e1f128e5bf4de843df02301b4176e4dc7';

/// Provider for multi-currency investment stats
///
/// Calculates investment statistics with proper currency conversion.
/// All cash flows are converted to user's base currency before aggregation.
///
/// **Parameters:**
/// - [investmentId]: Investment ID
///
/// **Returns:**
/// - InvestmentStats with amounts in user's base currency

@ProviderFor(multiCurrencyInvestmentStats)
const multiCurrencyInvestmentStatsProvider =
    MultiCurrencyInvestmentStatsFamily._();

/// Provider for multi-currency investment stats
///
/// Calculates investment statistics with proper currency conversion.
/// All cash flows are converted to user's base currency before aggregation.
///
/// **Parameters:**
/// - [investmentId]: Investment ID
///
/// **Returns:**
/// - InvestmentStats with amounts in user's base currency

final class MultiCurrencyInvestmentStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<InvestmentStats>,
          InvestmentStats,
          FutureOr<InvestmentStats>
        >
    with $FutureModifier<InvestmentStats>, $FutureProvider<InvestmentStats> {
  /// Provider for multi-currency investment stats
  ///
  /// Calculates investment statistics with proper currency conversion.
  /// All cash flows are converted to user's base currency before aggregation.
  ///
  /// **Parameters:**
  /// - [investmentId]: Investment ID
  ///
  /// **Returns:**
  /// - InvestmentStats with amounts in user's base currency
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
    r'f72a10b1e6d1448d4cc0ca6cd03132615b3e233a';

/// Provider for multi-currency investment stats
///
/// Calculates investment statistics with proper currency conversion.
/// All cash flows are converted to user's base currency before aggregation.
///
/// **Parameters:**
/// - [investmentId]: Investment ID
///
/// **Returns:**
/// - InvestmentStats with amounts in user's base currency

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

  /// Provider for multi-currency investment stats
  ///
  /// Calculates investment statistics with proper currency conversion.
  /// All cash flows are converted to user's base currency before aggregation.
  ///
  /// **Parameters:**
  /// - [investmentId]: Investment ID
  ///
  /// **Returns:**
  /// - InvestmentStats with amounts in user's base currency

  MultiCurrencyInvestmentStatsProvider call(String investmentId) =>
      MultiCurrencyInvestmentStatsProvider._(
        argument: investmentId,
        from: this,
      );

  @override
  String toString() => r'multiCurrencyInvestmentStatsProvider';
}

/// Provider for multi-currency global stats
///
/// Calculates global statistics across all investments with proper currency conversion.
/// All cash flows are converted to user's base currency before aggregation.
///
/// **Returns:**
/// - InvestmentStats with amounts in user's base currency

@ProviderFor(multiCurrencyGlobalStats)
const multiCurrencyGlobalStatsProvider = MultiCurrencyGlobalStatsProvider._();

/// Provider for multi-currency global stats
///
/// Calculates global statistics across all investments with proper currency conversion.
/// All cash flows are converted to user's base currency before aggregation.
///
/// **Returns:**
/// - InvestmentStats with amounts in user's base currency

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
  /// **Returns:**
  /// - InvestmentStats with amounts in user's base currency
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
    r'8e552a60df6423a5a6dbb64240a016cee992df26';

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
    r'9686712f61821cafa39586e47d769e50ce1b1ac3';

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
    r'6025c6cc91d5f0954933446161d032cf0164a8cc';
