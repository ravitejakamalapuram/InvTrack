/// Financial calculations for investment analysis.
///
/// This utility class provides common financial metrics used in investment tracking:
/// - **XIRR**: Extended Internal Rate of Return (annualized return for irregular cash flows)
/// - **MOIC**: Multiple on Invested Capital (total return multiple)
/// - **Absolute Return**: Simple percentage return
/// - **Net Cash Flow**: Total profit/loss
///
/// All methods are static and stateless for easy testing and reuse.
///
/// ## Usage Example
///
/// ```dart
/// // Calculate XIRR for an investment with multiple transactions
/// final cashFlows = [
///   CashFlowEntity(date: DateTime(2023, 1, 1), amount: 10000, type: CashFlowType.buy),
///   CashFlowEntity(date: DateTime(2023, 6, 1), amount: 500, type: CashFlowType.dividend),
///   CashFlowEntity(date: DateTime(2024, 1, 1), amount: 11000, type: CashFlowType.currentValue),
/// ];
/// final xirr = FinancialCalculator.calculateXirrFromCashFlows(cashFlows);
/// print(xirr == null ? '—' : 'XIRR: ${(xirr * 100).toStringAsFixed(2)}%');
///
/// // Calculate MOIC
/// final moic = FinancialCalculator.calculateMOIC(10000, 12000);
/// print('MOIC: ${moic.toStringAsFixed(2)}x'); // 1.20x
/// ```
library;

import 'package:inv_tracker/core/calculations/models/cash_flow_interface.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';

/// Utility class for financial calculations used in investment analysis.
///
/// See library documentation above for usage examples.
class FinancialCalculator {
  /// Calculates XIRR (Extended Internal Rate of Return) from a list of cash flows.
  ///
  /// XIRR is the annualized rate of return for investments with irregular cash flows.
  /// It handles real-world scenarios with multiple transactions.
  ///
  /// ## Parameters
  ///
  /// - [cashFlows]: List of cash flow entities with dates and amounts
  ///   - Uses `signedAmount` property (negative for outflows, positive for inflows)
  ///   - Must include at least one outflow and one inflow
  ///
  /// ## Returns
  ///
  /// - **double**: XIRR as decimal (e.g., 0.15 = 15% annual return)
  /// - **null**: When no XIRR exists (no flows, only inflows or only outflows,
  ///   or no solution). Show "—" and leave it out of rankings and averages;
  ///   never treat it as 0%.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final cashFlows = [
  ///   CashFlowEntity(
  ///     date: DateTime(2023, 1, 1),
  ///     amount: 10000,
  ///     type: CashFlowType.buy, // Outflow: signedAmount = -10000
  ///   ),
  ///   CashFlowEntity(
  ///     date: DateTime(2023, 6, 1),
  ///     amount: 500,
  ///     type: CashFlowType.dividend, // Inflow: signedAmount = +500
  ///   ),
  ///   CashFlowEntity(
  ///     date: DateTime(2024, 1, 1),
  ///     amount: 11000,
  ///     type: CashFlowType.currentValue, // Inflow: signedAmount = +11000
  ///   ),
  /// ];
  ///
  /// final xirr = FinancialCalculator.calculateXirrFromCashFlows(cashFlows);
  /// print('XIRR: ${(xirr! * 100).toStringAsFixed(2)}%'); // ~15%
  /// ```
  ///
  /// ## See Also
  ///
  /// - [XirrSolver.calculateXirr] for the underlying algorithm
  static double? calculateXirrFromCashFlows(List<ICashFlow> cashFlows) {
    if (cashFlows.isEmpty) return null;

    final dates = <DateTime>[];
    final amounts = <double>[];

    for (final cf in cashFlows) {
      dates.add(cf.date);
      amounts.add(cf.signedAmount);
    }

    return XirrSolver.calculateXirr(dates, amounts);
  }

  /// Like [calculateXirrFromCashFlows], but says whether the rate is exact,
  /// approximate or undefined, so the UI can label it. Its value is the
  /// number [calculateXirrFromCashFlows] returns.
  static XirrResult solveXirrFromCashFlows(List<ICashFlow> cashFlows) {
    return XirrSolver.solve(
      [for (final cf in cashFlows) cf.date],
      [for (final cf in cashFlows) cf.signedAmount],
    );
  }

