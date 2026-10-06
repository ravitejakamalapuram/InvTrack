import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

/// What a guest backup holds, counted when it was made, so that a later
/// import of it is checked the same way as the merge right after sign-in.
/// Counts and a currency code only: no names or amounts.
class GuestBackupSummary {
  const GuestBackupSummary({
    required this.investments,
    required this.cashFlows,
    required this.goals,
    required this.documents,
    required this.hasFireSettings,
    required this.baseCurrency,
  });

  /// Investments an import of the backup can recreate.
  final int investments;
  final int cashFlows;
  final int goals;
  final int documents;
  final bool hasFireSettings;

  /// The guest's base currency, for backup rows that carry none.
  final String baseCurrency;

  Map<String, Object> toJson() => {
    'investments': investments,
    'cashFlows': cashFlows,
    'goals': goals,
    'documents': documents,
    'hasFireSettings': hasFireSettings,
    'baseCurrency': baseCurrency,
  };

  /// Null if [json] is not a summary this version wrote.
  static GuestBackupSummary? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final investments = json['investments'];
    final cashFlows = json['cashFlows'];
    final goals = json['goals'];
    final documents = json['documents'];
    final hasFireSettings = json['hasFireSettings'];
    final baseCurrency = json['baseCurrency'];
    if (investments is! int ||
        cashFlows is! int ||
        goals is! int ||
        documents is! int ||
        hasFireSettings is! bool ||
        baseCurrency is! String) {
      return null;
    }
    return GuestBackupSummary(
      investments: investments,
      cashFlows: cashFlows,
      goals: goals,
      documents: documents,
      hasFireSettings: hasFireSettings,
      baseCurrency: baseCurrency,
    );
  }
}

/// A guest merge that saved the guest's backup and may have stopped before
/// the backup reached the Google account. [targetId] is the account the
/// merge signed in to, or null if the process stopped before that was
/// recorded.
typedef PendingGuestMerge = ({
  String guestId,
  String backupPath,
  String? targetId,
});

/// Remembers, across process death, the guest merge in progress, what each
/// guest backup holds and which backups were already offered at launch.
///
/// Holds user ids, backup paths, counts and currency codes, never names or
/// amounts. Backups are keyed by file name, which a transfer to another
/// owner keeps.
class GuestMergeJournal {
  GuestMergeJournal(this._prefs);

  final SharedPreferences _prefs;

  static const pendingKey = 'guest_merge_pending';
  static const _summaryPrefix = 'guest_backup_summary.';
  static const _offeredKey = 'guest_backups_offered';

  static String _summaryKey(String backupPath) =>
      '$_summaryPrefix${path.basename(backupPath)}';

  /// Records, before the sign-in, that [guestId] saved [backupPath].
  /// Throws if the device did not save it.
  Future<void> begin({
    required String guestId,
    required String backupPath,
    required GuestBackupSummary summary,
  }) async {
    final saved =
        await _prefs.setString(
          _summaryKey(backupPath),
          jsonEncode(summary.toJson()),
        ) &&
        await _prefs.setString(
          pendingKey,
          jsonEncode({'guestId': guestId, 'path': backupPath}),
        );
    if (!saved) throw StateError('The guest merge could not be recorded');
  }

  /// Records, once the sign-in returned, the account [targetId] that the
  /// pending merge's backup belongs to, so no other account is given it.
  Future<void> setTarget(String targetId) async {
    final raw = _prefs.getString(pendingKey);
    if (raw == null) return;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    await _prefs.setString(
      pendingKey,
      jsonEncode({...json, 'target': targetId}),
    );
  }

  PendingGuestMerge? get pending {
    final raw = _prefs.getString(pendingKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return (
        guestId: json['guestId'] as String,
        backupPath: json['path'] as String,
        targetId: json['target'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearPending() => _prefs.remove(pendingKey);

  /// Null for a backup saved before summaries were kept.
  GuestBackupSummary? summaryOf(String backupPath) {
    final raw = _prefs.getString(_summaryKey(backupPath));
    if (raw == null) return null;
    try {
      return GuestBackupSummary.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  bool wasOffered(String backupPath) =>
      (_prefs.getStringList(_offeredKey) ?? const <String>[]).contains(
        path.basename(backupPath),
      );

  Future<void> markOffered(String backupPath) async {
    final offered = {
      ...?_prefs.getStringList(_offeredKey),
      path.basename(backupPath),
    };
    await _prefs.setStringList(_offeredKey, offered.toList());
  }

  /// Forgets a backup that was deleted.
  Future<void> forget(String backupPath) async {
    await _prefs.remove(_summaryKey(backupPath));
    final offered = _prefs.getStringList(_offeredKey);
    if (offered == null || !offered.remove(path.basename(backupPath))) return;
    if (offered.isEmpty) {
      await _prefs.remove(_offeredKey);
    } else {
      await _prefs.setStringList(_offeredKey, offered);
    }
  }
}
