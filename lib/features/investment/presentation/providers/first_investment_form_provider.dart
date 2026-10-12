import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';

/// Whether the add form is the first investment flow form (A40, #783).
///
/// This is [isFirstInvestmentFlowEnabledProvider], except that a screen which
/// cannot read the flag (its shared preferences are not provided) gets false:
/// it shows today's form instead of failing. The app always provides them, so
/// this changes nothing for a user; it keeps a form that is built in a test or
/// a preview without the whole app from crashing on a flag it does not need.
final firstInvestmentFormEnabledProvider = Provider<bool>((ref) {
  try {
    return ref.watch(isFirstInvestmentFlowEnabledProvider);
  } catch (_) {
    return false;
  }
});
