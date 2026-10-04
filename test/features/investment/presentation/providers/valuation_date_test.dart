// A21 review follow-up: "today" for Year over Year, the health score and
// estimated current values moves to the new day after local midnight, so an
// app left open overnight does not keep yesterday's date (and its financial
// year).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';

void main() {
  // testWidgets runs timers on a fake clock that pump() moves forward.
  testWidgets('today and the Year over Year period move to the next day '
      'after midnight', (tester) async {
    var now = DateTime(2027, 3, 31, 23, 59, 30);
    final container = ProviderContainer(
      overrides: [
        valuationClockProvider.overrideWithValue(() => now),
        convertedCashFlowsProvider.overrideWithValue(
          AsyncValue.data([
            CashFlowEntity(
              id: 'income',
              investmentId: 'fd',
              type: CashFlowType.income,
              amount: 500,
              currency: 'INR',
              date: DateTime(2027, 4, 1),
              createdAt: DateTime(2027, 4, 1),
            ),
          ]),
        ),
      ],
    );
    container.listen(yoyComparisonProvider, (_, _) {});

    expect(container.read(valuationDateProvider), DateTime(2027, 3, 31));
    final before = container.read(yoyComparisonProvider).requireValue;
    expect(before.periodStart, DateTime(2026, 4, 1));
    expect(before.periodEnd, DateTime(2027, 4, 1));
    // Dated tomorrow: not counted yet.
    expect(before.thisYearReturned, 0.0);

    now = DateTime(2027, 4, 1, 0, 0, 30);
    await tester.pump(const Duration(minutes: 1));

    expect(container.read(valuationDateProvider), DateTime(2027, 4, 1));
    final after = container.read(yoyComparisonProvider).requireValue;
    expect(after.periodStart, DateTime(2027, 4, 1));
    expect(after.periodEnd, DateTime(2027, 4, 2));
    expect(after.thisYearReturned, closeTo(500.00, 0.005));

    container.dispose();
  });

  testWidgets('dependents are not rebuilt while the day is the same', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 4, 9);
    final container = ProviderContainer(
      overrides: [valuationClockProvider.overrideWithValue(() => now)],
    );
    final dates = <DateTime>[];
    container.listen(
      valuationDateProvider,
      (_, next) => dates.add(next),
      fireImmediately: true,
    );

    now = DateTime(2026, 10, 4, 18);
    await tester.pump(const Duration(minutes: 5));

    expect(dates, [DateTime(2026, 10, 4)]);
    container.dispose();
  });
}
