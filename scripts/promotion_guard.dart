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
// Run by the workflow as `dart run scripts/promotion_guard.dart` with these
// environment variables: ACTION, TO_TRACK, USER_FRACTION, RELEASED_AT
// (ISO 8601, the latest GitHub Release), PROMOTE_RUNS (JSON from
// `gh run list --workflow promote.yml --status success --json
// displayTitle,createdAt,updatedAt`), AUTO_RELEASE_RUNS (JSON from
// `gh run list --workflow auto-release.yml --status success --json
// createdAt,updatedAt`) and CRASH_FREE_USERS (percent). GitHub Actions sets
// GITHUB_REF and GITHUB_RUN_ATTEMPT.
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

/// A successful workflow run: when it was dispatched and when it finished.
class WorkflowRun {
  const WorkflowRun({required this.createdAt, required this.finishedAt});

  final DateTime createdAt;

  /// When the run's last job finished, so any Play call in it is done.
  final DateTime finishedAt;
}

/// Returns why the promotion must not run, or null when it may run.
///
/// [ref] and [runAttempt] are GitHub's `GITHUB_REF` and `GITHUB_RUN_ATTEMPT`.
/// The 48 h count starts at [rolloutSoakStart]. A null history means it could
/// not be read, so going above [stagedRolloutFraction] is refused.
String? promotionBlockReason({
  required String action,
  required String toTrack,
  required String userFraction,
  required String ref,
  required String runAttempt,
  required DateTime? releasedAt,
  required List<DateTime>? partialRolloutStarts,
  required List<WorkflowRun>? autoReleaseRuns,
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
    final reason = _soakBlockReason(
      releasedAt: releasedAt,
      partialRolloutStarts: partialRolloutStarts,
      autoReleaseRuns: autoReleaseRuns,
      now: now,
    );
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
  required DateTime? releasedAt,
  required List<DateTime>? partialRolloutStarts,
  required List<WorkflowRun>? autoReleaseRuns,
  required DateTime now,
}) {
  if (releasedAt == null) {
    return 'Cannot find when the latest release went out, so the 48 h '
        'partial rollout cannot be confirmed.';
  }
  if (partialRolloutStarts == null || autoReleaseRuns == null) {
    return 'Cannot read the promote or auto-release history, so the 48 h '
        'partial rollout cannot be confirmed.';
  }
  final start = rolloutSoakStart(
    releasedAt: releasedAt,
    partialRolloutStarts: partialRolloutStarts,
    autoReleaseRuns: autoReleaseRuns,
  );
  if (start == null) {
    return 'Cannot confirm when the partial production rollout of the latest '
        'release started: no successful auto-release or partial promote run '
        'for it was found. Promote it to production at 0.05 first.';
  }
  final soaked = now.difference(start);
  if (soaked < minimumSoak) {
    final hours = (soaked.inMinutes / 60).toStringAsFixed(1);
    return 'This build has been at a partial production rollout for $hours '
        'h. It needs 48 h before going above 5%.';
  }
  return null;
}

/// When the partial production rollout of the release published at
/// [releasedAt] started, or null when no run shows that it did.
///
/// Counts the finish of each successful run that could have made the Play
/// call for this release: a partial `promote` to production that finished
/// at or after [releasedAt], and an auto-release run that was running when
/// the release was published (it promotes to 5% after creating the release).
/// Returns the latest of them, so a delayed or re-run Play call restarts
/// the count.
DateTime? rolloutSoakStart({
  required DateTime releasedAt,
  required List<DateTime> partialRolloutStarts,
  required List<WorkflowRun> autoReleaseRuns,
}) {
  DateTime? start;
  void consider(DateTime time) {
    if (start == null || time.isAfter(start!)) start = time;
  }

  for (final finished in partialRolloutStarts) {
    if (!finished.isBefore(releasedAt)) consider(finished);
  }
  for (final run in autoReleaseRuns) {
    if (!run.createdAt.isAfter(releasedAt) &&
        !run.finishedAt.isBefore(releasedAt)) {
      consider(run.finishedAt);
    }
  }
  return start;
}

/// Matches promote.yml's `run-name`.
final RegExp _runTitle = RegExp(
  r'^promote action=(\S*) to=(.*) fraction=(.*)$',
);

/// When each successful promote.yml run in [runsJson] that started a partial
/// production rollout (`promote` to production at a fraction below 1)
/// finished.
///
/// [runsJson] is the output of `gh run list --workflow promote.yml --status
/// success --json displayTitle,createdAt,updatedAt`. Runs with other titles
/// are ignored. Returns null when [runsJson] cannot be read, or when a
/// matching run has no finish time.
List<DateTime>? partialRolloutStarts(String runsJson) {
  final decoded = _decodeList(runsJson);
  if (decoded == null) return null;

  final starts = <DateTime>[];
  for (final run in decoded) {
    if (run is! Map) continue;
    final title = run['displayTitle'];
    if (title is! String) continue;
    final match = _runTitle.firstMatch(title.trim());
    if (match == null || match.group(1) != 'promote') continue;
    if (!_isProduction(match.group(2)!)) continue;
    final fraction = _parseFraction(match.group(3)!);
    if (fraction == null || fraction >= 1) continue;
    final finished = _parseTime(run['updatedAt']);
    if (finished == null) return null;
    starts.add(finished);
  }
  return starts;
}

/// The successful auto-release.yml runs in [runsJson], the output of `gh run
/// list --workflow auto-release.yml --status success --json
/// createdAt,updatedAt`. Returns null when it cannot be read or a run has no
/// start or finish time.
List<WorkflowRun>? autoReleaseRuns(String runsJson) {
  final decoded = _decodeList(runsJson);
  if (decoded == null) return null;

  final runs = <WorkflowRun>[];
  for (final run in decoded) {
    if (run is! Map) return null;
    final created = _parseTime(run['createdAt']);
    final finished = _parseTime(run['updatedAt']);
    if (created == null || finished == null) return null;
    runs.add(WorkflowRun(createdAt: created, finishedAt: finished));
  }
  return runs;
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
  final releasedAtText = env['RELEASED_AT']?.trim() ?? '';
  final reason = promotionBlockReason(
    action: env['ACTION'] ?? '',
    toTrack: env['TO_TRACK'] ?? '',
    userFraction: env['USER_FRACTION'] ?? '',
    ref: env['GITHUB_REF'] ?? '',
    runAttempt: env['GITHUB_RUN_ATTEMPT'] ?? '',
    releasedAt: DateTime.tryParse(releasedAtText),
    partialRolloutStarts: partialRolloutStarts(env['PROMOTE_RUNS'] ?? ''),
    autoReleaseRuns: autoReleaseRuns(env['AUTO_RELEASE_RUNS'] ?? ''),
    now: DateTime.now().toUtc(),
    crashFreeUsers: env['CRASH_FREE_USERS'] ?? '',
  );
  if (reason != null) {
    stderr.writeln('::error::$reason');
    exit(1);
  }
  stdout.writeln('Promotion allowed.');
}
