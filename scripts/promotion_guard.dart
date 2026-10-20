// Release safety guard for `.github/workflows/promote.yml` (A63, A63-F1).
//
// A new build reaches production at no more than 5% (the auto-release staged
// fraction). It goes above 5%, up to and including 100%, only after it has
// been at a partial production rollout for at least 48 hours and Crashlytics
// shows at least 99.5% crash-free users. Any other production rollout change
// (for example resuming a halted rollout at 5%) needs the crash-free figure.
// The guard only allows a first attempt of a run dispatched from main, because
// a re-run reuses the inputs and the guard result of the original run. Halting
// is never blocked.
//
// The 48 h count starts at the rollout record that release-platform's promote
// job writes after it read the staged production release back from Play (a
// GitHub deployment in the `play-production` environment). With no record the
// guard refuses to widen. The guard also passes the version codes it counted
// the soak for to the promote job, which checks that Play still holds exactly
// those codes in progress before it changes anything (A84).
//
// Run by the workflow as `dart run scripts/promotion_guard.dart` with these
// environment variables: ACTION, TO_TRACK, USER_FRACTION, ROLLOUT_RECORDS
// (JSON from `gh api repos/$GITHUB_REPOSITORY/deployments?environment=
// play-production&per_page=100`) and CRASH_FREE_USERS (percent). GitHub
// Actions sets GITHUB_REF, GITHUB_RUN_ATTEMPT and GITHUB_OUTPUT.
import 'dart:convert';
import 'dart:io';

/// Minimum time a release must spend at a partial rollout before it goes
/// above [stagedRolloutFraction].
const Duration minimumSoak = Duration(hours: 48);

/// Minimum Crashlytics crash-free users, in percent, to change a production
/// rollout.
const double minimumCrashFreeUsers = 99.5;

/// The largest share of production users a build may reach before its 48 h
/// soak. Matches `rollout_fraction` in `.github/workflows/auto-release.yml`.
const double stagedRolloutFraction = 0.05;

const String _productionTrack = 'production';
const String _mainRef = 'refs/heads/main';

/// A staged production rollout that Play confirmed, as recorded by
/// release-platform's promote job.
class RolloutRecord {
  const RolloutRecord({required this.startedAt, required this.versionCodes});

  /// When the staged production rollout was read back from Play.
  final DateTime startedAt;

  /// The version codes of the in-progress release, sorted.
  final List<String> versionCodes;
}

/// Returns why the promotion must not run, or null when it may run.
///
/// [ref] and [runAttempt] are GitHub's `GITHUB_REF` and `GITHUB_RUN_ATTEMPT`.
/// The 48 h count starts at the latest of [rolloutRecords]. A null history
/// means it could not be read, so going above [stagedRolloutFraction] is
/// refused.
String? promotionBlockReason({
  required String action,
  required String toTrack,
  required String userFraction,
  required String ref,
  required String runAttempt,
  required List<RolloutRecord>? rolloutRecords,
  required DateTime now,
  required String crashFreeUsers,
}) {
  if (action == 'halt') return null;
  if (!const {'promote', 'rollout', 'complete'}.contains(action)) {
    return 'Unknown action "$action".';
  }
  if (ref.trim() != _mainRef) {
    return 'Promote runs only from main (this run is on "$ref"). Dispatch it '
        'from main.';
  }
  if (runAttempt.trim() != '1') {
    return 'This is attempt "$runAttempt" of an earlier run, which reuses its '
        'old inputs and guard result. Dispatch a new promote run instead.';
  }
  if (!_isProduction(toTrack)) return null;

  final fraction = action == 'complete' ? 1.0 : _parseFraction(userFraction);
  if (fraction == null) {
    return 'User fraction "$userFraction" must be a number in (0, 1].';
  }
  final aboveStaged = fraction > stagedRolloutFraction;

  if (action == 'promote') {
    // Promoting to production always starts a staged rollout, so the 48 h
    // count has a real start. A new build may start one without crash data.
    if (aboveStaged) {
      return 'Promote to production must start a staged rollout at 5% or '
          'less (user_fraction 0.05). Go wider later with rollout or '
          'complete, after 48 h.';
    }
    return null;
  }

  if (aboveStaged) {
    final reason = _soakBlockReason(records: rolloutRecords, now: now);
    if (reason != null) return reason;
  }

  final crashFree = double.tryParse(crashFreeUsers.trim());
  if (crashFree == null || !(crashFree >= 0 && crashFree <= 100)) {
    return 'Enter Crashlytics crash-free users for this release as a '
        'percentage (for example 99.7).';
  }
  if (crashFree < minimumCrashFreeUsers) {
    return 'Crash-free users are $crashFree%. Widening the rollout needs at '
        'least $minimumCrashFreeUsers%.';
  }
  return null;
}

