/// Derived providers for dated valuation snapshots. The snapshots stream
/// ([allValuationSnapshotsProvider]) is in investment_providers.dart with the
/// other base streams.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/calculations/valuation_snapshot_selector.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/utils/async_value_utils.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';

export 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart'
    show allValuationSnapshotsProvider, valuationSnapshotsActiveProvider;

/// Live snapshots of ACTIVE investments only, in the style of
/// [validCashFlowsProvider]: archived investments keep their snapshots but
/// are never valued (money rule 9), and snapshots left behind by a deleted
/// investment are never used.
final validValuationSnapshotsProvider =
    Provider<AsyncValue<List<InvestmentValuationSnapshot>>>((ref) {
      final investmentsAsync = errorFirst(ref.watch(activeInvestmentsProvider));
      final snapshotsAsync = errorFirst(
        ref.watch(allValuationSnapshotsProvider),
      );

      return investmentsAsync.when(
        data: (investments) => snapshotsAsync.when(
          data: (snapshots) {
            final activeIds = <String>{
              for (final investment in investments) investment.id,
            };
            return AsyncValue.data([
              for (final snapshot in snapshots)
                if (snapshot.isLive &&
                    activeIds.contains(snapshot.investmentId))
                  snapshot,
            ]);
          },
          loading: () => const AsyncValue.loading(),
          error: (e, st) => AsyncValue.error(e, st),
        ),
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    });

/// The valid snapshots by investment id, ready for the calculators. With the
/// feature off it is an empty map at once, never loading, so every consumer
/// behaves as it did before snapshots existed.
final valuationSnapshotsByInvestmentProvider =
    Provider<AsyncValue<Map<String, List<InvestmentValuationSnapshot>>>>((ref) {
      if (!ref.watch(valuationSnapshotsActiveProvider)) {
        return const AsyncValue.data({});
      }
      return ref.watch(validValuationSnapshotsProvider).whenData((snapshots) {
        final byInvestment = <String, List<InvestmentValuationSnapshot>>{};
        for (final snapshot in snapshots) {
          byInvestment
              .putIfAbsent(snapshot.investmentId, () => [])
              .add(snapshot);
        }
        for (final list in byInvestment.values) {
          list.sort((a, b) => ValuationSnapshotSelector.compare(b, a));
        }
        return byInvestment;
      });
    });

/// The live snapshots of one investment, newest first; empty when it has
/// none or the feature is off.
final investmentValuationSnapshotsProvider =
    Provider.family<List<InvestmentValuationSnapshot>, String>((
      ref,
      investmentId,
    ) {
      return ref.watch(
            valuationSnapshotsByInvestmentProvider.select(
              (async) => async.value?[investmentId],
            ),
          ) ??
          const [];
    });

/// The id of the signed-in user. The valuation notifier starts clean when it
/// changes, so one account's Undo or pending notices never reach another's.
final valuationAccountIdProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider.select((user) => user.value?.id)),
);

/// Every snapshot as the server has it: no state from the cache and none with
/// a write of this device still pending. Opened only while the feature is on
/// and a user is signed in.
final valuationServerSnapshotsProvider =
    StreamProvider<List<InvestmentValuationSnapshot>>((ref) {
      if (!ref.watch(valuationSnapshotsActiveProvider)) {
        return Stream.value(const []);
      }
      if (!ref.watch(isAuthenticatedProvider)) return Stream.value(const []);
      return ref.watch(valuationRepositoryProvider).watchServerConfirmed();
    });

/// The ids of snapshots this device edited that another device's write has
/// since replaced on the server (the last write to reach the server wins, so
/// an edit made offline on Monday can overwrite one made online on
/// Wednesday). The screens tell the user once, so that no edit is lost
/// silently, then call [ValuationConflicts.dismiss].
///
/// It compares the server-confirmed snapshots (no cache, no pending write
/// of this device) with what this device last wrote. What it knows is lost
/// with the process; that is accepted.
final valuationConflictsProvider =
    NotifierProvider<ValuationConflicts, Set<String>>(ValuationConflicts.new);

class ValuationConflicts extends Notifier<Set<String>> {
  final Map<String, InvestmentValuationSnapshot> _lastWritten = {};

  @override
  Set<String> build() {
    // Another account starts clean.
    ref.watch(valuationAccountIdProvider);
    _lastWritten.clear();
    ref.listen(valuationServerSnapshotsProvider, (_, next) {
      final server = next.value;
      if (server != null) _compare(server);
    });
    return const {};
  }

  /// Remembers what this device wrote for [snapshot].
  void recordWrite(InvestmentValuationSnapshot snapshot) {
    _lastWritten[snapshot.id] = snapshot;
  }

  void dismiss() => state = const {};

  void _compare(List<InvestmentValuationSnapshot> server) {
    final overwritten = <String>{};
    for (final s in server) {
      final written = _lastWritten[s.id];
      if (written == null) continue;
      final same =
          written.amount == s.amount &&
          _day(written.effectiveDate) == _day(s.effectiveDate) &&
          written.kind == s.kind &&
          written.provenance == s.provenance &&
          (written.deletedAt == null) == (s.deletedAt == null);
      if (!same) {
        overwritten.add(s.id);
        // The server value is the one to compare with from now on.
        _lastWritten.remove(s.id);
      }
    }
    if (overwritten.isNotEmpty) state = {...state, ...overwritten};
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
}
