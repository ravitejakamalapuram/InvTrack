import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/settings/data/services/usd_tag_repair_service.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/usd_tag_repair_actions.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Settings > Data & Account item that undoes the US dollar fix while its
/// backup is on this device. Shows nothing otherwise.
class UsdTagRepairUndoTile extends ConsumerStatefulWidget {
  const UsdTagRepairUndoTile({super.key});

  @override
  ConsumerState<UsdTagRepairUndoTile> createState() =>
      _UsdTagRepairUndoTileState();
}

class _UsdTagRepairUndoTileState extends ConsumerState<UsdTagRepairUndoTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(usdTagRepairServiceProvider);
    if (service == null || !service.hasBackup) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final count = service.backedUpInvestmentCount;
    return ListTile(
      leading: const Icon(Icons.undo),
      title: Text(l10n.usdTagRepairUndoTitle),
      subtitle: Text(l10n.usdTagRepairUndoSubtitle(count)),
      enabled: !_busy,
      onTap: () => _confirmUndo(service, count),
    );
  }

  Future<void> _confirmUndo(UsdTagRepairService service, int count) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.usdTagRepairUndoTitle),
        content: Text(l10n.usdTagRepairUndoMessage(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.usdTagRepairUndo),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (ref.read(usdTagRepairServiceProvider)?.userId != service.userId) {
      return;
    }
    setState(() => _busy = true);
    await undoUsdTagRepair(context, service, readUsdTagRepairAnalytics(ref));
    if (mounted) setState(() => _busy = false);
  }
}
