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
///  * Each chunk is written in a transaction that re-reads every document.
///    An investment with any document no longer `USD` (another device, an
///    edit) is skipped as a whole, so a changed value is never overwritten
///    and no investment is left with mixed currencies. A transaction fails
///    instead of queueing while offline.
///  * A transaction's reads run in parallel, [defaultChunkSize] documents at
///    a time, so it takes about one round trip and stays well inside
///    cloud_firestore's 30-second runTransaction timeout on a slow network.
///    Reads that take longer than the read timeout fail the transaction
///    first, so that timeout path, which can still commit, is never
///    reached.
class UsdTagRepairService {
  UsdTagRepairService({
    required FirebaseFirestore firestore,
    required String userId,
    required SharedPreferences prefs,
    int chunkSize = defaultChunkSize,
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

  static const Duration _writeTimeout = Duration(seconds: 5);

  /// The signed-in user whose investments this service checks.
  String get userId => _userId;

  /// The currency older versions wrote by default.
  static const String taggedCurrency = 'USD';

  /// Notes prefix written by Merge investments.
  static const String mergedNotesPrefix = 'Merged from:';

  /// Firestore's limit on writes in one batch or transaction.
  static const int maxWritesPerCommit = 500;

  /// Documents written per transaction. Smaller than [maxWritesPerCommit] so
  /// a transaction's parallel reads finish quickly on a slow network.
  static const int defaultChunkSize = 100;

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

  /// Whether this device has recorded the answer (or that there was nothing
  /// to fix). See [checkResolved] for the account-wide answer.
  bool get isResolved => _prefs.getBool(_resolvedKey) ?? false;

  /// Field on the `users/{uid}` document that records the answer for the
  /// account, so a new install or another phone is not asked again. Removed
  /// with that document on account deletion.
  static const String resolvedField = 'usdTagRepairResolvedAt';

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _firestore.collection('users').doc(_userId);

  /// Whether this user answered on any device (or had nothing to fix). Asks
  /// the server only when this device has no answer, and remembers a server
  /// answer here. Throws when the server cannot be reached.
  Future<bool> checkResolved() async {
    if (isResolved) return true;
    final snapshot = await _userDoc
        .get(const GetOptions(source: Source.server))
        .timeout(_readTimeout);
    if (snapshot.data()?[resolvedField] == null) return false;
    await _prefs.setBool(_resolvedKey, true);
    return true;
  }

  /// Records the answer (Keep, a repair, or nothing found) on this device and
  /// for the account, so the start-up question is not asked again. Offline,
  /// Firestore sends the account record when the connection is back.
  Future<void> markResolved() async {
    await _prefs.setBool(_resolvedKey, true);
    try {
      await _userDoc
          .set({
            resolvedField: FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(_writeTimeout);
    } on TimeoutException {
      // Queued by Firestore; sent when back online.
    } catch (e) {
      LoggerService.warn(
        'USD tag answer not saved for the account',
        metadata: {'errorType': e.runtimeType.toString()},
      );
    }
  }

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
    final userDoc = _userDoc;
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
  /// Returns how many documents and investments this run changed, and
  /// records the answer. Throws if a read or write fails; documents already
  /// written stay in the backup.
  Future<({int documents, int investments})> repair(
    Set<String> investmentIds,
    String baseCurrency,
  ) async {
    if (baseCurrency.trim().isEmpty || baseCurrency == taggedCurrency) {
      throw ArgumentError.value(baseCurrency, 'baseCurrency');
    }
    final selected = [
      for (final s in await _scan(baseCurrency))
        if (investmentIds.contains(s.candidate.investmentId)) s,
    ];

    var written = 0;
    final changedInvestments = <String>{};
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
        done = await _rewrite(chunk, from: taggedCurrency, to: baseCurrency);
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
      changedInvestments.addAll([
        for (final (investmentId, _, ref) in chunk)
          if (done.contains(ref)) investmentId,
      ]);
    }
    await markResolved();
    // Counts only: never ids, names or amounts (CLAUDE.md rule 7).
    LoggerService.info(
      'USD tag repair finished',
      metadata: {
        'investments': changedInvestments.length,
        'documents': written,
      },
    );
    return (documents: written, investments: changedInvestments.length);
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

  /// Where a document moves when its investment is archived or restored.
  /// Archiving keeps document ids.
  static const Map<String, String> _movedTo = {
    'investments': 'archivedInvestments',
    'archivedInvestments': 'investments',
    'cashflows': 'archivedCashflows',
    'archivedCashflows': 'cashflows',
  };

  /// Puts US dollars back on every document the last repairs changed, where
  /// the currency is still the one the repair wrote, including documents
  /// whose investment was archived or restored since. Returns how many were
  /// restored. The backup is removed only after every chunk succeeded.
  Future<int> undo() async {
    final entries = _backup();
    if (entries.isEmpty) return 0;
    final userDoc = _userDoc;
    var restored = 0;
    for (var i = 0; i < entries.length; i += _chunkSize) {
      final chunk = entries.sublist(
        i,
        i + _chunkSize > entries.length ? entries.length : i + _chunkSize,
      );
      restored += await _firestore.runTransaction<int>((tx) async {
        DocumentReference<Map<String, dynamic>> refIn(String name, int at) =>
            userDoc.collection(name).doc(chunk[at]['id'] as String);
        // Where the repair wrote each document, all at once; then, only for
        // documents no longer there, the collection they moved to when
        // their investment or goal was archived or restored.
        final refs = [
          for (var i = 0; i < chunk.length; i++)
            refIn(chunk[i]['c'] as String, i),
        ];
        final snaps = await _readAll(tx, refs);
        final moved = [
          for (var i = 0; i < chunk.length; i++)
            if (!snaps[i].exists && _movedTo[chunk[i]['c']] != null) i,
        ];
        final movedRefs = [
          for (final i in moved) refIn(_movedTo[chunk[i]['c']]!, i),
        ];
        final movedSnaps = await _readAll(tx, movedRefs);
        for (var m = 0; m < moved.length; m++) {
          refs[moved[m]] = movedRefs[m];
          snaps[moved[m]] = movedSnaps[m];
        }
        final toRestore = [
          for (var i = 0; i < chunk.length; i++)
            if (snaps[i].exists && snaps[i].data()?[_field] == chunk[i]['to'])
              (refs[i], chunk[i]['from'] as String),
        ];
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

  /// Changes `currency` from [from] to [to] on each document of [targets],
  /// in one transaction. An investment with any existing document no longer
  /// holding [from] is skipped as a whole, so it never ends up with mixed
  /// currencies. Returns the documents written.
  Future<List<DocumentReference<Map<String, dynamic>>>> _rewrite(
    List<_Target> targets, {
    required String from,
    required String to,
  }) {
    return _firestore.runTransaction((tx) async {
      final snaps = await _readAll(tx, [
        for (final (_, _, ref) in targets) ref,
      ]);
      final still = <_Target>[];
      final changedElsewhere = <String>{};
      for (var i = 0; i < targets.length; i++) {
        final target = targets[i];
        final (investmentId, _, _) = target;
        final snap = snaps[i];
        if (!snap.exists) continue;
        if (snap.data()?[_field] == from) {
          still.add(target);
        } else {
          changedElsewhere.add(investmentId);
        }
      }
      final toWrite = [
        for (final (investmentId, _, ref) in still)
          if (!changedElsewhere.contains(investmentId)) ref,
      ];
      for (final ref in toWrite) {
        tx.update(ref, {_field: to});
      }
      return toWrite;
    });
  }

  /// Reads [refs] in [tx] all at once. One after another, a few hundred
  /// documents ran past the 30-second runTransaction timeout on a slow
  /// network (A81).
  Future<List<DocumentSnapshot<Map<String, dynamic>>>> _readAll(
    Transaction tx,
    List<DocumentReference<Map<String, dynamic>>> refs,
  ) => Future.wait([for (final ref in refs) tx.get(ref)]).timeout(_readTimeout);
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
