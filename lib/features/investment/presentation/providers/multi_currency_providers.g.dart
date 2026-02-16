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
    r'60cb022520bf5bffff62b7052d822435fe4a4c06';

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
    r'4e4d98a0fb24cf664f38bb0efdc534d2f2fea9cb';

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

String _$multiCurrencyXirrHash() => r'254c8b68b8d7ddeaf3c20627a0267e3716bab00b';

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
    r'771912654ac10432a6399b8d1a246ce56122948b';
