/// Widget that initializes Income Guardian services on app startup.
///
/// This widget starts the monitoring and sync services for expected income payments:
/// - IncomeGuardianMonitorService: Triggers notifications for overdue/upcoming payments
/// - IncomeGuardianSyncService: Auto-matches actual payments to expected projections
///
/// Services only start when user is authenticated and stop on cleanup.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/features/income_projection/presentation/providers/income_guardian_service_providers.dart';

/// A widget that initializes Income Guardian background services.
///
/// Wraps the app and starts monitoring/sync services when authenticated.
/// Services automatically stop when the widget is disposed.
class IncomeGuardianServiceInitializer extends ConsumerStatefulWidget {
  final Widget child;

  const IncomeGuardianServiceInitializer({super.key, required this.child});

  @override
  ConsumerState<IncomeGuardianServiceInitializer> createState() =>
      _IncomeGuardianServiceInitializerState();
}

class _IncomeGuardianServiceInitializerState
    extends ConsumerState<IncomeGuardianServiceInitializer> {
  bool _servicesStarted = false;

  @override
  void initState() {
    super.initState();
    // Start services after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startServicesIfAuthenticated();
    });
  }

  /// Start Income Guardian services if user is authenticated
  void _startServicesIfAuthenticated() {
    final isAuthenticated = ref.read(isAuthenticatedProvider);

    if (!isAuthenticated) {
      LoggerService.debug('User not authenticated - skipping Income Guardian services');
      return;
    }

    if (_servicesStarted) {
      return;
    }

    try {
      // Initialize services (this triggers service start via provider lifecycle)
      ref.read(incomeGuardianServiceInitializerProvider);
      _servicesStarted = true;

      LoggerService.info('Income Guardian services started successfully');
    } catch (e) {
      LoggerService.error(
        'Error starting Income Guardian services',
        error: e,
        metadata: {'service': 'IncomeGuardianServiceInitializer'},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth state changes
    ref.listen<bool>(isAuthenticatedProvider, (previous, next) {
      if (next && !_servicesStarted) {
        _startServicesIfAuthenticated();
      }
    });

    // Render child immediately
    return widget.child;
  }
}
