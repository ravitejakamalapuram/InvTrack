import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What an older version tagged US dollars by mistake.
enum UsdTagKind {
  /// An investment whose cash flows are all in US dollars.
  allUsd,

  /// An investment in US dollars with no cash flows yet: its next cash flow
  /// would be in US dollars too.
  noCashFlows,

  /// An investment with some documents (cash flows, the investment itself
  /// or its expected payments) in US dollars and the rest in the base
  /// currency.
  partlyUsd,

  /// A goal in US dollars.
  goal,
}

/// An investment or goal stored as US dollars while the user's base currency
/// is not USD. Older versions saved such tags by mistake when merging,
/// importing a CSV or restoring a backup (A03), so its amounts are converted
/// from USD and shown many times too high.
class UsdTagCandidate {
  const UsdTagCandidate({
    required this.id,
    required this.name,
    required this.isMerged,
    required this.isArchived,
    required this.cashFlowCount,
    this.kind = UsdTagKind.allUsd,
    int? usdCashFlowCount,
    this.expectedPaymentCount = 0,
  }) : usdCashFlowCount = usdCashFlowCount ?? cashFlowCount;

  /// What [UsdTagRepairService.repair] takes. The investment id for
  /// [UsdTagKind.allUsd] (as in A04); otherwise the kind's prefix and the
  /// investment or goal id, so an item that changed kind since the question
  /// was asked is not changed.
  final String id;
  final String name;

  /// Its notes start with "Merged from:" (made by Merge investments).
  final bool isMerged;
  final bool isArchived;
  final UsdTagKind kind;

  /// All of the investment's cash flows; 0 for a goal.
  final int cashFlowCount;

  /// The cash flows that would change.
  final int usdCashFlowCount;

  /// The investment's expected payments that would change.
  final int expectedPaymentCount;

  /// Only merged investments start ticked: older merges always wrote US
  /// dollars. Anything else may really be in US dollars, so the user ticks
  /// it.
  bool get tickedByDefault => kind == UsdTagKind.allUsd && isMerged;
}

