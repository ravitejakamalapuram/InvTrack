import 'package:flutter/widgets.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

/// Keys of the add investment form's fields and actions, the same on the form
/// behind the first investment flow and on today's form. Tests and the
/// integration robot find the form by these instead of by position or by text
/// that the new form repeats (the title and the submit button both read "Add
/// Investment").
abstract final class AddInvestmentKeys {
  /// The chip of one investment type.
  static Key typeChip(InvestmentType type) =>
      ValueKey('add-investment-type-${type.name}');

  static const name = ValueKey('add-investment-name');
  static const amount = ValueKey('add-investment-amount');
  static const notes = ValueKey('add-investment-notes');

  /// The "More details" tile of the first investment flow form.
  static const moreDetails = ValueKey('add-investment-more-details');

  static const submit = ValueKey('add-investment-submit');
}
