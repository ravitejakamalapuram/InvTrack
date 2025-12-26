import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/notifications/notification_navigator.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/core/theme/app_theme.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/notification_sync_initializer.dart';

class InvTrackerApp extends ConsumerWidget {
  const InvTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);

    return NotificationSyncInitializer(
      child: _NotificationNavigationHandler(
        child: MaterialApp.router(
          title: 'InvTracker',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: settings.themeMode,
          routerConfig: router,
        ),
      ),
    );
  }
}

/// Widget that handles navigation from notification taps.
///
/// Listens to the pending navigation stream and navigates to the
/// appropriate screen when a notification is tapped.
class _NotificationNavigationHandler extends ConsumerStatefulWidget {
  final Widget child;

  const _NotificationNavigationHandler({required this.child});

  @override
  ConsumerState<_NotificationNavigationHandler> createState() =>
      _NotificationNavigationHandlerState();
}

class _NotificationNavigationHandlerState
    extends ConsumerState<_NotificationNavigationHandler> {
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    // Listen for pending navigation from notifications
    _subscription = pendingNavigationStream.listen(_handleNavigation);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _handleNavigation(String payload) async {
    // Wait a bit for the app to be fully ready
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final navigator = ref.read(notificationNavigatorProvider);
    final success = await navigator.handleNotificationTap(payload);

    if (kDebugMode) {
      debugPrint('🔔 Navigation result: $success for payload: $payload');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
