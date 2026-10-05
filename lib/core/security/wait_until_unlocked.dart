import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';

/// For start-up prompts shown on the root navigator. The lock screen is a
/// page under that navigator, so such a dialog would open over it, where
/// whoever holds the phone could answer it without the PIN (A113).
///
/// A dialog still closes, with a null result, when the page under it goes:
/// for example when the app locks while it is open. Treat null as "not
/// answered", never as an answer.
mixin WaitsForUnlock<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final _waiters = <Completer<bool>>{};

  /// Completes with true once the app is unlocked and the lock page is gone,
  /// or false if this widget goes away first. Whatever the prompt depends on
  /// (the signed-in user, the base currency) may have changed while it
  /// waited.
  Future<bool> waitUntilUnlocked() async {
    while (true) {
      if (ref.read(securityProvider).isLocked && !await _nextUnlock()) {
        return false;
      }
      // The router replaces the lock page on the frame after the unlock. A
      // dialog opened before that frame would sit on the lock page and close
      // with it.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return false;
      if (!ref.read(securityProvider).isLocked) return true;
    }
  }

  Future<bool> _nextUnlock() async {
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
