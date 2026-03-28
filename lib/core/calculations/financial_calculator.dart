/// Financial calculations for investment analysis.
///
/// This utility class provides common financial metrics used in investment tracking:
/// - **XIRR**: Extended Internal Rate of Return (annualized return for irregular cash flows)
/// - **CAGR**: Compound Annual Growth Rate (annualized return for single investment)
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
/// print('XIRR: ${(xirr * 100).toStringAsFixed(2)}%'); // ~15%
///
/// // Calculate CAGR for a simple investment
/// final cagr = FinancialCalculator.calculateCAGR(10000, 12000, 2);
/// print('CAGR: ${(cagr * 100).toStringAsFixed(2)}%'); // ~9.54%
///
/// // Calculate MOIC
/// final moic = FinancialCalculator.calculateMOIC(10000, 12000);
/// print('MOIC: ${moic.toStringAsFixed(2)}x'); // 1.20x
/// ```
library;

import 'dart:math';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

/// Utility class for financial calculations used in investment analysis.
///
/// See library documentation above for usage examples.
class FinancialCalculator {
  /// Calculates XIRR (Extended Internal Rate of Return) from a list of cash flows.
  ///
  /// XIRR is the annualized rate of return for investments with irregular cash flows.
  /// It's more accurate than CAGR for real-world scenarios with multiple transactions.
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
  /// - **0.0**: If cash flows are empty or invalid (all inflows or all outflows)
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
  /// print('XIRR: ${(xirr * 100).toStringAsFixed(2)}%'); // ~15%
  /// ```
  ///
  /// ## See Also
  ///
  /// - [XirrSolver.calculateXirr] for the underlying algorithm
  /// - [calculateCAGR] for simple single-investment scenarios
  static double calculateXirrFromCashFlows(List<CashFlowEntity> cashFlows) {
    if (cashFlows.isEmpty) return 0.0;

    final dates = <DateTime>[];
    final amounts = <double>[];

    // Optimization: Skip zero amount cash flows before passing to XIRR solver
    // Zero amounts don't affect XIRR and just waste calculation cycles
    for (final cf in cashFlows) {
      final amount = cf.signedAmount;
      if (amount == 0.0) continue;

      dates.add(cf.date);
      amounts.add(amount);
    }

    if (dates.isEmpty) return 0.0;

    return XirrSolver.calculateXirr(dates, amounts) ?? 0.0;
  }

  /// Calculates CAGR (Compound Annual Growth Rate).
  ///
  /// CAGR is the annualized rate of return for a single investment over a period of time.
  /// It assumes all returns are reinvested and compounds annually.
  ///
  /// ## Formula
  ///
  /// ```
  /// CAGR = (endValue / startValue)^(1/years) - 1
  /// ```
  ///
  /// ## Parameters
  ///
  /// - [startValue]: Initial investment amount (must be > 0)
  /// - [endValue]: Final value of investment
  /// - [years]: Time period in years (must be > 0)
  ///
  /// ## Returns
  ///
  /// - **double**: CAGR as decimal (e.g., 0.0954 = 9.54% annual return)
  /// - **0.0**: If startValue ≤ 0 or years ≤ 0 (invalid inputs)
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Investment: ₹10,000 → ₹12,000 over 2 years
  /// final cagr = FinancialCalculator.calculateCAGR(10000, 12000, 2);
  /// print('CAGR: ${(cagr * 100).toStringAsFixed(2)}%'); // 9.54%
  ///
  /// // Loss scenario: ₹10,000 → ₹8,000 over 1 year
  /// final loss = FinancialCalculator.calculateCAGR(10000, 8000, 1);
  /// print('CAGR: ${(loss * 100).toStringAsFixed(2)}%'); // -20.00%
  /// ```
  ///
  /// ## When to Use
  ///
  /// - **Use CAGR**: For single lump-sum investments (e.g., FD, bonds)
  /// - **Use XIRR**: For multiple transactions (e.g., SIP, dividends, partial withdrawals)
  ///
  /// ## See Also
  ///
  /// - [calculateXirrFromCashFlows] for investments with multiple transactions
  static double calculateCAGR(
    double startValue,
    double endValue,
    double years,
  ) {
    if (startValue <= 0 || years <= 0) return 0.0;
    return pow(endValue / startValue, 1 / years) - 1;
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
  /// - [calculateCAGR] for time-adjusted annualized return
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
  static double calculateTotalInvested(List<CashFlowEntity> cashFlows) {
    double total = 0.0;
    for (final cf in cashFlows) {
      if (cf.type.isOutflow) {
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
  static double calculateTotalReturned(List<CashFlowEntity> cashFlows) {
    double total = 0.0;
    for (final cf in cashFlows) {
      if (cf.type.isInflow) {
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
  /// - **Use CAGR**: For time-adjusted annualized return (single investment)
  /// - **Use XIRR**: For time-adjusted annualized return (multiple transactions)
  ///
  /// ## See Also
  ///
  /// - [calculateCAGR] for annualized return
  /// - [calculateMOIC] for multiple-based return
  /// - [calculateNetCashFlow] for absolute profit/loss amount
  static double calculateAbsoluteReturn(double invested, double returned) {
    if (invested == 0) return 0.0;
    return ((returned - invested) / invested) * 100;
  }
}
