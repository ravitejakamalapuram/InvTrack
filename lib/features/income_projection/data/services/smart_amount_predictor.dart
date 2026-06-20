/// Smart Amount Predictor Service
///
/// ML-based income amount prediction using Weighted Moving Average (WMA),
/// seasonal adjustments, and platform behavior learning.
library;

import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

/// Result of amount prediction
class PredictionResult {
  final double predictedAmount;
  final double varianceFactor; // 0.0 to 1.0 (used for tolerance)
  final int platformDelayDays;
  final bool isSeasonalBonus; // Q4 detection

  const PredictionResult({
    required this.predictedAmount,
    required this.varianceFactor,
    required this.platformDelayDays,
    this.isSeasonalBonus = false,
  });
}

/// Smart Amount Predictor Service
class SmartAmountPredictor {
  /// Predict next income amount using Weighted Moving Average (WMA)
  ///
  /// Requires at least 3 historical payments. Returns fixed amount if < 3.
  ///
  /// Algorithm:
  /// - Uses last 6 payments (30%, 25%, 20%, 15%, 7%, 3% weights)
  /// - Applies seasonal adjustment for Q4 bonuses
  /// - Learns platform delay patterns
  /// - Calculates variance for dynamic tolerance
  PredictionResult predictAmount({
    required InvestmentEntity investment,
    required List<CashFlowEntity> historicalIncome,
    required DateTime expectedDate,
  }) {
    // Filter to income-only transactions, sorted by date descending
    final incomePayments =
        historicalIncome.where((cf) => cf.type == CashFlowType.income).toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    // Need at least 3 payments for meaningful prediction
    if (incomePayments.length < 3) {
      return PredictionResult(
        predictedAmount: _getFixedAmount(investment),
        varianceFactor: 0.0,
        platformDelayDays: 0,
      );
    }

    // 1. Calculate WMA
    final wmaAmount = _calculateWMA(incomePayments);

    // 2. Detect seasonal patterns (Q4 bonus)
    final isQ4 = expectedDate.month >= 10 && expectedDate.month <= 12;
    final seasonalMultiplier = isQ4
        ? _detectSeasonalBonus(incomePayments)
        : 1.0;

    // 3. Learn platform delay
    final platformDelay = _learnPlatformDelay(investment, incomePayments);

    // 4. Calculate variance
    final variance = _calculateVariance(incomePayments);

    // 5. Apply seasonal adjustment
    final predictedAmount = wmaAmount * seasonalMultiplier;

    return PredictionResult(
      predictedAmount: predictedAmount,
      varianceFactor: variance,
      platformDelayDays: platformDelay,
      isSeasonalBonus: seasonalMultiplier > 1.0,
    );
  }

  /// Calculate Weighted Moving Average
  ///
  /// Weights (most recent to oldest): 30%, 25%, 20%, 15%, 7%, 3%
  double _calculateWMA(List<CashFlowEntity> payments) {
    final weights = [0.30, 0.25, 0.20, 0.15, 0.07, 0.03];
    final count = payments.length < 6 ? payments.length : 6;

    double weightedSum = 0.0;
    double totalWeight = 0.0;

    for (int i = 0; i < count; i++) {
      weightedSum += payments[i].amount * weights[i];
      totalWeight += weights[i];
    }

    return weightedSum / totalWeight;
  }

  /// Detect Q4 seasonal bonus pattern
  ///
  /// Returns multiplier (1.0 = no bonus, 1.2 = 20% bonus)
  double _detectSeasonalBonus(List<CashFlowEntity> payments) {
    // Need at least 2 years of data
    if (payments.length < 8) return 1.0;

    double q4Total = 0.0;
    int q4Count = 0;
    double nonQ4Total = 0.0;
    int nonQ4Count = 0;

    // Optimization: Single pass loop replacing multiple sequential .where().toList(), .map() and .reduce() calls
    for (final p in payments) {
      if (p.date.month >= 10 && p.date.month <= 12) {
        q4Total += p.amount;
        q4Count++;
      } else {
        nonQ4Total += p.amount;
        nonQ4Count++;
      }
    }

    if (q4Count == 0 || nonQ4Count == 0) return 1.0;

    final q4Average = q4Total / q4Count;
    final nonQ4Average = nonQ4Total / nonQ4Count;

    // If Q4 average is > 15% higher, it's a seasonal bonus
    if (q4Average > nonQ4Average * 1.15) {
      return q4Average / nonQ4Average;
    }

    return 1.0;
  }