  /// Calculates MOIC (Multiple on Invested Capital).
  ///
  /// MOIC shows how many times your investment has grown. It's a simple ratio
  /// that doesn't account for time, making it useful for quick comparisons.
  ///
  /// ## Formula
  ///
  /// ```
  /// MOIC = Total Value / Total Invested
  /// ```
  ///
  /// ## Parameters
  ///
  /// - [invested]: Total amount invested (must be > 0 for meaningful result)
  /// - [returned]: Total value returned (current value + dividends + withdrawals)
  ///
  /// ## Returns
  ///
  /// - **double**: MOIC as multiple (e.g., 1.5 = 1.5x return)
  /// - **0.0**: If invested = 0 (division by zero protection)
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Invested ₹10,000, current value ₹15,000
  /// final moic = FinancialCalculator.calculateMOIC(10000, 15000);
  /// print('MOIC: ${moic.toStringAsFixed(2)}x'); // 1.50x
  ///
  /// // Total loss scenario
  /// final loss = FinancialCalculator.calculateMOIC(10000, 0);
  /// print('MOIC: ${loss.toStringAsFixed(2)}x'); // 0.00x
  ///
  /// // Doubled investment
  /// final doubled = FinancialCalculator.calculateMOIC(10000, 20000);
  /// print('MOIC: ${doubled.toStringAsFixed(2)}x'); // 2.00x
  /// ```
  ///
  /// ## Interpretation
  ///
  /// - **MOIC > 1.0**: Profit (e.g., 1.5x = 50% gain)
  /// - **MOIC = 1.0**: Break-even (no gain or loss)
  /// - **MOIC < 1.0**: Loss (e.g., 0.8x = 20% loss)
  ///
  /// ## See Also
  ///
  /// - [calculateAbsoluteReturn] for percentage-based return
  static double calculateMOIC(double invested, double returned) {
    if (invested == 0) return 0.0;
    return returned / invested;
  }

  /// Calculates Net Cash Flow (Total Returned - Total Invested).
  ///
  /// Net cash flow is the absolute profit or loss from an investment,
  /// without considering time or percentages.
  ///
  /// ## Formula
  ///
  /// ```
  /// Net Cash Flow = Total Returned - Total Invested
  /// ```
  ///
  /// ## Parameters
  ///
  /// - [invested]: Total amount invested
  /// - [returned]: Total value returned (current value + dividends + withdrawals)
  ///
  /// ## Returns
  ///
  /// - **double**: Net cash flow (positive = profit, negative = loss)
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Invested ₹10,000, current value ₹12,000
  /// final netCashFlow = FinancialCalculator.calculateNetCashFlow(10000, 12000);
  /// print('Profit: ₹${netCashFlow.toStringAsFixed(2)}'); // ₹2,000.00
  ///
  /// // Loss scenario
  /// final loss = FinancialCalculator.calculateNetCashFlow(10000, 8000);
  /// print('Loss: ₹${loss.toStringAsFixed(2)}'); // -₹2,000.00
  /// ```
  ///
  /// ## See Also
  ///
  /// - [calculateAbsoluteReturn] for percentage-based return
  /// - [calculateMOIC] for multiple-based return
  static double calculateNetCashFlow(double invested, double returned) {
    return returned - invested;
  }

