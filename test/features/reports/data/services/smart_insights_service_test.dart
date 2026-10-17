import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/reports/data/services/smart_insights_service.dart';
import 'package:inv_tracker/features/reports/domain/entities/smart_insight.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

void main() {
  group('SmartInsightsService declining alert (money rule 4)', () {
    final service = SmartInsightsService();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final longAgo = today.subtract(const Duration(days: 60));
    final recent = today.subtract(const Duration(days: 2));

    InvestmentEntity investment(InvestmentStatus status) => InvestmentEntity(
      id: 'inv1',
      name: 'FD',
      type: InvestmentType.fixedDeposit,
      status: status,
      startDate: longAgo,
      createdAt: longAgo,
      updatedAt: longAgo,
      currency: 'INR',
    );

    CashFlowEntity flow(
      String id,
      double amount,
      CashFlowType type,
      DateTime d,
    ) => CashFlowEntity(
      id: id,
      investmentId: 'inv1',
      amount: amount,
      date: d,
      type: type,
      currency: 'INR',
      createdAt: d,
    );

    List<SmartInsight> declining(
      InvestmentStatus status,
      List<CashFlowEntity> flows,
    ) {
      return service
          .generateInsights(
            investments: [investment(status)],
            cashFlows: flows,
            goals: const [],
            currencySymbol: '₹',
            locale: 'en_IN',
            l10n: lookupAppLocalizations(const Locale('en')),
          )
          .where((i) => i.type == InsightType.decliningInvestment)
          .toList();
    }

    // Paid back (1500 back on 1400 in): a cash-only minimum, not a decline.
    final paidBack = [
      flow('1', 1000, CashFlowType.invest, longAgo),
      flow('2', 1500, CashFlowType.returnFlow, longAgo),
      flow('3', 400, CashFlowType.fee, recent),
    ];
    // 600 back on 1500 in, no current value: awaiting a value.
    final awaiting = [
      flow('1', 1000, CashFlowType.invest, longAgo),
      flow('2', 600, CashFlowType.returnFlow, longAgo),
      flow('3', 500, CashFlowType.fee, recent),
    ];

    test('open holding that has been paid back raises no alert', () {
      expect(declining(InvestmentStatus.open, paidBack), isEmpty);
    });

    test('open holding awaiting a value raises no alert', () {
      expect(declining(InvestmentStatus.open, awaiting), isEmpty);
    });

    test('closed holding with the same cash flows still alerts', () {
      final alerts = declining(InvestmentStatus.closed, awaiting);
      expect(alerts, hasLength(1));
      expect(alerts.single.value, '-20.0%');
    });
  });
}
