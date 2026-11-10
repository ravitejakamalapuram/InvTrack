import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/unit_holding.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// The name of [unit] in the user's language.
String quantityUnitName(AppLocalizations l10n, QuantityUnit unit) =>
    switch (unit) {
      QuantityUnit.gram => l10n.quantityUnitGram,
      QuantityUnit.kilogram => l10n.quantityUnitKilogram,
      QuantityUnit.troyOunce => l10n.quantityUnitTroyOunce,
      QuantityUnit.tola => l10n.quantityUnitTola,
      QuantityUnit.sovereign => l10n.quantityUnitSovereign,
    };

/// "10 gram × ₹6,450": the weight times the price per unit, the price in
/// [currency] (never the base currency).
String holdingText(
  AppLocalizations l10n,
  UnitHolding holding,
  String currency,
) {
  final quantity = holding.quantity.toString().replaceFirst(
    RegExp(r'\.0$'),
    '',
  );
  return l10n.holdingSummary(
    quantity,
    quantityUnitName(l10n, holding.unit),
    formatCurrencyForCode(holding.unitPrice, currency),
  );
}
