import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';

/// For start-up prompts shown on the root navigator. The lock screen is a
/// page under that navigator, so such a dialog would open over it, where
/// whoever holds the phone could answer it without the PIN (A113).
mixin WaitsForUnlock<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final _waiters = <Completer<bool>>{};

  /// Completes with true once the app is not locked, or false if this
  /// widget goes away first. Whatever the prompt depends on (the signed-in
  /// user, the base currency) may have changed while it waited.
  Future<bool> waitUntilUnlocked() async {
    if (!ref.read(securityProvider).isLocked) return true;
    final unlocked = Completer<bool>();
    _waiters.add(unlocked);
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
      _waiters.remove(unlocked);
    }
  }

  @override
  void dispose() {
    for (final unlocked in _waiters) {
      if (!unlocked.isCompleted) unlocked.complete(false);
    }
    super.dispose();
  }
}
