// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calculation_engine_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for the unified [CalculationEngine].
///
/// Automatically registers calculation modules and resolves active services.

@ProviderFor(calculationEngine)
const calculationEngineProvider = CalculationEngineProvider._();

/// Provider for the unified [CalculationEngine].
///
/// Automatically registers calculation modules and resolves active services.

final class CalculationEngineProvider
    extends
        $FunctionalProvider<
          CalculationEngine,
          CalculationEngine,
          CalculationEngine
        >
    with $Provider<CalculationEngine> {
  /// Provider for the unified [CalculationEngine].
  ///
  /// Automatically registers calculation modules and resolves active services.
  const CalculationEngineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'calculationEngineProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$calculationEngineHash();

  @$internal
  @override
  $ProviderElement<CalculationEngine> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CalculationEngine create(Ref ref) {
    return calculationEngine(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CalculationEngine value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CalculationEngine>(value),
    );
  }
}

String _$calculationEngineHash() => r'f07d7076fb36859857fcf3293c523e88d597dabb';
