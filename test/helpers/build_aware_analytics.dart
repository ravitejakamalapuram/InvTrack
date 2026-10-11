import 'package:flutter/widgets.dart';

import '../mocks/mock_analytics_service.dart';

/// A [FakeAnalyticsService] that notes, for every event, whether the widget
/// tree was in its build phase when the event was logged. Logging from
/// `build()` runs on every rebuild; it has to wait for the end of the frame.
class BuildAwareAnalytics extends FakeAnalyticsService {
  /// One entry per logged event: true if it was logged while building.
  final loggedWhileBuilding = <bool>[];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) {
    loggedWhileBuilding.add(
      WidgetsBinding.instance.buildOwner?.debugBuilding ?? false,
    );
    return super.logEvent(name: name, parameters: parameters);
  }
}
