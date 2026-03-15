// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'currency_switch_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for currency switch status

@ProviderFor(CurrencySwitch)
const currencySwitchProvider = CurrencySwitchProvider._();

/// Provider for currency switch status
final class CurrencySwitchProvider
    extends $NotifierProvider<CurrencySwitch, CurrencySwitchStatus> {
  /// Provider for currency switch status
  const CurrencySwitchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currencySwitchProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currencySwitchHash();

  @$internal
  @override
  CurrencySwitch create() => CurrencySwitch();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CurrencySwitchStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CurrencySwitchStatus>(value),
    );
  }
}

String _$currencySwitchHash() => r'5004282f3bbb48732274a3cf90ff20852b9fee24';

/// Provider for currency switch status

abstract class _$CurrencySwitch extends $Notifier<CurrencySwitchStatus> {
  CurrencySwitchStatus build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<CurrencySwitchStatus, CurrencySwitchStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CurrencySwitchStatus, CurrencySwitchStatus>,
              CurrencySwitchStatus,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
