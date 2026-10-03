import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Writes the user's base currency, once, into records saved before
/// multi-currency support (no `currency` field).
///
/// The repositories label such records with the base currency at read time.
/// Without this stamp, changing the base currency would relabel their amounts
/// (for example an INR 10,00,000 FD shown as USD 10,00,000). The read-time
/// fallback stays for records that arrive later without a currency, such as
/// from an old app version on another device.
///
/// Concurrency and offline behaviour:
///  * The scan reads from the server only. Offline it throws, nothing is
///    recorded as done, and the next start retries.
///  * Each chunk is written in a transaction that re-reads every document
///    and only adds `currency` where it is still missing, so a currency set
///    by another device or an edit in between is never overwritten. A
///    transaction fails instead of queueing while offline, so a stale stamp
///    can never be replayed later on top of a newer value.
class LegacyCurrencyBackfillService {
  LegacyCurrencyBackfillService({
    required FirebaseFirestore firestore,
    required String userId,
    required SharedPreferences prefs,
    int chunkSize = maxWritesPerCommit,
    Duration readTimeout = const Duration(seconds: 20),
  }) : _firestore = firestore,
       _userId = userId,
       _prefs = prefs,
       _chunkSize = chunkSize,
       _readTimeout = readTimeout {
    if (chunkSize < 1 || chunkSize > maxWritesPerCommit) {
      throw ArgumentError.value(chunkSize, 'chunkSize', 'must be 1 to 500');
    }
  }

  final FirebaseFirestore _firestore;
  final String _userId;
  final SharedPreferences _prefs;
  final int _chunkSize;
  final Duration _readTimeout;
  Future<bool>? _running;

  /// Every collection whose mapper falls back to the base currency when a
  /// document has no `currency` (investment, cash-flow, goal and
  /// expected-cash-flow mappers, active and archived).
  static const List<String> collections = [
    'investments',
    'cashflows',
    'archivedInvestments',
    'archivedCashflows',
    'goals',
    'archivedGoals',
    'expectedCashFlows',
  ];

  /// Firestore's limit on writes in one batch or transaction.
  static const int maxWritesPerCommit = 500;

  static const String _field = 'currency';

  String get _doneKey => 'legacy_currency_backfill_done_$_userId';

  /// Whether this user's records were already stamped on this device.
  bool get isComplete => _prefs.getBool(_doneKey) ?? false;

  /// True when [data] has no usable currency: absent, null or blank.
  static bool isMissingCurrency(Map<String, dynamic>? data) {
    final value = data?[_field];
    return value == null || (value is String && value.trim().isEmpty);
  }

  /// Stamps [currency] into every record that has none and returns how many
  /// were written. Throws if any read or write fails; completion is recorded
  /// only after every collection succeeded.
  Future<int> backfill(String currency) async {
    if (currency.trim().isEmpty) {
      throw ArgumentError.value(currency, 'currency', 'must not be empty');
    }
    final userDoc = _firestore.collection('users').doc(_userId);
    var stamped = 0;
    for (final name in collections) {
      final snapshot = await userDoc
          .collection(name)
          .get(const GetOptions(source: Source.server))
          .timeout(_readTimeout);
      final missing = [
        for (final doc in snapshot.docs)
          if (isMissingCurrency(doc.data())) doc.reference,
      ];
      for (var i = 0; i < missing.length; i += _chunkSize) {
        final end = math.min(i + _chunkSize, missing.length);
        stamped += await _stampChunk(missing.sublist(i, end), currency);
      }
    }
    await _prefs.setBool(_doneKey, true);
    // Counts only: never ids, names or amounts (CLAUDE.md rule 7).
    LoggerService.info(
      'Legacy currency backfill finished',
      metadata: {'stamped': stamped},
    );
    return stamped;
  }

  /// Runs [backfill] once per user. Returns false when it failed; the
  /// read-time fallback then stays in place and the next call retries.
  Future<bool> runOnce(String currency) {
    if (isComplete) return Future.value(true);
    return _running ??= _runGuarded(currency).whenComplete(() {
      _running = null;
    });
  }

  Future<bool> _runGuarded(String currency) async {
    try {
      await backfill(currency);
      return true;
    } catch (e) {
      LoggerService.warn(
        'Legacy currency backfill did not finish; will retry',
        metadata: {'errorType': e.runtimeType.toString()},
      );
      return false;
    }
  }

  Future<int> _stampChunk(
    List<DocumentReference<Map<String, dynamic>>> refs,
    String currency,
  ) {
    return _firestore.runTransaction<int>((tx) async {
      final stillMissing = <DocumentReference<Map<String, dynamic>>>[];
      for (final ref in refs) {
        final snap = await tx.get(ref);
        if (snap.exists && isMissingCurrency(snap.data())) {
          stillMissing.add(ref);
        }
      }
      for (final ref in stillMissing) {
        tx.update(ref, {_field: currency});
      }
      return stillMissing.length;
    });
  }
}
