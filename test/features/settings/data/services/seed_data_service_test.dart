import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/settings/data/services/seed_data_service.dart';

import '../../../goals/data/repositories/mock_goal_repository.dart';
import '../../../investment/data/repositories/mock_investment_repository.dart';

void main() {
  test('demo data is stored in the base currency, never USD', () async {
    final investments = FakeInvestmentRepository();
    final goals = FakeGoalRepository();

    final result = await SeedDataService(
      investments,
      goals,
    ).seedDemoData(baseCurrency: 'INR');

    expect(result.investments, greaterThan(0));
    expect(investments.investments.map((i) => i.currency).toSet(), {'INR'});
    expect(investments.cashFlows.map((cf) => cf.currency).toSet(), {'INR'});
  });
}
