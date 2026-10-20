import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/settings/data/services/data_import_service.dart';

/// Investments and goals that a restore or import just wrote and the US
/// dollar check has not looked at yet (A110). Goal ids start with `goal:`, as
/// in [UsdTagRepairService]. `UsdTagRepairInitializer` takes them and asks
/// again if any is wrongly tagged, even when the question was answered
/// before.
final usdTagRepairPendingCheckProvider =
    NotifierProvider<UsdTagRepairPendingCheck, Set<String>>(
      UsdTagRepairPendingCheck.new,
    );

class UsdTagRepairPendingCheck extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// Queues what [result] wrote.
  void reportImport(ZipImportResult result) => report(
    investmentIds: result.importedInvestmentIds,
    goalIds: result.importedGoalIds,
  );

  /// Queues investments (and goals) that an import wrote cash flows for.
  void report({
    Iterable<String> investmentIds = const [],
    Iterable<String> goalIds = const [],
  }) {
    final ids = {...investmentIds, for (final id in goalIds) 'goal:$id'};
    if (ids.isEmpty) return;
    state = {...state, ...ids};
  }

  /// Returns the queued ids and empties the queue.
  Set<String> take() {
    final ids = state;
    if (ids.isNotEmpty) state = const {};
    return ids;
  }
}
