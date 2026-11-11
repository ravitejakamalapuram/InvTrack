import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

/// The grams of metal still held: weight bought (INVEST) minus weight sold
/// (RETURN), over the cash flows that carry a weight. Null when none does, so
/// a screen shows nothing rather than "0 g" for an investment tracked by money
/// only. Never below zero.
double? heldGrams(Iterable<CashFlowEntity> cashFlows) {
  double? held;
  for (final flow in cashFlows) {
    final grams = flow.grams;
    if (grams == null) continue;
    switch (flow.type) {
      case CashFlowType.invest:
        held = (held ?? 0) + grams;
      case CashFlowType.returnFlow:
        held = (held ?? 0) - grams;
      case CashFlowType.income:
      case CashFlowType.fee:
        break;
    }
  }
  if (held == null) return null;
  return held < 0 ? 0 : held;
}