/// Finds investments (A04), their expected payments and goals (A109)
/// wrongly stored as US dollars and, only for the ones the user confirms,
/// relabels them with the base currency. Only documents in US dollars
/// change, and amounts never do.
///
/// Safety:
///  * Reads come from the server only. Offline they throw and nothing is
///    written or recorded.
///  * Before any write, a backup of every document about to change
///    (collection, id, previous and new currency) is saved for this user, so
///    [undo] can put the previous currency back.
///  * The repair scans again and changes only items of the kind the user
///    saw: an investment that became partly US dollars since the question,
///    for example, is left alone.
///  * Each chunk is written in a transaction that re-reads every document.
///    An investment or goal with any document no longer `USD` (another
///    device, an edit) is skipped as a whole, so a changed value is never
///    overwritten. A transaction fails instead of queueing while offline.
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

  /// Goal collections, active and archived.
  static const List<String> _goalCollections = ['goals', 'archivedGoals'];

  /// Expected payments of active and archived investments.
  static const String _expectedCashFlows = 'expectedCashFlows';

  /// Prefixes of [UsdTagCandidate.id] for the kinds A04 did not flag.
  static const String _goalPrefix = 'goal:';
  static const String _noCashFlowsPrefix = 'empty:';
  static const String _partlyUsdPrefix = 'partly:';

  static const String _field = 'currency';

  /// Where sample data mode records its investment ids
  /// (SampleDataModeNotifier).
  static const String _sampleInvestmentIdsKey = 'sample_data_investment_ids';

  /// Every SharedPreferences key this service keeps for [userId]. Removed on
  /// account deletion.
  static List<String> prefsKeysFor(String userId) => [
    'usd_tag_repair_resolved_$userId',
    'usd_tag_repair_backup_$userId',
    'usd_tag_repair_extended_resolved_$userId',
  ];

  String get _resolvedKey => 'usd_tag_repair_resolved_$_userId';
  String get _backupKey => 'usd_tag_repair_backup_$_userId';
  String get _extendedResolvedKey =>
      'usd_tag_repair_extended_resolved_$_userId';

  /// Whether this device has recorded the answer to the current question
  /// (or that there was nothing to fix). See [checkResolved] for the
  /// account-wide answer.
  bool get isResolved => _prefs.getBool(_extendedResolvedKey) ?? false;

  /// Whether this user answered the A04 question, which listed only
  /// investments all in US dollars, on this device or (after
  /// [checkResolved]) on another one. Those investments are then not listed
  /// again.
  bool get answeredAllUsd => _prefs.getBool(_resolvedKey) ?? false;

  /// Field on the `users/{uid}` document that records the A04 answer for
  /// the account. Removed with that document on account deletion.
  static const String resolvedField = 'usdTagRepairResolvedAt';

  /// Field on the `users/{uid}` document that records the answer to the
  /// current question (A109: goals, expected payments, empty and partly US
  /// dollar investments too), so a new install or another phone is not
  /// asked again. Removed with that document on account deletion.
  static const String extendedResolvedField = 'usdTagRepairExtendedResolvedAt';

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
    final data = snapshot.data();
    if (data?[resolvedField] != null) {
      await _prefs.setBool(_resolvedKey, true);
    }
    if (data?[extendedResolvedField] == null) return false;
    await _prefs.setBool(_resolvedKey, true);
    await _prefs.setBool(_extendedResolvedKey, true);
    return true;
  }

  /// Records the answer (Keep, a repair, or nothing found) on this device and
  /// for the account, so the start-up question is not asked again. Offline,
  /// Firestore sends the account record when the connection is back.
  Future<void> markResolved() async {
    await _prefs.setBool(_resolvedKey, true);
    await _prefs.setBool(_extendedResolvedKey, true);
    try {
      await _userDoc
          .set({
            resolvedField: FieldValue.serverTimestamp(),
            extendedResolvedField: FieldValue.serverTimestamp(),
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
      _backedUpOwners().where((o) => !o.startsWith(_goalPrefix)).length;

  /// How many goals [undo] would put back.
  int get backedUpGoalCount =>
      _backedUpOwners().where((o) => o.startsWith(_goalPrefix)).length;

  /// The investment id, or `goal:` and the goal id, of each backed-up
  /// document.
  Set<String> _backedUpOwners() => {
    for (final e in _backup())
      if (e['inv'] case final String owner) owner,
  };

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

  /// Investments and goals that look wrongly stored as US dollars, read
  /// from the server. Writes nothing. Empty when [baseCurrency] is USD.
  /// Throws offline. After the A04 answer ([answeredAllUsd]), investments
  /// all in US dollars were already asked about and are left out.
  Future<List<UsdTagCandidate>> findCandidates(String baseCurrency) async {
    final scan = await _scan(baseCurrency);
    final skipAllUsd = answeredAllUsd;
    return [
      for (final s in scan)
        if (!skipAllUsd || s.candidate.kind != UsdTagKind.allUsd) s.candidate,
    ];
  }

  Future<List<_Scanned>> _scan(String baseCurrency) async {
    if (baseCurrency == taggedCurrency) return const [];
    final userDoc = _userDoc;
    // Sample data includes a US dollar investment on purpose.
    final sampleIds = {...?_prefs.getStringList(_sampleInvestmentIdsKey)};
    final paymentsByInvestment = _byInvestment(
      await _read(userDoc.collection(_expectedCashFlows)),
    );
    final found = <_Scanned>[];
    for (final (investmentsName, cashFlowsName) in _collections) {
      final investments = await _read(userDoc.collection(investmentsName));
      final flowsByInvestment = _byInvestment(
        await _read(userDoc.collection(cashFlowsName)),
      );
      final inCollection = <_Scanned>[];
      for (final inv in investments.docs) {
        if (sampleIds.contains(inv.id)) continue;
        final data = inv.data();
        final flows = flowsByInvestment[inv.id] ?? const [];
        final payments = paymentsByInvestment[inv.id] ?? const [];
        final usdFlows = [
          for (final f in flows)
            if (_isTagged(f.data())) f,
        ];
        final usdPayments = [
          for (final p in payments)
            if (_isTagged(p.data())) p,
        ];
        final UsdTagKind kind;
        if (flows.isNotEmpty && usdFlows.length == flows.length) {
          kind = UsdTagKind.allUsd;
        } else if (!_isTagged(data) &&
            usdFlows.isEmpty &&
            usdPayments.isEmpty) {
          continue;
        } else if (![
          data,
          for (final f in flows) f.data(),
          for (final p in payments) p.data(),
        ].every((d) => _isTagged(d) || _isIn(d, baseCurrency))) {
          // Also in a third currency: really multi-currency, not a mistake.
          continue;
        } else if (flows.isEmpty && _isTagged(data)) {
          kind = UsdTagKind.noCashFlows;
        } else {
          kind = UsdTagKind.partlyUsd;
        }
        final notes = data['notes'];
        inCollection.add(
          _Scanned(
            UsdTagCandidate(
              id: switch (kind) {
                UsdTagKind.noCashFlows => '$_noCashFlowsPrefix${inv.id}',
                UsdTagKind.partlyUsd => '$_partlyUsdPrefix${inv.id}',
                _ => inv.id,
              },
              name: data['name'] as String? ?? '',
              isMerged: notes is String && notes.startsWith(mergedNotesPrefix),
              isArchived: investmentsName != 'investments',
              kind: kind,
              cashFlowCount: flows.length,
              usdCashFlowCount: usdFlows.length,
              expectedPaymentCount: usdPayments.length,
            ),
            inv.id,
            [
              if (_isTagged(data)) (investmentsName, inv.reference),
              for (final f in usdFlows) (cashFlowsName, f.reference),
              for (final p in usdPayments) (_expectedCashFlows, p.reference),
            ],
          ),
        );
      }
      found.addAll(_byName(inCollection));
    }
    for (final goalsName in _goalCollections) {
      final goals = await _read(userDoc.collection(goalsName));
      found.addAll(
        _byName([
          for (final goal in goals.docs)
            if (_isTagged(goal.data()))
              _Scanned(
                UsdTagCandidate(
                  id: '$_goalPrefix${goal.id}',
                  name: goal.data()['name'] as String? ?? '',
                  isMerged: false,
                  isArchived: goalsName != 'goals',
                  kind: UsdTagKind.goal,
                  cashFlowCount: 0,
                ),
                '$_goalPrefix${goal.id}',
                [(goalsName, goal.reference)],
              ),
        ]),
      );
    }
    return found;
  }

  static Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _byInvestment(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final byInvestment =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final doc in snapshot.docs) {
      final investmentId = doc.data()['investmentId'];
      if (investmentId is! String) continue;
      byInvestment.putIfAbsent(investmentId, () => []).add(doc);
    }
    return byInvestment;
  }

  static List<_Scanned> _byName(List<_Scanned> scanned) => scanned
    ..sort(
      (a, b) => a.candidate.name.toLowerCase().compareTo(
        b.candidate.name.toLowerCase(),
      ),
    );

  Future<QuerySnapshot<Map<String, dynamic>>> _read(
    CollectionReference<Map<String, dynamic>> collection,
  ) => collection
      .get(const GetOptions(source: Source.server))
      .timeout(_readTimeout);

  static bool _isTagged(Map<String, dynamic>? data) =>
      data?[_field] == taggedCurrency;

  /// In [currency], or with no currency (read as the base currency).
  static bool _isIn(Map<String, dynamic>? data, String currency) {
    final value = data?[_field];
    return value == currency ||
        value == null ||
        value is String && value.trim().isEmpty;
  }

  /// Relabels the documents in US dollars of the confirmed candidates
  /// ([UsdTagCandidate.id]) with [baseCurrency], after re-reading them from
  /// the server. Candidates that are no longer of the kind the user saw, or
  /// no longer in US dollars, are skipped, so a second run writes nothing.
  /// Returns how many documents, investments and goals this run changed,
  /// and records the answer. Throws if a read or write fails; documents
  /// already written stay in the backup.
  Future<({int documents, int investments, int goals})> repair(
    Set<String> ids,
    String baseCurrency,
  ) async {
    if (baseCurrency.trim().isEmpty || baseCurrency == taggedCurrency) {
      throw ArgumentError.value(baseCurrency, 'baseCurrency');
    }
    final selected = [
      for (final s in await _scan(baseCurrency))
        if (ids.contains(s.candidate.id)) s,
    ];

    var written = 0;
    final changed = <String>{};
    for (final chunk in _chunks(selected)) {
      final planned = [
        for (final (owner, collection, ref) in chunk)
          {
            'c': collection,
            'id': ref.id,
            'inv': owner,
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
      changed.addAll([
        for (final (owner, _, ref) in chunk)
          if (done.contains(ref)) owner,
      ]);
    }
    await markResolved();
    final goals = changed.where((o) => o.startsWith(_goalPrefix)).length;
    final investments = changed.length - goals;
    // Counts only: never ids, names or amounts (CLAUDE.md rule 7).
    LoggerService.info(
      'USD tag repair finished',
      metadata: {
        'investments': investments,
        'goals': goals,
        'documents': written,
      },
    );
    return (documents: written, investments: investments, goals: goals);
  }

  /// Groups documents so that one investment's (or goal's) documents share
  /// a transaction; one with more documents than [_chunkSize] is split only
  /// because it must be.
  List<List<_Target>> _chunks(List<_Scanned> selected) {
    final chunks = <List<_Target>>[];
    var current = <_Target>[];
    for (final s in selected) {
      final refs = [
        for (final (collection, ref) in s.refs) (s.owner, collection, ref),
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

  /// Where a document moves when its investment or goal is archived or
  /// restored. Archiving keeps document ids.
  static const Map<String, String> _movedTo = {
    'investments': 'archivedInvestments',
    'archivedInvestments': 'investments',
    'cashflows': 'archivedCashflows',
    'archivedCashflows': 'cashflows',
    'goals': 'archivedGoals',
    'archivedGoals': 'goals',
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
  /// in one transaction. An investment or goal with any existing document no
  /// longer holding [from] is skipped as a whole, so a value changed
  /// elsewhere is never overwritten. Returns the documents written.
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

/// Owner (see [_Scanned.owner]), collection name and document to rewrite.
typedef _Target = (String, String, DocumentReference<Map<String, dynamic>>);

class _Scanned {
  _Scanned(this.candidate, this.owner, this.refs);
  final UsdTagCandidate candidate;

  /// The investment id, or `goal:` and the goal id, recorded with each
  /// document in the backup.
  final String owner;

  /// Collection name and document of everything in US dollars that the
  /// repair changes: the investment, its cash flows and expected payments,
  /// or the goal.
  final List<(String, DocumentReference<Map<String, dynamic>>)> refs;
}