  /// Calculates Total Invested (outflows) from cash flows.
  ///
  /// Sums all outflow transactions (purchases, investments) from a list of cash flows.
  ///
  /// ## Parameters
  ///
  /// - [cashFlows]: List of cash flow entities
  ///
  /// ## Returns
  ///
  /// - **double**: Total amount invested (always positive)
  ///
  /// ## Example
  ///
  /// ```dart
  /// final cashFlows = [
  ///   CashFlowEntity(amount: 10000, type: CashFlowType.buy),      // Outflow
  ///   CashFlowEntity(amount: 5000, type: CashFlowType.buy),       // Outflow
  ///   CashFlowEntity(amount: 500, type: CashFlowType.dividend),   // Inflow (ignored)
  /// ];
  ///
  /// final totalInvested = FinancialCalculator.calculateTotalInvested(cashFlows);
  /// print('Total Invested: ₹${totalInvested}'); // ₹15,000
  /// ```
  ///
  /// ## See Also
  ///
  /// - [calculateTotalReturned] for total inflows
  /// - [calculateNetCashFlow] for net profit/loss
  static double calculateTotalInvested(List<ICashFlow> cashFlows) {
    double total = 0.0;
    for (final cf in cashFlows) {
      if (cf.signedAmount < 0) {
        total += cf.amount;
      }
    }
    return total;
  }

  /// Calculates Total Returned (inflows) from cash flows.
  ///
  /// Sums all inflow transactions (dividends, interest, current value) from a list of cash flows.
  ///
  /// ## Parameters
  ///
  /// - [cashFlows]: List of cash flow entities
  ///
  /// ## Returns
  ///
  /// - **double**: Total amount returned (always positive)
  ///
  /// ## Example
  ///
  /// ```dart
  /// final cashFlows = [
  ///   CashFlowEntity(amount: 10000, type: CashFlowType.buy),        // Outflow (ignored)
  ///   CashFlowEntity(amount: 500, type: CashFlowType.dividend),     // Inflow
  ///   CashFlowEntity(amount: 11000, type: CashFlowType.currentValue), // Inflow
  /// ];
  ///
  /// final totalReturned = FinancialCalculator.calculateTotalReturned(cashFlows);
  /// print('Total Returned: ₹${totalReturned}'); // ₹11,500
  /// ```
  ///
  /// ## See Also
  ///
  /// - [calculateTotalInvested] for total outflows
  /// - [calculateNetCashFlow] for net profit/loss
  static double calculateTotalReturned(List<ICashFlow> cashFlows) {
    double total = 0.0;
    for (final cf in cashFlows) {
      if (cf.signedAmount > 0) {
        total += cf.amount;
      }
    }
    return total;
  }

  /// Calculates Absolute Return percentage.
  ///
  /// Absolute return is the simple percentage gain or loss on an investment,
  /// without considering time. It's useful for quick comparisons but doesn't
  /// account for how long the investment was held.
  ///
  /// ## Formula
  ///
  /// ```
  /// Absolute Return = ((Total Returned - Total Invested) / Total Invested) × 100
  /// ```
  ///
  /// ## Parameters
  ///
  /// - [invested]: Total amount invested (must be > 0 for meaningful result)
  /// - [returned]: Total value returned (current value + dividends + withdrawals)
  ///
  /// ## Returns
  ///
  /// - **double**: Absolute return as percentage (e.g., 20.0 = 20% return)
  /// - **0.0**: If invested = 0 (division by zero protection)
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Invested ₹10,000, current value ₹12,000
  /// final absReturn = FinancialCalculator.calculateAbsoluteReturn(10000, 12000);
  /// print('Absolute Return: ${absReturn.toStringAsFixed(2)}%'); // 20.00%
  ///
  /// // Loss scenario
  /// final loss = FinancialCalculator.calculateAbsoluteReturn(10000, 8000);
  /// print('Absolute Return: ${loss.toStringAsFixed(2)}%'); // -20.00%
  ///
  /// // Break-even
  /// final breakEven = FinancialCalculator.calculateAbsoluteReturn(10000, 10000);
  /// print('Absolute Return: ${breakEven.toStringAsFixed(2)}%'); // 0.00%
  /// ```
  ///
  /// ## When to Use
  ///
  /// - **Use Absolute Return**: For quick comparisons without time consideration
  /// - **Use XIRR**: For time-adjusted annualized return
  ///
  /// ## See Also
  ///
  /// - [calculateMOIC] for multiple-based return
  /// - [calculateNetCashFlow] for absolute profit/loss amount
  static double calculateAbsoluteReturn(double invested, double returned) {
    if (invested == 0) return 0.0;
    return ((returned - invested) / invested) * 100;
  }
}
