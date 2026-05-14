// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'smart_insights_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Service provider for smart insights generation

@ProviderFor(smartInsightsService)
const smartInsightsServiceProvider = SmartInsightsServiceProvider._();

/// Service provider for smart insights generation

final class SmartInsightsServiceProvider
    extends
        $FunctionalProvider<
          SmartInsightsService,
          SmartInsightsService,
          SmartInsightsService
        >
    with $Provider<SmartInsightsService> {
  /// Service provider for smart insights generation
  const SmartInsightsServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'smartInsightsServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$smartInsightsServiceHash();

  @$internal
  @override
  $ProviderElement<SmartInsightsService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SmartInsightsService create(Ref ref) {
    return smartInsightsService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SmartInsightsService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SmartInsightsService>(value),
    );
  }
}

String _$smartInsightsServiceHash() =>
    r'e90bbc3de9c61f875447384ca897bb7af8e0d89a';

/// Provider for smart insights (auto-generated from user data)

@ProviderFor(smartInsights)
const smartInsightsProvider = SmartInsightsProvider._();

/// Provider for smart insights (auto-generated from user data)

final class SmartInsightsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SmartInsight>>,
          List<SmartInsight>,
          FutureOr<List<SmartInsight>>
        >
    with
        $FutureModifier<List<SmartInsight>>,
        $FutureProvider<List<SmartInsight>> {
  /// Provider for smart insights (auto-generated from user data)
  const SmartInsightsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'smartInsightsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$smartInsightsHash();

  @$internal
  @override
  $FutureProviderElement<List<SmartInsight>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<SmartInsight>> create(Ref ref) {
    return smartInsights(ref);
  }
}

String _$smartInsightsHash() => r'8caec92fff6b5cf86a4b92e2f8edee918b30d91b';

/// Provider for high-priority insights (urgent/warning only)

@ProviderFor(priorityInsights)
const priorityInsightsProvider = PriorityInsightsProvider._();

/// Provider for high-priority insights (urgent/warning only)

final class PriorityInsightsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SmartInsight>>,
          List<SmartInsight>,
          FutureOr<List<SmartInsight>>
        >
    with
        $FutureModifier<List<SmartInsight>>,
        $FutureProvider<List<SmartInsight>> {
  /// Provider for high-priority insights (urgent/warning only)
  const PriorityInsightsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'priorityInsightsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$priorityInsightsHash();

  @$internal
  @override
  $FutureProviderElement<List<SmartInsight>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<SmartInsight>> create(Ref ref) {
    return priorityInsights(ref);
  }
}

String _$priorityInsightsHash() => r'8a20f4bfb63b56c7f7072153cb9b6e5a38c839cf';
