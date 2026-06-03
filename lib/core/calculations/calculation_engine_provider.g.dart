// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calculation_engine_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(calculationEngine)
final calculationEngineProvider = CalculationEngineProvider._();

typedef CalculationEngineRef = AutoDisposeProviderRef<CalculationEngine>;

final class CalculationEngineProvider
    extends $AutoDisposeProvider<CalculationEngine> {
  CalculationEngineProvider._()
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

String _$calculationEngineHash() => r'8c5e9f7a4b3d2c1e0f9a8b7c6d5e4f3a2b1c0d9e';
// ignore: unused_element
String $calculationEngineHash() => _$calculationEngineHash();
