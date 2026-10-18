import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/digest/domain/monthly_digest.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_stats_provider.dart';

/// The recap of a month, built from the one converted snapshot, the active
/// investments and their stats (no new Firestore reads).
final monthlyDigestProvider = Provider.autoDispose
    .family<AsyncValue<MonthlyDigest>, DigestMonth>((ref, month) {
      final flowsAsync = ref.watch(convertedCashFlowsSnapshotProvider);
      final investmentsAsync = ref.watch(activeInvestmentsProvider);
      final statsAsync = ref.watch(activeInvestmentBasicStatsMapProvider);

      for (final async in [flowsAsync, investmentsAsync, statsAsync]) {
        if (async.hasError) {
          return AsyncValue.error(
            async.error!,
            async.stackTrace ?? StackTrace.current,
          );
        }
      }
      if (!flowsAsync.hasValue ||
          !investmentsAsync.hasValue ||
          !statsAsync.hasValue) {
        return const AsyncValue.loading();
      }
      final snapshot = flowsAsync.requireValue;
      return AsyncValue.data(
        MonthlyDigest.build(
          month: month,
          baseCurrency: snapshot.baseCurrency,
          convertedFlows: snapshot.cashFlows,
          activeInvestments: investmentsAsync.requireValue,
          statsById: statsAsync.requireValue,
        ),
      );
    });
