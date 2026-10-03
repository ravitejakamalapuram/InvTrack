import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/settings/data/services/legacy_currency_backfill_service.dart';

/// Stamps records saved without a currency with the base currency, once per
/// signed-in user (guests included), as soon as that user is known (A03-F1).
///
/// The base currency comes from the device settings, which are loaded before
/// the first frame, so it is the currency the app shows today. A failure (for
/// example offline) is retried on the next start; until then the
/// repositories keep their read-time fallback.
class LegacyCurrencyBackfillInitializer extends ConsumerStatefulWidget {
  const LegacyCurrencyBackfillInitializer({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LegacyCurrencyBackfillInitializer> createState() =>
      _LegacyCurrencyBackfillInitializerState();
}

class _LegacyCurrencyBackfillInitializerState
    extends ConsumerState<LegacyCurrencyBackfillInitializer> {
  @override
  void initState() {
    super.initState();
    ref.listenManual<LegacyCurrencyBackfillService?>(
      legacyCurrencyBackfillServiceProvider,
      (_, service) {
        if (service == null) return;
        unawaited(service.runOnce(ref.read(currencyCodeProvider)));
      },
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
