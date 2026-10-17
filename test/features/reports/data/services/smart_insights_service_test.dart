import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/reports/data/services/smart_insights_service.dart';
import 'package:inv_tracker/features/reports/domain/entities/smart_insight.dart';
import 'package:inv_tracker/l10n/generated/app_localizations_en.dart';

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  InvestmentEntity investment(InvestmentStatus status) => InvestmentEntity(
    id: 'inv',
    name: 'P2P loan',
    type: InvestmentType.p2pLending,
    status: status,
    startDate: today.subtract(const Duration(days: 90)),
    createdAt: today,
    updatedAt: today,
    currency: 'INR',
  );

  CashFlowEntity flow(CashFlowType type, double amount, int daysAgo) =>
      CashFlowEntity(
        id: '$type$daysAgo',
        investmentId: 'inv',
        date: today.subtract(Duration(days: daysAgo)),
        type: type,
        amount: amount,
        createdAt: today,
        currency: 'INR',
      );

  // 50% back on cash 60 days ago, then 1000 more put in: the cash-only
  // "return" drops by 75 points.
  final flows = [
    flow(CashFlowType.invest, 1000, 60),
    flow(CashFlowType.returnFlow, 1500, 60),
    flow(CashFlowType.invest, 1000, 5),
  ];

  List<SmartInsight> declining(InvestmentStatus status) =>
      SmartInsightsService()
          .generateInsights(
            investments: [investment(status)],
            cashFlows: flows,
            goals: const [],
            currencySymbol: '₹',
            locale: 'en_IN',
            l10n: AppLocalizationsEn(),
          )
          .where((i) => i.type == InsightType.decliningInvestment)
          .toList();

  test('an open holding gets no declining alert from cash alone', () {
    expect(declining(InvestmentStatus.open), isEmpty);
  });

  test('a closed holding still gets the declining alert', () {
    final alerts = declining(InvestmentStatus.closed);
    expect(alerts, hasLength(1));
    expect(alerts.single.value, '-75.0%');
  });
}
