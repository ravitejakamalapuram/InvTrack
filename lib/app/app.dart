import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/core/theme/app_theme.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/data/presentation/providers/data_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';

class InvTrackerApp extends ConsumerWidget {
  const InvTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);

    // Listen to auth state and update currentUserIdProvider
    // This ensures the database is switched when user changes
    ref.listen<AsyncValue<dynamic>>(authStateProvider, (previous, next) {
      final user = next.valueOrNull;
      final userId = user?.id as String?;
      final currentUserId = ref.read(currentUserIdProvider);

      // Only update if user ID actually changed to avoid unnecessary rebuilds
      if (userId != currentUserId) {
        debugPrint('[App] Auth state changed, updating user ID: $currentUserId -> $userId');
        ref.read(currentUserIdProvider.notifier).state = userId;

        // Initialize data from cloud for Google users
        // This is done asynchronously - the UI will show cached data while loading
        if (userId != null) {
          Future.microtask(() async {
            final result = await ref.read(dataControllerProvider).initialize();
            if (result.isFailure) {
              debugPrint('[App] Data initialization failed: ${result.error}');
            }
          });
        }
      }
    });

    // Also set initial user ID on first build
    final authState = ref.watch(authStateProvider);
    if (authState.hasValue && authState.value != null) {
      final userId = authState.value!.id;
      final currentUserId = ref.read(currentUserIdProvider);
      if (userId != currentUserId) {
        // Use Future.microtask to avoid modifying state during build
        Future.microtask(() {
          ref.read(currentUserIdProvider.notifier).state = userId;
        });
      }
    }

    return MaterialApp.router(
      title: 'InvTracker',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      routerConfig: router,
    );
  }
}
