import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';

/// Logs a `screen_view` through [AnalyticsService] whenever a named page is
/// shown, so a test can watch it with `FakeAnalyticsService`.
///
/// Only [PageRoute]s with a name count: dialogs and bottom sheets are not
/// screens, and an unnamed page stays out of the report instead of showing up
/// under its path. Names come from `AnalyticsScreens`.
///
/// Give `GoRouter` one instance and no other. go_router forwards the events of
/// every tab's Navigator to the router's observers (`notifyRootObserver`), so
/// a second instance on a tab would log each of its screens twice.
class AnalyticsRouteObserver extends NavigatorObserver {
  AnalyticsRouteObserver(this._analytics);

  final AnalyticsService _analytics;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _log(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _log(newRoute);

  /// The page underneath is on screen again, but only when a page was
  /// closed: closing a dialog or a sheet shows no new screen.
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) _log(previousRoute);
  }

  void _log(Route<dynamic>? route) {
    final name = route is PageRoute ? route.settings.name : null;
    if (name != null) unawaited(_analytics.logScreenView(screenName: name));
  }
}
