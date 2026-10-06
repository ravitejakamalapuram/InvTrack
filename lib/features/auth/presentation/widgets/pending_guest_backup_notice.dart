import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/error/error_handler.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/auth/presentation/providers/guest_backup_merge_provider.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

enum _Answer { keep, share, importNow }

/// When a user signs in, finishes a guest merge that the process stopped
/// part-way ([GuestBackupMergeService.recoverInterruptedMerge]) and offers
/// each kept guest backup once: Import now, Share or Keep (A79).
///
/// A backup is deleted only after an import that added every record. The
/// notice waits until the app is unlocked, because Import now changes the
/// account's data.
class PendingGuestBackupNotice extends ConsumerStatefulWidget {
  const PendingGuestBackupNotice({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PendingGuestBackupNotice> createState() =>
      _PendingGuestBackupNoticeState();
}

class _PendingGuestBackupNoticeState
    extends ConsumerState<PendingGuestBackupNotice> {
  String? _checkedUserId;
  Completer<bool>? _unlocked;

  @override
  void initState() {
    super.initState();
    // fireImmediately covers a user who is already signed in at launch.
    ref.listenManual<AsyncValue<UserEntity?>>(authStateProvider, (_, next) {
      final user = next.value;
      if (user == null) {
        _checkedUserId = null;
      } else if (user.id != _checkedUserId) {
        _checkedUserId = user.id;
        unawaited(_check(user));
      }
    }, fireImmediately: true);
  }

  Future<void> _check(UserEntity user) async {
    final service = ref.read(guestBackupMergeServiceProvider);
    final List<String> backups;
    try {
      backups = await service.recoverInterruptedMerge(user);
    } catch (e) {
      // The type only: file errors carry the backup's path.
      LoggerService.warn(
        'Guest backup check at launch did not finish',
        metadata: {'errorType': e.runtimeType.toString()},
      );
      return;
    }
    for (final backupPath in backups) {
      if (!await _waitUntilUnlocked() || !_stillCurrent(user)) return;
      final context = rootNavigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      final answer = await _ask(context);
      // Closed without an answer (the app went away): asked again next time.
      if (answer == null || !_stillCurrent(user)) return;
      switch (answer) {
        case _Answer.keep:
          break;
        case _Answer.share:
          // A failed share is offered again next time.
          if (!await _share(service, backupPath)) continue;
        case _Answer.importNow:
          final result = await _import(service, backupPath);
          // Deleted after a complete import; a failed one is offered again.
          if (result == null || result == GuestBackupImport.complete) {
            continue;
          }
      }
      await service.markOffered(backupPath);
    }
  }

  Future<_Answer?> _ask(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showDialog<_Answer>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.guestBackupNoticeTitle),
        content: Text(l10n.guestBackupNoticeMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, _Answer.keep),
            child: Text(l10n.keep),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, _Answer.share),
            child: Text(l10n.share),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, _Answer.importNow),
            child: Text(l10n.guestBackupImportNow),
          ),
        ],
      ),
    );
  }

  /// False if the share sheet could not be opened.
  Future<bool> _share(GuestBackupMergeService service, String path) async {
    try {
      await service.shareBackup(path);
      return true;
    } catch (e, st) {
      final context = rootNavigatorKey.currentContext;
      ErrorHandler.handle(
        e,
        st,
        context: context != null && context.mounted ? context : null,
        showFeedback: true,
      );
      return false;
    }
  }

  /// Null if the import failed.
  Future<GuestBackupImport?> _import(
    GuestBackupMergeService service,
    String path,
  ) async {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null || !navigator.mounted) return null;
    final l10n = AppLocalizations.of(navigator.context);
    final messenger = ScaffoldMessenger.maybeOf(navigator.context);
    final loading = DialogRoute<void>(
      context: navigator.context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    unawaited(navigator.push(loading));
    final GuestBackupImport result;
    try {
      result = await service.importSavedBackup(path);
    } catch (e, st) {
      if (loading.isActive) navigator.removeRoute(loading);
      ErrorHandler.handle(
        e,
        st,
        context: navigator.mounted ? navigator.context : null,
        showFeedback: true,
      );
      return null;
    }
    if (loading.isActive) navigator.removeRoute(loading);
    if (!navigator.mounted) return result;

    switch (result) {
      case GuestBackupImport.complete:
        messenger?.showSnackBar(
          SnackBar(
            content: Text(l10n.guestDataMerged),
            backgroundColor: AppColors.successLight,
          ),
        );
      case GuestBackupImport.incomplete:
        await _tell(navigator, l10n.guestBackupImportIncomplete, l10n);
      case GuestBackupImport.unchecked:
        await _tell(navigator, l10n.guestBackupImportUnchecked, l10n);
    }
    return result;
  }

  Future<void> _tell(
    NavigatorState navigator,
    String message,
    AppLocalizations l10n,
  ) {
    return showDialog<void>(
      context: navigator.context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  /// Completes with true once the app is not locked, or false if this
  /// widget goes away first.
  Future<bool> _waitUntilUnlocked() async {
    if (!ref.read(securityProvider).isLocked) return true;
    final unlocked = _unlocked = Completer<bool>();
    final sub = ref.listenManual<bool>(
      securityProvider.select((s) => s.isLocked),
      (_, isLocked) {
        if (!isLocked && !unlocked.isCompleted) unlocked.complete(true);
      },
    );
    try {
      return await unlocked.future;
    } finally {
      // After dispose the subscription is already closed with the widget.
      if (mounted) sub.close();
      if (identical(_unlocked, unlocked)) _unlocked = null;
    }
  }

  bool _stillCurrent(UserEntity user) =>
      mounted && ref.read(authStateProvider).value?.id == user.id;

  @override
  void dispose() {
    final unlocked = _unlocked;
    if (unlocked != null && !unlocked.isCompleted) unlocked.complete(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
