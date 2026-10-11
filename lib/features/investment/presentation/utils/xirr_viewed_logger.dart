import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/features/investment/presentation/utils/return_display.dart';

/// Where an XIRR is shown, as `xirr_viewed` reports it.
class XirrSurface {
  static const String overview = 'overview';
  static const String investmentDetail = 'investment_detail';
}

/// Logs `xirr_viewed` the first time in this process that [display] shows a
/// real XIRR on [surface].
///
/// Call it from the `build` of the widget that shows [display]. It does
/// nothing for the dash that stands in for an open investment without a
/// current value (money rule 4), for a short holding's absolute return, or
/// while [isHidden] by privacy mode; a surface already reported is skipped, so
/// rebuilds cost nothing. The event is logged after the frame, never during
/// the build.
void logXirrViewedOnce(
  WidgetRef ref, {
  required String surface,
  required ReturnDisplay display,
  required bool isHidden,
}) {
  if (display.kind != ReturnDisplayKind.annualised || isHidden) return;
  if (!ref.read(analyticsOnceProvider).add('xirr_viewed:$surface')) return;
  final analytics = ref.read(analyticsServiceProvider);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      analytics.logXirrViewed(surface: surface, isEstimate: display.isEstimate),
    );
  });
}
