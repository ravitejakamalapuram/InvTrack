// A10 (#754): users set or clear an open investment's current value. It is
// saved date-only, never in the future, and an edit of the investment's
// other details keeps it.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_notifier.dart';

import '../../data/repositories/mock_investment_repository.dart';
import '../../../../mocks/mock_analytics_service.dart';
import '../../../../mocks/mock_notification_service.dart';

InvestmentEntity _gold({
  InvestmentStatus status = InvestmentStatus.open,
  bool isArchived = false,
  double? value,
  DateTime? date,
  String currency = 'INR',
}) => InvestmentEntity(
  id: 'gold',
  name: 'SGB 2031',
  type: InvestmentType.gold,
  status: status,
  createdAt: DateTime(2025, 1, 1),
  updatedAt: DateTime(2025, 1, 1),
  isArchived: isArchived,
  currency: currency,
  currentValue: value,
  currentValueDate: date,
);

void main() {
  late FakeInvestmentRepository repo;
  late ProviderContainer container;
  late InvestmentNotifier notifier;

  setUp(() {
    repo = FakeInvestmentRepository();
    container = ProviderContainer(
      overrides: [
        investmentRepositoryProvider.overrideWithValue(repo),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        currencyCodeProvider.overrideWithValue('INR'),
      ],
    );
    notifier = container.read(investmentNotifierProvider.notifier);
  });

  tearDown(() {
    container.dispose();
    repo.reset();
  });

  test('saves the value with a date-only date', () async {
    repo.seed(investments: [_gold()]);

    await notifier.setCurrentValue(
      id: 'gold',
      value: 125000.555,
      date: DateTime(2026, 10, 1, 18, 45),
    );

    final saved = (await repo.getInvestmentById('gold'))!;
    expect(saved.currentValue, 125000.56, reason: 'rounded to the paisa');
    expect(saved.currentValueDate, DateTime(2026, 10, 1));
  });

  test(
    'rounds a current value to the investment currency minor unit',
    () async {
      repo.seed(investments: [_gold(currency: 'JPY')]);

      await notifier.setCurrentValue(
        id: 'gold',
        value: 125.6,
        date: DateTime(2026, 10, 1),
      );

      final saved = (await repo.getInvestmentById('gold'))!;
      expect(saved.currentValue, 126, reason: 'JPY has zero minor-unit digits');
    },
  );

  test('rounds a three-decimal currency to the thousandth', () async {
    repo.seed(investments: [_gold(currency: 'KWD')]);

    await notifier.setCurrentValue(
      id: 'gold',
      value: 1.2345,
      date: DateTime(2026, 10, 1),
    );

    final saved = (await repo.getInvestmentById('gold'))!;
    expect(
      saved.currentValue,
      1.235,
      reason: 'KWD has three minor-unit digits',
    );
  });

  test('clearing the value removes it', () async {
    repo.seed(investments: [_gold(value: 125000, date: DateTime(2026, 10, 1))]);

    await notifier.clearCurrentValue('gold');

    final saved = (await repo.getInvestmentById('gold'))!;
    expect(saved.currentValue, isNull);
    expect(saved.currentValueDate, isNull);
  });

  test('rejects negative, non-finite and future values', () async {
    repo.seed(investments: [_gold()]);
    final tomorrow = DateTime.now().add(const Duration(days: 1));

    for (final (value, date) in [
      (-1.0, DateTime(2026, 10, 1)),
      (double.nan, DateTime(2026, 10, 1)),
      (double.infinity, DateTime(2026, 10, 1)),
      (1000.0, tomorrow),
    ]) {
      await expectLater(
        notifier.setCurrentValue(id: 'gold', value: value, date: date),
        throwsA(isA<ValidationException>()),
      );
    }
    expect((await repo.getInvestmentById('gold'))!.currentValue, isNull);
  });

  test('closed investments cannot be valued', () async {
    repo.seed(investments: [_gold(status: InvestmentStatus.closed)]);

    await expectLater(
      notifier.setCurrentValue(
        id: 'gold',
        value: 1000,
        date: DateTime(2026, 10, 1),
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  test('editing other details keeps the current value', () async {
    repo.seed(investments: [_gold(value: 125000, date: DateTime(2026, 10, 1))]);

    await notifier.updateInvestment(
      id: 'gold',
      name: 'SGB 2031 tranche I',
      type: InvestmentType.gold,
    );

    final saved = (await repo.getInvestmentById('gold'))!;
    expect(saved.name, 'SGB 2031 tranche I');
    expect(saved.currentValue, 125000);
    expect(saved.currentValueDate, DateTime(2026, 10, 1));
  });

  test('editing with the same currency keeps the current value', () async {
    repo.seed(investments: [_gold(value: 125000, date: DateTime(2026, 10, 1))]);

    await notifier.updateInvestment(
      id: 'gold',
      name: 'SGB 2031',
      type: InvestmentType.gold,
      currency: 'INR',
    );

    final saved = (await repo.getInvestmentById('gold'))!;
    expect(saved.currentValue, 125000);
    expect(saved.currentValueDate, DateTime(2026, 10, 1));
  });

  test('changing the currency clears the current value', () async {
    // The value was entered in INR; read as USD it would be 83x too large.
    repo.seed(investments: [_gold(value: 125000, date: DateTime(2026, 10, 1))]);

    await notifier.updateInvestment(
      id: 'gold',
      name: 'SGB 2031',
      type: InvestmentType.gold,
      currency: 'USD',
    );

    final saved = (await repo.getInvestmentById('gold'))!;
    expect(saved.currency, 'USD');
    expect(saved.currentValue, isNull);
    expect(saved.currentValueDate, isNull);
  });
}
