// Release safety guard for `.github/workflows/promote.yml` (A63).
//
// No build reaches 100% of production until it has been out for at least
// 48 hours at a partial rollout and Crashlytics shows at least 99.5%
// crash-free users. Widening a partial production rollout (for example
// 5% -> 20%) needs the crash-free figure too. Halting is never blocked.
//
// Run by the workflow as `dart run scripts/promotion_guard.dart` with these
// environment variables: ACTION, TO_TRACK, USER_FRACTION, RELEASED_AT
// (ISO 8601, the latest GitHub Release) and CRASH_FREE_USERS (percent).
import 'dart:io';

/// Minimum time a release must spend at a partial rollout before 100%.
const Duration minimumSoak = Duration(hours: 48);

/// Minimum Crashlytics crash-free users, in percent, to widen a rollout.
const double minimumCrashFreeUsers = 99.5;

const String _productionTrack = 'production';

/// Returns why the promotion must not run, or null when it may run.
String? promotionBlockReason({
  required String action,
  required String toTrack,
  required String userFraction,
  required DateTime? releasedAt,
  required DateTime now,
  required String crashFreeUsers,
}) {
  if (action == 'halt') return null;
  if (!const {'promote', 'rollout', 'complete'}.contains(action)) {
    return 'Unknown action "$action".';
  }
  if (toTrack.trim() != _productionTrack) return null;

  final fraction = action == 'complete' ? 1.0 : _parseFraction(userFraction);
  if (fraction == null) {
    return 'User fraction "$userFraction" must be a number in (0, 1].';
  }
  final reachesEveryone = fraction >= 1;

  // A new build may start a partial rollout without crash data.
  if (action == 'promote' && !reachesEveryone) return null;

  if (reachesEveryone) {
    if (releasedAt == null) {
      return 'Cannot find when the latest release went out, so the 48 h '
          'partial rollout cannot be confirmed.';
    }
    final soaked = now.difference(releasedAt);
    if (soaked < minimumSoak) {
      final hours = (soaked.inMinutes / 60).toStringAsFixed(1);
      return 'The latest release has been out for $hours h. It needs 48 h at '
          'a partial rollout before going to 100%.';
    }
  }

  final crashFree = double.tryParse(crashFreeUsers.trim());
  if (crashFree == null || crashFree < 0 || crashFree > 100) {
    return 'Enter Crashlytics crash-free users for this release as a '
        'percentage (for example 99.7).';
  }
  if (crashFree < minimumCrashFreeUsers) {
    return 'Crash-free users are $crashFree%. Widening the rollout needs at '
        'least $minimumCrashFreeUsers%.';
  }
  return null;
}

/// Empty means 100%, as in the shared promote workflow.
double? _parseFraction(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return 1;
  final value = double.tryParse(text);
  if (value == null || value <= 0 || value > 1) return null;
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
    now: DateTime.now().toUtc(),
    crashFreeUsers: env['CRASH_FREE_USERS'] ?? '',
  );
  if (reason != null) {
    stderr.writeln('::error::$reason');
    exit(1);
  }
  stdout.writeln('Promotion allowed.');
}
