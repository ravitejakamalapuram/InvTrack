// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'currency_conversion_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for CurrencyConversionService
///
/// Provides access to currency conversion with three-tier caching
///
/// **CRITICAL FIX (2026-05-04)**: Never throw in provider - throws AuthException instead
/// Provider exceptions cause ProviderException which crashes the app.
/// Instead, return null when user is not authenticated - call sites should check.
///
/// Fixes Crashlytics issues:
/// - #50a389e45315ab4cb1393f56b731f6ff (ProviderException crashes)
/// - #fa5a52c906efdb348d26233a9c94744a (currency service auth errors)

@ProviderFor(currencyConversionService)
const currencyConversionServiceProvider = CurrencyConversionServiceProvider._();

/// Provider for CurrencyConversionService
///
/// Provides access to currency conversion with three-tier caching
///
/// **CRITICAL FIX (2026-05-04)**: Never throw in provider - throws AuthException instead
/// Provider exceptions cause ProviderException which crashes the app.
/// Instead, return null when user is not authenticated - call sites should check.
///
/// Fixes Crashlytics issues:
/// - #50a389e45315ab4cb1393f56b731f6ff (ProviderException crashes)
/// - #fa5a52c906efdb348d26233a9c94744a (currency service auth errors)

final class CurrencyConversionServiceProvider
    extends
        $FunctionalProvider<
          CurrencyConversionService?,
          CurrencyConversionService?,
          CurrencyConversionService?
        >
    with $Provider<CurrencyConversionService?> {
  /// Provider for CurrencyConversionService
  ///
  /// Provides access to currency conversion with three-tier caching
  ///
  /// **CRITICAL FIX (2026-05-04)**: Never throw in provider - throws AuthException instead
  /// Provider exceptions cause ProviderException which crashes the app.
  /// Instead, return null when user is not authenticated - call sites should check.
  ///
  /// Fixes Crashlytics issues:
  /// - #50a389e45315ab4cb1393f56b731f6ff (ProviderException crashes)
  /// - #fa5a52c906efdb348d26233a9c94744a (currency service auth errors)
  const CurrencyConversionServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currencyConversionServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currencyConversionServiceHash();

  @$internal
  @override
  $ProviderElement<CurrencyConversionService?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CurrencyConversionService? create(Ref ref) {
    return currencyConversionService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CurrencyConversionService? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CurrencyConversionService?>(value),
    );
  }
}

String _$currencyConversionServiceHash() =>
    r'4ff3db1191bf4155c346bc382061fd2b9e472f84';
