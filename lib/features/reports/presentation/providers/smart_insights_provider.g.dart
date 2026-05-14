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
/// Requires AppLocalizations for localized strings

@ProviderFor(smartInsights)
const smartInsightsProvider = SmartInsightsFamily._();

/// Provider for smart insights (auto-generated from user data)
/// Requires AppLocalizations for localized strings

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
  /// Requires AppLocalizations for localized strings
  const SmartInsightsProvider._({
    required SmartInsightsFamily super.from,
    required AppLocalizations super.argument,
  }) : super(
         retry: null,
         name: r'smartInsightsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$smartInsightsHash();

  @override
  String toString() {
    return r'smartInsightsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<SmartInsight>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<SmartInsight>> create(Ref ref) {
    final argument = this.argument as AppLocalizations;
    return smartInsights(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SmartInsightsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$smartInsightsHash() => r'93305b894480c53d19a8393e58b62220a5d23337';

/// Provider for smart insights (auto-generated from user data)
/// Requires AppLocalizations for localized strings

final class SmartInsightsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<SmartInsight>>,
          AppLocalizations
        > {
  const SmartInsightsFamily._()
    : super(
        retry: null,
        name: r'smartInsightsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for smart insights (auto-generated from user data)
  /// Requires AppLocalizations for localized strings

  SmartInsightsProvider call(AppLocalizations l10n) =>
      SmartInsightsProvider._(argument: l10n, from: this);

  @override
  String toString() => r'smartInsightsProvider';
}

/// Provider for high-priority insights (urgent/warning only)
/// Requires AppLocalizations for localized strings

@ProviderFor(priorityInsights)
const priorityInsightsProvider = PriorityInsightsFamily._();

/// Provider for high-priority insights (urgent/warning only)
/// Requires AppLocalizations for localized strings

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
  /// Requires AppLocalizations for localized strings
  const PriorityInsightsProvider._({
    required PriorityInsightsFamily super.from,
    required AppLocalizations super.argument,
  }) : super(
         retry: null,
         name: r'priorityInsightsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$priorityInsightsHash();

  @override
  String toString() {
    return r'priorityInsightsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<SmartInsight>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<SmartInsight>> create(Ref ref) {
    final argument = this.argument as AppLocalizations;
    return priorityInsights(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PriorityInsightsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$priorityInsightsHash() => r'c05a6ca19279f09d17d27092ee30fbdf11568fc6';

/// Provider for high-priority insights (urgent/warning only)
/// Requires AppLocalizations for localized strings

final class PriorityInsightsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<SmartInsight>>,
          AppLocalizations
        > {
  const PriorityInsightsFamily._()
    : super(
        retry: null,
        name: r'priorityInsightsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for high-priority insights (urgent/warning only)
  /// Requires AppLocalizations for localized strings

  PriorityInsightsProvider call(AppLocalizations l10n) =>
      PriorityInsightsProvider._(argument: l10n, from: this);

  @override
  String toString() => r'priorityInsightsProvider';
}
