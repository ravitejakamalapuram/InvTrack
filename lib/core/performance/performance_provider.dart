/// Provider for performance monitoring service.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/performance/performance_service.dart';

/// Provider for the PerformanceService singleton
final performanceServiceProvider = Provider<PerformanceService>((ref) {
  return PerformanceService();
});
