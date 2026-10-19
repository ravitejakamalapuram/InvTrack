import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/notifications/notification_constants.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';
import 'package:inv_tracker/features/security/data/services/security_service.dart';
import 'package:inv_tracker/features/settings/data/services/account_data_deletion_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Removes what the signed-out user left on this device: the Firestore
/// offline cache, their attachments, the app-lock PIN and their per-user
/// preferences. The server copy is untouched.
///
/// Every step runs even if another fails, so one broken step cannot leave
/// the rest behind. Failures are logged without ids or paths.
class SignOutCleanupService {
  SignOutCleanupService({
    required FirebaseFirestore firestore,
    required SecurityService security,
    required SharedPreferences prefs,
    Future<void> Function(String userId)? deleteDocuments,
    this.syncTimeout = const Duration(seconds: 5),
  }) : _firestore = firestore,
       _security = security,
       _prefs = prefs,
       _deleteDocuments =
           deleteDocuments ??
           ((uid) =>
               DocumentStorageService(userId: uid).deleteAllUserDocuments());

  final FirebaseFirestore _firestore;
  final SecurityService _security;
  final SharedPreferences _prefs;
  final Future<void> Function(String userId) _deleteDocuments;

  /// How long to wait for offline edits to reach the server.
  final Duration syncTimeout;

  /// Prefixes of per-user keys written by NotificationPrefsKeys.
  static const List<String> _keyPrefixes = [
    'milestone_shown_',
    'goal_milestone_shown_',
    'income_reminder_due_',
    'income_reminder_shown_',
    'idle_alert_last_shown_',
    'goal_at_risk_last_shown_',
    'goal_stale_last_shown_',
  ];

  static const List<String> _fixedKeys = [
    NotificationPrefsKeys.remindersOwnerUid,
    NotificationPrefsKeys.userSignupDate,
    NotificationPrefsKeys.activationDay0Sent,
    NotificationPrefsKeys.activationDay1Sent,
    NotificationPrefsKeys.activationDay3Sent,
    NotificationPrefsKeys.activationDay7Sent,
    NotificationPrefsKeys.activationDay14Sent,
  ];

  /// True when edits made on this device have not reached the server
  /// within [syncTimeout]. Clearing the cache would then lose them.
  Future<bool> hasUnsyncedWrites() async {
    try {
      await _firestore.waitForPendingWrites().timeout(syncTimeout);
      return false;
    } on TimeoutException {
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<void> wipe(String userId) async {
    await _step('pin', _security.removePin);
    await _step('documents', () => _deleteDocuments(userId));
    await _step('prefs', () async {
      await AccountDataDeletionService(
        firestore: _firestore,
        userId: userId,
      ).deleteLocalData(deleteLocalFiles: () async {}, prefs: _prefs);
      for (final key in _prefs.getKeys().toList()) {
        if (_fixedKeys.contains(key) ||
            _keyPrefixes.any((p) => key.startsWith(p))) {
          await _prefs.remove(key);
        }
      }
    });
    // terminate() must come first; clearPersistence() is only allowed on a
    // terminated instance.
    await _step('firestoreCache', () async {
      await _firestore.terminate();
      await _firestore.clearPersistence();
    });
  }

  Future<void> _step(String name, Future<void> Function() run) async {
    try {
      await run();
    } catch (e) {
      LoggerService.warn(
        'Sign-out cleanup step failed',
        metadata: {'operation': name, 'errorType': e.runtimeType.toString()},
      );
    }
  }
}
