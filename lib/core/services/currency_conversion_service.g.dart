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

@ProviderFor(currencyConversionService)
const currencyConversionServiceProvider = CurrencyConversionServiceProvider._();

/// Provider for CurrencyConversionService
///
/// Provides access to currency conversion with three-tier caching

final class CurrencyConversionServiceProvider
    extends
        $FunctionalProvider<
          CurrencyConversionService,
          CurrencyConversionService,
          CurrencyConversionService
        >
    with $Provider<CurrencyConversionService> {
  /// Provider for CurrencyConversionService
  ///
  /// Provides access to currency conversion with three-tier caching
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
  $ProviderElement<CurrencyConversionService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CurrencyConversionService create(Ref ref) {
    return currencyConversionService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CurrencyConversionService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CurrencyConversionService>(value),
    );
  }
}

String _$currencyConversionServiceHash() =>
    r'87764de20d006b3e8346ecd5223f5e9592c4fd15';
