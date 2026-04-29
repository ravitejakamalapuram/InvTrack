/// Analytics provider for Reports feature.
///
/// Centralizes analytics tracking for report viewing, export, and user interactions.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';

/// Provider for AnalyticsService instance.
///
/// Use this provider to log report-specific events throughout the Reports feature.
///
/// ## Example Usage
///
/// ```dart
/// // In a screen
/// final analytics = ref.read(analyticsServiceProvider);
/// await analytics.logReportViewed(reportType: 'weekly');
///
/// // In an export service
/// await analytics.logReportExported(
///   reportType: 'monthly',
///   format: 'pdf',
///   recordCount: 15,
/// );
/// ```
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});
