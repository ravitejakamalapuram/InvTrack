import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/core/security/wait_until_unlocked.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Shows a blocking "scheduled for deletion" notice when a signed-in user has
/// a pending `deletionRequests/{uid}` document (for example filed on the web
/// by mistake). The user can withdraw the request or sign out. It waits until
/// the app is unlocked, so it never opens over the lock screen (A113).
class DeletionRequestNotice extends ConsumerStatefulWidget {
  const DeletionRequestNotice({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DeletionRequestNotice> createState() =>
      _DeletionRequestNoticeState();
}

class _DeletionRequestNoticeState extends ConsumerState<DeletionRequestNotice>
    with WaitsForUnlock {
  String? _checkedUserId;
  // Bumped on every sign-in and sign-out, so a check that waited for the
  // unlock across one does not show its question (A113).
  int _session = 0;

  @override
  void initState() {
    super.initState();
    // fireImmediately covers a user who is already signed in at app launch.
    ref.listenManual(authStateProvider, (_, next) {
      final userId = next.value?.id;
      if (userId == null) {
        if (_checkedUserId != null) _session++;
        _checkedUserId = null;
      } else if (userId != _checkedUserId) {
        _checkedUserId = userId;
        _check(++_session);
      }
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) => widget.child;

  Future<void> _check(int session) async {
    final service = ref.read(deletionRequestServiceProvider);
    if (!await service.hasRequest()) return;
    // Whoever holds a locked phone must not withdraw the deletion. The user
    // may also have signed out (or in again) while it waited.
    if (!await waitUntilUnlocked() || session != _session) return;

    final context = rootNavigatorKey.currentContext;
    if (!mounted || context == null || !context.mounted) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);

    final withdraw = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(l10n.deletionScheduledTitle),
          content: Text(l10n.deletionScheduledMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.signOut),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.deletionScheduledWithdraw),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (withdraw == true) {
      final ok = await service.withdraw();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? l10n.deletionRequestWithdrawn
                : l10n.deletionRequestWithdrawFailed,
          ),
        ),
      );
    } else {
      await ref.read(authRepositoryProvider).signOut();
    }
  }
}
