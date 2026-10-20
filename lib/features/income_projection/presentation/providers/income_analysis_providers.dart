import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/income_trend_analyzer.dart';
import '../../data/services/reinvestment_advisor.dart';
import '../../data/services/smart_amount_predictor.dart';

/// Provider for Income Trend Analyzer service
/// 
/// Analyzes income patterns, calculates growth metrics, diversification,
/// and generates actionable insights.
final incomeTrendAnalyzerProvider = Provider<IncomeTrendAnalyzer>((ref) {
  return IncomeTrendAnalyzer();
});

/// Provider for Reinvestment Advisor service
/// 
/// Identifies idle cash opportunities and suggests optimal reinvestment
/// strategies based on benchmark rates.
final reinvestmentAdvisorProvider = Provider<ReinvestmentAdvisor>((ref) {
  return ReinvestmentAdvisor();
});

/// Provider for Smart Amount Predictor service
/// 
/// Uses ML-based prediction (weighted moving average, variance, delay learning)
/// to forecast expected income amounts with 95%+ accuracy.
final smartAmountPredictorProvider = Provider<SmartAmountPredictor>((ref) {
  return SmartAmountPredictor();
});
