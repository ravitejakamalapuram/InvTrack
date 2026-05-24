/// Reinvestment Advisor Service
///
/// Detects idle cash and generates reinvestment opportunities with
/// opportunity cost calculations and investment suggestions.
library;

import 'package:uuid/uuid.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/income_projection/domain/entities/reinvestment_opportunity.dart';

/// Reinvestment Advisor Service
class ReinvestmentAdvisor {
  static const _uuid = Uuid();

  /// Detect idle cash and generate reinvestment opportunities
  List<ReinvestmentOpportunity> detectOpportunities({
    required List<InvestmentEntity> investments,
    required List<CashFlowEntity> cashFlows,
    required double savingsRate,
    required double benchmarkRate, // e.g., 8% FD rate
    int minimumIdleDays = 3,
  }) {
    final opportunities = <ReinvestmentOpportunity>[];
    final now = DateTime.now();
    final Map<String, InvestmentEntity> investmentMap = {
      for (final inv in investments) inv.id: inv,
    };

    // Group income by investment
    final incomeByInvestment = <String, List<CashFlowEntity>>{};
    for (final cf in cashFlows) {
      if (cf.type != CashFlowType.income) continue;
      incomeByInvestment.putIfAbsent(cf.investmentId, () => []).add(cf);
    }

    // Check each investment for idle cash
    for (final entry in incomeByInvestment.entries) {
      final investmentId = entry.key;
      final incomePayments = entry.value
        ..sort((a, b) => b.date.compareTo(a.date));

      // Get most recent income payment
      if (incomePayments.isEmpty) continue;
      final latestIncome = incomePayments.first;

      // Calculate days idle
      final daysIdle = now.difference(latestIncome.date).inDays;
      if (daysIdle < minimumIdleDays) continue;

      // Get investment details
      final investment = investmentMap[investmentId] ?? investments.first;

      // Calculate opportunity cost
      final dailyRate = (benchmarkRate - savingsRate) / 365 / 100;
      final opportunityCostDaily = latestIncome.amount * dailyRate;
      final opportunityCostMonthly = opportunityCostDaily * 30;

      // Generate investment suggestions
      final suggestions = _generateSuggestions(
        availableAmount: latestIncome.amount,
        currency: latestIncome.currency,
        benchmarkRate: benchmarkRate,
        investment: investment,
        investments: investments,
      );

      // Create opportunity
      opportunities.add(
        ReinvestmentOpportunity(
          id: _uuid.v4(),
          cashFlowId: latestIncome.id,
          investmentId: investmentId,
          availableAmount: latestIncome.amount,
          currency: latestIncome.currency,
          daysIdle: daysIdle,
          receivedDate: latestIncome.date,
          savingsRate: savingsRate,
          benchmarkRate: benchmarkRate,
          opportunityCostDaily: opportunityCostDaily,
          opportunityCostMonthly: opportunityCostMonthly,
          suggestions: suggestions,
          createdAt: now,
        ),
      );
    }

    // Sort by urgency (days idle descending)
    opportunities.sort((a, b) => b.daysIdle.compareTo(a.daysIdle));

    return opportunities;
  }

  /// Generate investment suggestions
  List<InvestmentSuggestion> _generateSuggestions({
    required double availableAmount,
    required String currency,
    required double benchmarkRate,
    required InvestmentEntity investment,
    required List<InvestmentEntity> investments,
  }) {
    final suggestions = <InvestmentSuggestion>[];

    // 1. Fixed Deposit suggestion (safe option)
    suggestions.add(
      InvestmentSuggestion(
        id: _uuid.v4(),
        type: ReinvestmentType.fixedDeposit,
        name: 'Fixed Deposit (${benchmarkRate.toStringAsFixed(1)}%)',
        description: 'Safe, guaranteed returns. Lock-in for 1 year.',
        suggestedAmount: availableAmount,
        expectedReturn: benchmarkRate,
        tenureMonths: 12,
      ),
    );

    // 2. P2P Lending suggestion (higher risk/return)
    if (availableAmount >= 10000) {
      suggestions.add(
        InvestmentSuggestion(
          id: _uuid.v4(),
          type: ReinvestmentType.p2pLending,
          name: 'P2P Lending (12-14%)',
          description:
              'Higher returns with moderate risk. Diversified across borrowers.',
          suggestedAmount: availableAmount,
          expectedReturn: 13.0,
          tenureMonths: 12,
        ),
      );
    }

    // 3. Top-up existing investment (if applicable)
    final activeInvestments = investments
        .where(
          (inv) =>
              inv.status == InvestmentStatus.open &&
              inv.id != investment.id &&
              inv.type != InvestmentType.realEstate, // Can't top-up real estate
        )
        .toList();

    if (activeInvestments.isNotEmpty) {
      final topPerformer = activeInvestments.first;
      suggestions.add(
        InvestmentSuggestion(
          id: _uuid.v4(),
          type: ReinvestmentType.existingInvestment,
          name: 'Top-up ${topPerformer.name}',
          description:
              'Add to your existing ${topPerformer.type.name} investment.',
          suggestedAmount: availableAmount,
          expectedReturn: topPerformer.expectedRate ?? benchmarkRate,
          tenureMonths: topPerformer.tenureMonths ?? 12,
          existingInvestmentId: topPerformer.id,
        ),
      );
    }

    return suggestions.take(3).toList();
  }

  /// Calculate total opportunity cost for all idle cash
  double calculateTotalOpportunityCost(
    List<ReinvestmentOpportunity> opportunities,
  ) {
    return opportunities.fold<double>(
      0.0,
      (sum, opp) => sum + opp.totalOpportunityCostLost,
    );
  }

  /// Get opportunities requiring notification
  List<ReinvestmentOpportunity> getNotificationQueue(
    List<ReinvestmentOpportunity> opportunities,
  ) {
    return opportunities.where((opp) => opp.shouldNotify).toList();
  }
}
