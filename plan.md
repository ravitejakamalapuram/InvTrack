1. **Optimize `.fold()` operations in `lib/features/investment/presentation/providers/multi_currency_providers.dart`**
   - Replace `.fold<double>(0.0, (sum, cf) => sum + cf.amount)` with standard `for` loops in `multiCurrencyInvestedAmount` and `multiCurrencyReturnedAmount`.
   - *Why*: As noted in the instructions, "replacing `.fold()` with a standard `for` loop in performance-critical sections avoids closure allocation overhead per iteration, improving overall execution time."

2. **Pre commit step**
   - Run `pre_commit_instructions` and follow testing and linting directions.

3. **Submit the change**
   - Create a PR titled "⚡ Bolt: [performance improvement] Replace fold with for loop for performance".
