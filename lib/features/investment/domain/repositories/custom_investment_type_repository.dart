import 'package:inv_tracker/features/investment/domain/entities/custom_investment_type_entity.dart';

/// Storage of the account's reusable custom investment types (#936).
///
/// It only stores definitions. The rules for saving, renaming and removing
/// them live in `CustomTypeCatalog`, and nothing here reads or writes an
/// investment or a cash flow.
abstract class CustomInvestmentTypeRepository {
  /// Every definition, removed ones included, as they change.
  Stream<List<CustomInvestmentType>> watchAll();

  /// Every definition, removed ones included, from the local cache when
  /// offline.
  Future<List<CustomInvestmentType>> getAll();

  /// Creates or replaces the definition with [type]'s id.
  Future<void> put(CustomInvestmentType type);
}