  /// Learn platform-specific delay pattern
  ///
  /// Returns average delay in days (0 = always on time)
  int _learnPlatformDelay(
    InvestmentEntity investment,
    List<CashFlowEntity> payments,
  ) {
    if (investment.incomeFrequency == null || payments.length < 4) {
      return 0;
    }

    // Calculate expected dates based on frequency
    final delays = <int>[];
    final frequency = investment.incomeFrequency!;
    final monthsBetween = frequency.monthsBetweenPayments;

    // Start with the most recent payment as baseline
    for (int i = 1; i < payments.length && i < 6; i++) {
      final actual = payments[i - 1].date;
      final previous = payments[i].date;

      // Expected = previous + frequency months
      final expectedMonth = previous.month + monthsBetween;
      final expectedYear = previous.year + (expectedMonth > 12 ? 1 : 0);
      final adjustedMonth = expectedMonth > 12
          ? expectedMonth - 12
          : expectedMonth;

      final expected = DateTime(expectedYear, adjustedMonth, previous.day);

      final delayDays = actual.difference(expected).inDays;

      // Only track positive delays (not early payments)
      if (delayDays > 0 && delayDays < 10) {
        delays.add(delayDays);
      }
    }

    if (delays.isEmpty) return 0;

    // Return average delay
    int totalDelay = 0;
    for (final delay in delays) {
      totalDelay += delay;
    }
    return (totalDelay / delays.length).round();
  }

  /// Calculate variance factor for dynamic tolerance
  ///
  /// Returns 0.0 to 1.0 (0.0 = no variance, 1.0 = high variance)
  double _calculateVariance(List<CashFlowEntity> payments) {
    if (payments.length < 3) return 0.0;

    final count = payments.length < 6 ? payments.length : 6;
    double sum = 0.0;

    // Optimization: Single pass loop for mean calculation
    for (int i = 0; i < count; i++) {
      sum += payments[i].amount;
    }
    final mean = sum / count;

    // Optimization: Single pass loop for variance calculation
    double sumSquaredDiffs = 0.0;
    for (int i = 0; i < count; i++) {
      final diff = payments[i].amount - mean;
      sumSquaredDiffs += diff * diff;
    }

    final variance = sumSquaredDiffs / count;
    final stdDev = variance > 0 ? variance.abs().toDouble() : 0.0;

    // Normalize to 0.0 - 1.0 range
    // Coefficient of variation (CV) = stdDev / mean
    final cv = mean > 0 ? stdDev / mean : 0.0;

    // Cap at 1.0
    return cv > 1.0 ? 1.0 : cv;
  }

  /// Get fixed amount from investment metadata
  double _getFixedAmount(InvestmentEntity investment) {
    // For FDs, bonds: Calculate based on expected rate
    if (investment.expectedRate != null && investment.expectedRate! > 0) {
      // This would require principal amount calculation
      // For now, return a default (will be enhanced later)
      return 0.0;
    }

    // No fixed amount available
    return 0.0;
  }

  /// Predict amount with fallback to fixed
  ///
  /// Public helper for easy access
  double predictAmountSimple({
    required InvestmentEntity investment,
    required List<CashFlowEntity> historicalIncome,
    required DateTime expectedDate,
  }) {
    final result = predictAmount(
      investment: investment,
      historicalIncome: historicalIncome,
      expectedDate: expectedDate,
    );
    return result.predictedAmount;
  }
}
