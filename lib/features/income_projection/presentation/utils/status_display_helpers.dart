/// Display helpers for income projection status enums
/// 
/// UI-layer utilities for converting domain enums to user-friendly display strings.
/// Centralizes all display logic outside of domain layer per Clean Architecture.
library;

import 'package:inv_tracker/features/income_projection/domain/entities/expected_cash_flow_entity.dart';
import 'package:inv_tracker/features/income_projection/domain/entities/reinvestment_opportunity.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Get localized display name for ExpectedCashFlowStatus
String getStatusDisplayName(AppLocalizations l10n, ExpectedCashFlowStatus status) {
  switch (status) {
    case ExpectedCashFlowStatus.upcoming:
      return l10n.incomeStatusUpcoming;
    case ExpectedCashFlowStatus.dueSoon:
      return l10n.incomeStatusDueSoon;
    case ExpectedCashFlowStatus.gracePeriod:
      return l10n.incomeStatusGracePeriod;
    case ExpectedCashFlowStatus.overdue:
      return l10n.incomeStatusOverdue;
    case ExpectedCashFlowStatus.received:
      return l10n.incomeStatusReceived;
    case ExpectedCashFlowStatus.dismissed:
      return l10n.incomeStatusDismissed;
  }
}

/// Get display name for PredictionSource (non-localized, technical labels)
String getPredictionSourceDisplayName(PredictionSource source) {
  switch (source) {
    case PredictionSource.fixed:
      return 'Fixed';
    case PredictionSource.wma:
      return 'Smart Prediction';
    case PredictionSource.manual:
      return 'Manual';
  }
}

/// Get display name for ReinvestmentType (non-localized, technical labels)
String getReinvestmentTypeDisplayName(ReinvestmentType type) {
  switch (type) {
    case ReinvestmentType.fixedDeposit:
      return 'Fixed Deposit';
    case ReinvestmentType.p2pLending:
      return 'P2P Lending';
    case ReinvestmentType.existingInvestment:
      return 'Top-up Existing';
    case ReinvestmentType.taxSaving:
      return 'Tax Saving';
    case ReinvestmentType.other:
      return 'Other';
  }
}

/// Get diversification risk label (non-localized, technical labels)
String getDiversificationRiskLabel(double hhi) {
  if (hhi < 0.15) return 'Excellent';
  if (hhi < 0.30) return 'Good';
  if (hhi < 0.50) return 'Moderate';
  return 'Risky';
}

/// Get localized growth trend label
String getGrowthTrendLabel(AppLocalizations l10n, double momGrowth) {
  if (momGrowth > 5) return l10n.growthTrendStrong;
  if (momGrowth > 0) return l10n.growthTrendPositive;
  if (momGrowth > -5) return l10n.growthTrendStable;
  return l10n.growthTrendDeclining;
}

/// Get localized platform reliability grade
String getPlatformReliabilityGrade(AppLocalizations l10n, double onTimeRate) {
  if (onTimeRate >= 0.95) return l10n.platformReliabilityExcellent;
  if (onTimeRate >= 0.85) return l10n.platformReliabilityGood;
  if (onTimeRate >= 0.70) return l10n.platformReliabilityFair;
  return l10n.platformReliabilityPoor;
}
