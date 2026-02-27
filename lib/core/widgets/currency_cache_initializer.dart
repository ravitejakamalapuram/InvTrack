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

  const CurrencyCacheInitializer({
    super.key,
    required this.child,
  });

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
    _initialized = true;

    try {
      final service = ref.read(currencyConversionServiceProvider);
      final baseCurrency = ref.read(currencyCodeProvider);

      // 1. Refresh live cache if stale (>1 hour old)
      await service.refreshLiveCacheIfStale();

      // 2. Preload common rates in background (don't block UI)
      // Get all unique currencies from investments
      final investments = await ref.read(investmentsStreamProvider.future);
      final currencies = investments.map((inv) => inv.currency).toSet();

      // Preload rates for all currencies (background)
      unawaited(service.preloadRates(currencies, baseCurrency));

      LoggerService.info(
        'Currency cache initialized',
        metadata: {
          'currencies': currencies.length,
          'baseCurrency': baseCurrency,
        },
      );
    } catch (e) {
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

