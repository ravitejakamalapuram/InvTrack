import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';

/// Widget that initializes currency conversion cache on app start.
///
/// This widget:
/// 1. Refreshes live cache if needed (throttled to prevent excessive API calls)
/// 2. Preloads common rates in background (don't block UI)
///
/// The initialization happens after the first frame is rendered to avoid
/// blocking the UI during app startup.
class CurrencyCacheInitializer extends ConsumerStatefulWidget {
  final Widget child;

  const CurrencyCacheInitializer({super.key, required this.child});

  @override
  ConsumerState<CurrencyCacheInitializer> createState() =>
      _CurrencyCacheInitializerState();
}

class _CurrencyCacheInitializerState
    extends ConsumerState<CurrencyCacheInitializer> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Defer initialization to after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCurrencyCache();
    });
  }

  Future<void> _initializeCurrencyCache() async {
    if (_initialized) return;

    try {
      // BUG FIX (2026-05-04): Provider now returns null when unauthenticated
      // Check for null service instead of checking auth state separately
      // Fixes Crashlytics issue #50a389e45315ab4cb1393f56b731f6ff variant
      final service = ref.read(currencyConversionServiceProvider);

      if (service == null) {
        LoggerService.debug(
          'Skipping currency cache initialization - user not authenticated',
        );
        return;
      }

      final baseCurrency = ref.read(currencyCodeProvider);

      // 1. Refresh live cache if stale (>1 hour old)
      await service.refreshLiveCacheIfStale();

      // 2. Preload common rates in background (don't block UI)
      // Get all unique currencies from investments
      final investments = await ref.read(allInvestmentsProvider.future);
      final currencies = investments.map((inv) => inv.currency).toSet();

      // Preload rates for all currencies (background)
      unawaited(service.preloadRates(currencies, baseCurrency));

      // BUGFIX (2026-05-01): Only mark as initialized after successful completion
      // Fixes CodeRabbit review comment - allows retry after sign-in
      _initialized = true;

      LoggerService.info(
        'Currency cache initialized',
        metadata: {
          'currencies': currencies.length,
          'baseCurrency': baseCurrency,
        },
      );
    } catch (e) {
      // BUGFIX (2026-05-01): Reset flag on error to allow retry
      _initialized = false;

      LoggerService.error(
        'Error initializing currency cache',
        error: e,
        metadata: {'service': 'CurrencyConversionService'},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
