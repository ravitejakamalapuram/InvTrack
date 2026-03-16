1. **Optimize multi-currency conversion in Goal Progress calculation**
   - The `GoalProgressCalculator.calculateMultiCurrency` method currently loops through cashflows and awaits the `conversionService.convert` for each cashflow individually.
   - This creates an N+1 query problem, making sequential API calls (or cache lookups) for every single cashflow associated with a goal.
   - I will replace this sequential processing with the optimized `batchConverter.batchConvert` which handles deduplication and parallel processing (as is done in `multiCurrency_providers.dart`).

2. **Run formatting and tests**
   - Run `dart format .`
   - Run `flutter analyze`
   - Run `flutter test`

3. **Pre-commit step**
   - Use `pre_commit_instructions` tool to run the final checks before creating the pull request.

4. **Submit pull request**
   - Submit the changes using the `submit` tool with a descriptive commit message following Bolt's standard format.
