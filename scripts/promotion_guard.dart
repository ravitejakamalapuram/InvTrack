// Release safety guard for `.github/workflows/promote.yml` (A63).
//
// No build reaches 100% of production until it has been out for at least
// 48 hours at a partial rollout and Crashlytics shows at least 99.5%
// crash-free users. Promoting a build to production always starts a partial
// rollout; only `rollout` to 1 or `complete` can then take it to 100%.
// Widening a partial production rollout (for example 5% -> 20%) needs the
// crash-free figure too. Halting is never blocked.
//
// Run by the workflow as `dart run scripts/promotion_guard.dart` with these
// environment variables: ACTION, TO_TRACK, USER_FRACTION, RELEASED_AT
// (ISO 8601, the latest GitHub Release), PROMOTE_RUNS (JSON from
// `gh run list --workflow promote.yml --status success --json
// displayTitle,createdAt`) and CRASH_FREE_USERS (percent).
import 'dart:convert';
import 'dart:io';

/// Minimum time a release must spend at a partial rollout before 100%.
const Duration minimumSoak = Duration(hours: 48);

/// Minimum Crashlytics crash-free users, in percent, to widen a rollout.
const double minimumCrashFreeUsers = 99.5;

const String _productionTrack = 'production';

/// Returns why the promotion must not run, or null when it may run.
///
/// The 48 h count starts at the later of [releasedAt] and the newest of
/// [partialRolloutStarts] (see [partialRolloutStarts]). A null
/// [partialRolloutStarts] means the promote history could not be read, so
/// reaching 100% is refused.
String? promotionBlockReason({
  required String action,
  required String toTrack,
  required String userFraction,
  required DateTime? releasedAt,
  required List<DateTime>? partialRolloutStarts,
  required DateTime now,
  required String crashFreeUsers,
}) {
  if (action == 'halt') return null;
  if (!const {'promote', 'rollout', 'complete'}.contains(action)) {
    return 'Unknown action "$action".';
  }
  if (!_isProduction(toTrack)) return null;

  final fraction = action == 'complete' ? 1.0 : _parseFraction(userFraction);
  if (fraction == null) {
    return 'User fraction "$userFraction" must be a number in (0, 1].';
  }
  final reachesEveryone = fraction >= 1;

  if (action == 'promote') {
    // Promoting to production always starts a partial rollout, so the 48 h
    // count has a real start. A new build may start one without crash data.
    if (reachesEveryone) {
      return 'Promote to production must start a partial rollout (for '
          'example user_fraction 0.05). Take it to 100% later with complete, '
          'after 48 h.';
    }
    return null;
  }

  if (reachesEveryone) {
    if (releasedAt == null) {
      return 'Cannot find when the latest release went out, so the 48 h '
          'partial rollout cannot be confirmed.';
    }
    if (partialRolloutStarts == null) {
      return 'Cannot read the promote history, so the 48 h partial rollout '
          'cannot be confirmed.';
    }
    var soakStart = releasedAt;
    for (final start in partialRolloutStarts) {
      if (start.isAfter(soakStart)) soakStart = start;
    }
    final soaked = now.difference(soakStart);
    if (soaked < minimumSoak) {
      final hours = (soaked.inMinutes / 60).toStringAsFixed(1);
      return 'This build has been at a partial production rollout for $hours '
          'h. It needs 48 h before going to 100%.';
    }
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

/// Matches promote.yml's `run-name`.
final RegExp _runTitle = RegExp(
  r'^promote action=(\S*) to=(.*) fraction=(.*)$',
);

/// When each successful promote.yml run in [runsJson] started a partial
/// production rollout (`promote` to production at a fraction below 1).
///
/// [runsJson] is the output of `gh run list --workflow promote.yml --status
/// success --json displayTitle,createdAt`. Runs with other titles are
/// ignored. Returns null when [runsJson] cannot be read.
List<DateTime>? partialRolloutStarts(String runsJson) {
  final Object? decoded;
  try {
    decoded = jsonDecode(runsJson);
  } on FormatException {
    return null;
  }
  if (decoded is! List) return null;

  final starts = <DateTime>[];
  for (final run in decoded) {
    if (run is! Map) continue;
    final title = run['displayTitle'];
    final createdAt = run['createdAt'];
    if (title is! String || createdAt is! String) continue;
    final match = _runTitle.firstMatch(title.trim());
    if (match == null || match.group(1) != 'promote') continue;
    if (!_isProduction(match.group(2)!)) continue;
    final fraction = _parseFraction(match.group(3)!);
    if (fraction == null || fraction >= 1) continue;
    final started = DateTime.tryParse(createdAt);
    if (started != null) starts.add(started);
  }
  return starts;
}

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
    releasedAt: DateTime.tryParse(releasedAtText),
    partialRolloutStarts: partialRolloutStarts(env['PROMOTE_RUNS'] ?? ''),
    now: DateTime.now().toUtc(),
    crashFreeUsers: env['CRASH_FREE_USERS'] ?? '',
  );
  if (reason != null) {
    stderr.writeln('::error::$reason');
    exit(1);
  }
  stdout.writeln('Promotion allowed.');
}