String? _soakBlockReason({
  required List<RolloutRecord>? records,
  required DateTime now,
}) {
  if (records == null) {
    return 'Cannot read the rollout records, so the 48 h partial rollout '
        'cannot be confirmed.';
  }
  final latest = latestRolloutRecord(records);
  if (latest == null) {
    return 'Cannot confirm when the partial production rollout started: no '
        'rollout record was found. Promote the release to production at 0.05 '
        'with promote.yml first.';
  }
  final soaked = now.difference(latest.startedAt);
  if (soaked < minimumSoak) {
    final hours = (soaked.inMinutes / 60).toStringAsFixed(1);
    return 'This build has been at a partial production rollout for $hours '
        'h. It needs 48 h before going above 5%.';
  }
  return null;
}

/// The most recently started rollout, or null when there is none.
RolloutRecord? latestRolloutRecord(List<RolloutRecord> records) {
  RolloutRecord? latest;
  for (final record in records) {
    if (latest == null || record.startedAt.isAfter(latest.startedAt)) {
      latest = record;
    }
  }
  return latest;
}

/// Whether the action goes above [stagedRolloutFraction] on production, so it
/// needs the 48 h soak and a confirmation of the soaked release on Play.
bool soakRequired({
  required String action,
  required String toTrack,
  required String userFraction,
}) {
  if (!const {'rollout', 'complete'}.contains(action)) return false;
  if (!_isProduction(toTrack)) return false;
  final fraction = action == 'complete' ? 1.0 : _parseFraction(userFraction);
  return fraction != null && fraction > stagedRolloutFraction;
}

/// The staged production rollouts in [deploymentsJson], the output of the
/// deployments API for the `play-production` environment. Deployments that are
/// not a valid staged production rollout are skipped. Returns null when
/// [deploymentsJson] cannot be read.
List<RolloutRecord>? rolloutRecords(String deploymentsJson) {
  final decoded = _decodeList(deploymentsJson);
  if (decoded == null) return null;

  final records = <RolloutRecord>[];
  for (final deployment in decoded) {
    if (deployment is! Map || deployment['environment'] != 'play-production') {
      continue;
    }
    final payload = deployment['payload'];
    if (payload is! Map) continue;
    final track = payload['track'];
    if (track is! String || !_isProduction(track)) continue;
    if (payload['status'] != 'inProgress') continue;
    final startedAt = _parseTime(payload['startedAt']);
    final codes = payload['versionCodes'];
    if (startedAt == null || codes is! List || codes.isEmpty) continue;
    records.add(
      RolloutRecord(
        startedAt: startedAt,
        versionCodes: [for (final code in codes) '$code']..sort(),
      ),
    );
  }
  return records;
}

List<Object?>? _decodeList(String json) {
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return null;
  }
  return decoded is List ? decoded : null;
}

DateTime? _parseTime(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

bool _isProduction(String track) =>
    track.trim().toLowerCase() == _productionTrack;

/// Empty means 100%, as in the shared promote workflow.
double? _parseFraction(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return 1;
  final value = double.tryParse(text);
  if (value == null || !(value > 0 && value <= 1)) return null;
  return value;
}

void main() {
  final env = Platform.environment;
  final action = env['ACTION'] ?? '';
  final toTrack = env['TO_TRACK'] ?? '';
  final userFraction = env['USER_FRACTION'] ?? '';
  final records = rolloutRecords(env['ROLLOUT_RECORDS'] ?? '');
  final reason = promotionBlockReason(
    action: action,
    toTrack: toTrack,
    userFraction: userFraction,
    ref: env['GITHUB_REF'] ?? '',
    runAttempt: env['GITHUB_RUN_ATTEMPT'] ?? '',
    rolloutRecords: records,
    now: DateTime.now().toUtc(),
    crashFreeUsers: env['CRASH_FREE_USERS'] ?? '',
  );
  if (reason != null) {
    stderr.writeln('::error::$reason');
    exit(1);
  }
  final latest = records == null ? null : latestRolloutRecord(records);
  if (latest != null &&
      soakRequired(
        action: action,
        toTrack: toTrack,
        userFraction: userFraction,
      )) {
    final output = env['GITHUB_OUTPUT'];
    if (output != null && output.isNotEmpty) {
      File(output).writeAsStringSync(
        'soak_version_codes=${latest.versionCodes.join(',')}\n',
        mode: FileMode.append,
      );
    }
    stdout.writeln(
      'Soak counted for version codes ${latest.versionCodes.join(', ')} '
      'from ${latest.startedAt.toIso8601String()}.',
    );
  }
  stdout.writeln('Promotion allowed.');
}
