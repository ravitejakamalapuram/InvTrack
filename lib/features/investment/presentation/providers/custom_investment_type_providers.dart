/// Providers and actions for the account's reusable custom investment types
/// (#936). The rules live in `CustomTypeCatalog`; this layer reads the stored
/// definitions, applies a rule and writes the one definition it changed.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/investment/domain/entities/custom_investment_type_entity.dart';
import 'package:inv_tracker/features/investment/domain/models/custom_type_catalog.dart';
import 'package:uuid/uuid.dart';

/// Every stored definition, removed ones included. Empty while signed out.
final customInvestmentTypesProvider =
    StreamProvider<List<CustomInvestmentType>>((ref) {
      if (!ref.watch(isAuthenticatedProvider)) return Stream.value(const []);
      return ref.watch(customInvestmentTypeRepositoryProvider).watchAll();
    });

/// The active types to suggest when Other is selected: one per label,
/// whatever its case or spacing, ordered by label.
///
/// Nothing is suggested while the types are loading, and that includes a
/// reload because the signed-in user changed: the previous account's types
/// must not show to the next one.
final customTypeSuggestionsProvider = Provider<List<CustomInvestmentType>>((
  ref,
) {
  final all = ref
      .watch(customInvestmentTypesProvider)
      .when(
        data: (all) => all,
        loading: () => const <CustomInvestmentType>[],
        error: (_, _) => const <CustomInvestmentType>[],
      );
  return CustomTypeCatalog.suggestions(all);
});

final customInvestmentTypeNotifierProvider =
    NotifierProvider<CustomInvestmentTypeNotifier, AsyncValue<void>>(
      CustomInvestmentTypeNotifier.new,
    );

/// Saves, renames and removes reusable custom types. Each action writes at
/// most one definition. It never reads or writes an investment or a cash
/// flow, so it cannot reclassify or delete one. A refused change is returned
/// with its [CustomTypeChange.issue] and nothing is written.
class CustomInvestmentTypeNotifier extends Notifier<AsyncValue<void>> {
  static const _uuid = Uuid();

  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  /// Saves [label] as a reusable type. Only ever called by an explicit user
  /// action, never while typing.
  Future<CustomTypeChange> save(String? label) => _apply(
    (all) => CustomTypeCatalog.save(
      all,
      label,
      newId: _uuid.v4(),
      now: DateTime.now(),
    ),
  );

  /// Renames the type [id]. Investments keep their own copy of the old label.
  Future<CustomTypeChange> rename(String id, String? label) => _apply(
    (all) => CustomTypeCatalog.rename(all, id, label, now: DateTime.now()),
  );

  /// Removes the type [id] from the suggestions. Investments that use it keep
  /// their label.
  Future<CustomTypeChange> remove(String id) =>
      _apply((all) => CustomTypeCatalog.remove(all, id, now: DateTime.now()));

  Future<CustomTypeChange> _apply(
    CustomTypeChange Function(List<CustomInvestmentType> all) decide,
  ) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(customInvestmentTypeRepositoryProvider);
      final change = decide(await repository.getAll());
      final write = change.write;
      if (write != null) await repository.put(write);
      state = const AsyncValue.data(null);
      return change;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}
