// Release gate for `.github/workflows/auto-release.yml` (A85).
//
// An automatic release needs the latest completed `nightly.yml` run on main
// (golden tests and the emulator integration flows) to have succeeded and to
// have started no more than 36 hours ago. A failed, cancelled, missing or
// stale nightly, or a history that cannot be read, stops the release.
//
// Run by the workflow as `dart run scripts/nightly_gate.dart` with the
// environment variable NIGHTLY_RUNS (JSON from `gh run list --workflow
// nightly.yml --branch main --status completed --limit 1 --json
// conclusion,createdAt,displayTitle`).
import 'dart:convert';
import 'dart:io';

/// The oldest a successful nightly may be: a day plus slack for a late cron.
const Duration maxNightlyAge = Duration(hours: 36);

/// The run name `nightly.yml` gives a golden regeneration run, which skips the
/// integration tests and so is not a full nightly.
const String regenerationRunName = 'nightly golden regeneration';

/// A completed nightly run: how it ended, when it started and its title.
class NightlyRun {
  const NightlyRun({
    required this.conclusion,
    required this.createdAt,
    required this.title,
  });

  final String conclusion;
  final DateTime createdAt;
  final String title;
}

/// Returns why the release must not run, or null when it may run.
///
/// [latestRuns] is newest first, as `gh run list` prints it, and null when it
/// could not be read.
String? nightlyBlockReason({
  required List<NightlyRun>? latestRuns,
  required DateTime now,
  required Duration maxAge,
}) {
  const unblock =
      'Dispatch the nightly workflow on main and wait for it to pass.';
  if (latestRuns == null) {
    return 'Cannot read the nightly run history, so the integration tests '
        'cannot be confirmed. $unblock';
  }
  if (latestRuns.isEmpty) {
    return 'No completed nightly run found on main. $unblock';
  }
  final run = latestRuns.first;
  if (run.conclusion != 'success') {
    return 'The latest nightly run on main ended with ${run.conclusion}. '
        '$unblock';
  }
  if (run.title == regenerationRunName) {
    return 'The latest nightly run on main was a golden regeneration, which '
        'skips the integration tests. $unblock';
  }
  final age = now.difference(run.createdAt);
  if (age > maxAge || age.isNegative) {
    return 'The latest successful nightly run started '
        '${run.createdAt.toIso8601String()}, outside the last '
        '${maxAge.inHours} h. $unblock';
  }
  return null;
}

/// The runs in [json], the output of `gh run list --workflow nightly.yml
/// --json conclusion,createdAt,displayTitle`. Returns null when it cannot be
/// read or a run has no start time or title: without the title a golden
/// regeneration run cannot be told from a full nightly.
List<NightlyRun>? nightlyRuns(String json) {
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return null;
  }
  if (decoded is! List) return null;
  final runs = <NightlyRun>[];
  for (final run in decoded) {
    if (run is! Map) return null;
    final conclusion = run['conclusion'];
    final created = run['createdAt'];
    final createdAt = created is String ? DateTime.tryParse(created) : null;
    final title = run['displayTitle'];
    if (conclusion is! String || createdAt == null || title is! String) {
      return null;
    }
    runs.add(
      NightlyRun(conclusion: conclusion, createdAt: createdAt, title: title),
    );
  }
  return runs;
}

void main() {
  final reason = nightlyBlockReason(
    latestRuns: nightlyRuns(Platform.environment['NIGHTLY_RUNS'] ?? ''),
    now: DateTime.timestamp(),
    maxAge: maxNightlyAge,
  );
  if (reason != null) {
    stderr.writeln('::error::$reason');
    exit(1);
  }
  stdout.writeln('Latest nightly passed. Release allowed.');
}
