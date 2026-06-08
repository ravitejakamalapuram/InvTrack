/// Decoupled enum representing the type of cash flow for calculations.
enum CalculationCashFlowType {
  /// Money invested (outflow).
  invest,

  /// Money returned from exit/sale (inflow).
  returnFlow,

  /// Income received such as dividends, interest, rent (inflow).
  income,

  /// Fees or expenses paid (outflow).
  fee,
}

/// A generic interface representing a cash flow transaction for financial calculations.
///
/// This decouples calculation engines and utilities from database-bound
/// feature entities like [CashFlowEntity].
abstract class ICashFlow {
  /// The unique identifier of the investment this cash flow belongs to.
  String get investmentId;

  /// The date of the cash flow transaction.
  DateTime get date;

  /// The absolute amount of the cash flow transaction.
  double get amount;

  /// The signed amount of the cash flow transaction.
  /// Outflows (investments, fees) are negative.
  /// Inflows (returns, income) are positive.
  double get signedAmount;

  /// The currency code of the transaction (e.g., 'USD', 'INR').
  String get currency;

  /// The type of cash flow (invest, returnFlow, income, fee).
  CalculationCashFlowType get calculationType;
}
