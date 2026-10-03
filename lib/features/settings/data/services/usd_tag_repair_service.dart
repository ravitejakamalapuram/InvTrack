import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An investment whose cash flows are all stored as US dollars while the
/// user's base currency is not USD. Older versions saved such tags by
/// mistake when merging, importing a CSV or restoring a backup (A03), so its
/// amounts are converted from USD and shown many times too high.
class UsdTagCandidate {
  const UsdTagCandidate({
    required this.investmentId,
    required this.name,
    required this.isMerged,
    required this.isArchived,
    required this.cashFlowCount,
  });

  final String investmentId;
  final String name;

  /// Its notes start with "Merged from:" (made by Merge investments).
  final bool isMerged;
  final bool isArchived;
  final int cashFlowCount;
}

/// Finds investments wrongly stored as US dollars (A04) and, only for the
/// ones the user confirms, relabels them with the base currency. Amounts are
/// never changed.
///
/// Safety:
///  * Reads come from the server only. Offline they throw and nothing is
///    written or recorded.
///  * Before any write, a backup of every document about to change
///    (collection, id, previous and new currency) is saved for this user, so
///    [undo] can put the previous currency back.
///  * Each chunk is written in a transaction that re-reads every document and
///    only changes `currency` where it is still `USD`, so a value changed in
///    between (another device, an edit) is never overwritten. A transaction
///    fails instead of queueing while offline.
class UsdTagRepairService {
  UsdTagRepairService({
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

  /// The signed-in user whose investments this service checks.
  String get userId => _userId;

  /// The currency older versions wrote by default.
  static const String taggedCurrency = 'USD';

  /// Notes prefix written by Merge investments.
  static const String mergedNotesPrefix = 'Merged from:';

  /// Firestore's limit on writes in one batch or transaction.
  static const int maxWritesPerCommit = 500;

  /// Investment collection and its cash-flow collection, active and archived.
  static const List<(String, String)> _collections = [
    ('investments', 'cashflows'),
    ('archivedInvestments', 'archivedCashflows'),
  ];

  static const String _field = 'currency';

  /// Where sample data mode records its investment ids
  /// (SampleDataModeNotifier).
  static const String _sampleInvestmentIdsKey = 'sample_data_investment_ids';

  /// Every SharedPreferences key this service keeps for [userId]. Removed on
  /// account deletion.
  static List<String> prefsKeysFor(String userId) => [
    'usd_tag_repair_resolved_$userId',
    'usd_tag_repair_backup_$userId',
  ];

  String get _resolvedKey => 'usd_tag_repair_resolved_$_userId';
  String get _backupKey => 'usd_tag_repair_backup_$_userId';

  /// Whether this user answered the question (or had nothing to fix).
  bool get isResolved => _prefs.getBool(_resolvedKey) ?? false;

  /// Records the answer (Keep, or nothing found) so the start-up question is
  /// not asked again.
  Future<void> markResolved() => _prefs.setBool(_resolvedKey, true);

  /// Whether a repair can still be undone on this device.
  bool get hasBackup => _backup().isNotEmpty;

  /// How many investments [undo] would put back.
  int get backedUpInvestmentCount =>
      {for (final e in _backup()) e['inv']}.length;

  List<Map<String, dynamic>> _backup() {
    final raw = _prefs.getString(_backupKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveBackup(List<Map<String, dynamic>> entries) async {
    if (entries.isEmpty) {
      await _prefs.remove(_backupKey);
    } else {
      await _prefs.setString(_backupKey, jsonEncode(entries));
    }
  }

  /// Investments that look wrongly stored as US dollars, read from the
  /// server. Writes nothing. Empty when [baseCurrency] is USD. Throws offline.
  Future<List<UsdTagCandidate>> findCandidates(String baseCurrency) async {
    final scan = await _scan(baseCurrency);
    return [for (final s in scan) s.candidate];
  }

  Future<List<_Scanned>> _scan(String baseCurrency) async {
    if (baseCurrency == taggedCurrency) return const [];
    final userDoc = _firestore.collection('users').doc(_userId);
    // Sample data includes a US dollar investment on purpose.
    final sampleIds = {...?_prefs.getStringList(_sampleInvestmentIdsKey)};
    final found = <_Scanned>[];
    for (final (investmentsName, cashFlowsName) in _collections) {
      final investments = await _read(userDoc.collection(investmentsName));
      final cashFlows = await _read(userDoc.collection(cashFlowsName));
      final flowsByInvestment =
          <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
      for (final doc in cashFlows.docs) {
        final investmentId = doc.data()['investmentId'];
        if (investmentId is! String) continue;
        flowsByInvestment.putIfAbsent(investmentId, () => []).add(doc);
      }
      final inCollection = <_Scanned>[];
      for (final inv in investments.docs) {
        if (sampleIds.contains(inv.id)) continue;
        final flows = flowsByInvestment[inv.id] ?? const [];
        if (flows.isEmpty) continue;
        if (!flows.every((f) => _isTagged(f.data()))) continue;
        final data = inv.data();
        final notes = data['notes'];
        inCollection.add(
          _Scanned(
            UsdTagCandidate(
              investmentId: inv.id,
              name: data['name'] as String? ?? '',
              isMerged: notes is String && notes.startsWith(mergedNotesPrefix),
              isArchived: investmentsName != 'investments',
              cashFlowCount: flows.length,
            ),
            [
              if (_isTagged(data)) (investmentsName, inv.reference),
              for (final f in flows) (cashFlowsName, f.reference),
            ],
          ),
        );
      }
      inCollection.sort(
        (a, b) => a.candidate.name.toLowerCase().compareTo(
          b.candidate.name.toLowerCase(),
        ),
      );
      found.addAll(inCollection);
    }
    return found;
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _read(
    CollectionReference<Map<String, dynamic>> collection,
  ) => collection
      .get(const GetOptions(source: Source.server))
      .timeout(_readTimeout);

  static bool _isTagged(Map<String, dynamic>? data) =>
      data?[_field] == taggedCurrency;

  /// Relabels the confirmed [investmentIds] (and their cash flows) from USD
  /// to [baseCurrency], after re-reading them from the server. Investments
  /// that are no longer all USD are skipped, so a second run writes nothing.
  /// Returns how many documents were written and records the answer. Throws
  /// if a read or write fails; documents already written stay in the backup.
  Future<int> repair(Set<String> investmentIds, String baseCurrency) async {
    if (baseCurrency.trim().isEmpty || baseCurrency == taggedCurrency) {
      throw ArgumentError.value(baseCurrency, 'baseCurrency');
    }
    final selected = [
      for (final s in await _scan(baseCurrency))
        if (investmentIds.contains(s.candidate.investmentId)) s,
    ];

    var written = 0;
    for (final chunk in _chunks(selected)) {
      final planned = [
        for (final (investmentId, collection, ref) in chunk)
          {
            'c': collection,
            'id': ref.id,
            'inv': investmentId,
            'from': taggedCurrency,
            'to': baseCurrency,
          },
      ];
      // The backup is on disk before the write it describes.
      // An entry left by an interrupted run for the same document is
      // replaced, not repeated.
      final plannedKeys = {for (final e in planned) '${e['c']}/${e['id']}'};
      final before = [
        for (final e in _backup())
          if (!plannedKeys.contains('${e['c']}/${e['id']}')) e,
      ];
      await _saveBackup([...before, ...planned]);
      final List<DocumentReference<Map<String, dynamic>>> done;
      try {
        done = await _rewrite(
          [for (final (_, _, ref) in chunk) ref],
          from: taggedCurrency,
          to: baseCurrency,
        );
      } catch (_) {
        await _saveBackup(before);
        rethrow;
      }
      // Keep only what was written, so undo never touches a document this
      // repair did not change.
      await _saveBackup([
        ...before,
        for (var i = 0; i < chunk.length; i++)
          if (done.contains(chunk[i].$3)) planned[i],
      ]);
      written += done.length;
    }
    await markResolved();
    // Counts only: never ids, names or amounts (CLAUDE.md rule 7).
    LoggerService.info(
      'USD tag repair finished',
      metadata: {'investments': selected.length, 'documents': written},
    );
    return written;
  }

  /// Groups documents so that one investment's documents share a
  /// transaction; an investment with more documents than [_chunkSize] is
  /// split only because it must be.
  List<List<_Target>> _chunks(List<_Scanned> selected) {
    final chunks = <List<_Target>>[];
    var current = <_Target>[];
    for (final s in selected) {
      final refs = [
        for (final (collection, ref) in s.refs)
          (s.candidate.investmentId, collection, ref),
      ];
      if (current.isNotEmpty && current.length + refs.length > _chunkSize) {
        chunks.add(current);
        current = [];
      }
      for (final entry in refs) {
        if (current.length == _chunkSize) {
          chunks.add(current);
          current = [];
        }
        current.add(entry);
      }
    }
    if (current.isNotEmpty) chunks.add(current);
    return chunks;
  }

  /// Puts US dollars back on every document the last repairs changed, where
  /// the currency is still the one the repair wrote. Returns how many were
  /// restored. The backup is removed only after every chunk succeeded.
  Future<int> undo() async {
    final entries = _backup();
    if (entries.isEmpty) return 0;
    final userDoc = _firestore.collection('users').doc(_userId);
    var restored = 0;
    for (var i = 0; i < entries.length; i += _chunkSize) {
      final chunk = entries.sublist(
        i,
        i + _chunkSize > entries.length ? entries.length : i + _chunkSize,
      );
      restored += await _firestore.runTransaction<int>((tx) async {
        final toRestore = <(DocumentReference<Map<String, dynamic>>, String)>[];
        for (final e in chunk) {
          final ref = userDoc
              .collection(e['c'] as String)
              .doc(e['id'] as String);
          final snap = await tx.get(ref);
          if (snap.exists && snap.data()?[_field] == e['to']) {
            toRestore.add((ref, e['from'] as String));
          }
        }
        for (final (ref, from) in toRestore) {
          tx.update(ref, {_field: from});
        }
        return toRestore.length;
      });
    }
    await _saveBackup(const []);
    LoggerService.info(
      'USD tag repair undone',
      metadata: {'documents': restored},
    );
    return restored;
  }

  /// Changes `currency` from [from] to [to] on each of [refs] still holding
  /// [from], in one transaction. Returns the documents written.
  Future<List<DocumentReference<Map<String, dynamic>>>> _rewrite(
    List<DocumentReference<Map<String, dynamic>>> refs, {
    required String from,
    required String to,
  }) {
    return _firestore.runTransaction((tx) async {
      final still = <DocumentReference<Map<String, dynamic>>>[];
      for (final ref in refs) {
        final snap = await tx.get(ref);
        if (snap.exists && snap.data()?[_field] == from) still.add(ref);
      }
      for (final ref in still) {
        tx.update(ref, {_field: to});
      }
      return still;
    });
  }
}

/// Investment id, collection name and document to rewrite.
typedef _Target = (String, String, DocumentReference<Map<String, dynamic>>);

class _Scanned {
  _Scanned(this.candidate, this.refs);
  final UsdTagCandidate candidate;

  /// Collection name and document of the investment (when it is tagged USD)
  /// and of each of its cash flows.
  final List<(String, DocumentReference<Map<String, dynamic>>)> refs;
}
