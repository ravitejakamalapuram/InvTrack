/// The user's two privacy switches: usage data and crash reports.
///
/// Both default to on, which is how the app behaved before the switches
/// existed. A choice is saved only after Firebase accepted it, so the saved
/// value never disagrees with what is really being collected.
library;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String privacyAnalyticsKey = 'privacy_analytics_enabled';
const String privacyCrashReportsKey = 'privacy_crash_reports_enabled';

/// Reads the saved choices. Nothing saved means on.
abstract final class PrivacyChoices {
  static bool analyticsEnabled(SharedPreferences prefs) =>
      prefs.getBool(privacyAnalyticsKey) ?? true;

  static bool crashReportsEnabled(SharedPreferences prefs) =>
      prefs.getBool(privacyCrashReportsKey) ?? true;
}

/// Whether Crashlytics should collect. The user's choice always wins; debug
/// builds additionally need the debug-mode switch, as before.
bool crashCollectionEnabled({
  required bool userChoice,
  required bool debugModeEnabled,
  bool isDebugBuild = kDebugMode,
}) => userChoice && (!isDebugBuild || debugModeEnabled);

/// Turns collection on or off in the Firebase SDKs. Replaced in tests.
abstract class PrivacyCollectionApplier {
  Future<void> setAnalytics(bool enabled);
  Future<void> setPerformance(bool enabled);
  Future<void> setCrashReports(bool enabled);
}

class FirebasePrivacyApplier implements PrivacyCollectionApplier {
  @override
  Future<void> setAnalytics(bool enabled) =>
      FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);

  @override
  Future<void> setPerformance(bool enabled) =>
      FirebasePerformance.instance.setPerformanceCollectionEnabled(enabled);

  @override
  Future<void> setCrashReports(bool enabled) {
    CrashlyticsService.userAllowsReports = enabled;
    final collect = crashCollectionEnabled(
      userChoice: enabled,
      debugModeEnabled: CrashlyticsService.enableInDebugMode,
    );
    final crashlytics = FirebaseCrashlytics.instance;
    return crashlytics.setCrashlyticsCollectionEnabled(collect);
  }
}

final privacyCollectionApplierProvider = Provider<PrivacyCollectionApplier>(
  (ref) => FirebasePrivacyApplier(),
);

/// Applies the saved choices once at app start, before anything is sent.
Future<void> applyStoredPrivacyChoices(
  SharedPreferences prefs,
  PrivacyCollectionApplier applier,
) async {
  final analytics = PrivacyChoices.analyticsEnabled(prefs);
  await applier.setAnalytics(analytics);
  await applier.setPerformance(analytics);
  await applier.setCrashReports(PrivacyChoices.crashReportsEnabled(prefs));
}

/// "Share usage data". Also covers performance monitoring.
class AnalyticsSharingNotifier extends Notifier<bool> {
  @override
  bool build() =>
      PrivacyChoices.analyticsEnabled(ref.watch(sharedPreferencesProvider));

  Future<void> setEnabled(bool enabled) async {
    if (state == enabled) return;
    final applier = ref.read(privacyCollectionApplierProvider);
    await applier.setAnalytics(enabled);
    await applier.setPerformance(enabled);
    await ref
        .read(sharedPreferencesProvider)
        .setBool(privacyAnalyticsKey, enabled);
    state = enabled;
  }
}

final analyticsSharingProvider =
    NotifierProvider<AnalyticsSharingNotifier, bool>(
      AnalyticsSharingNotifier.new,
    );

/// "Send crash reports".
class CrashReportsNotifier extends Notifier<bool> {
  @override
  bool build() =>
      PrivacyChoices.crashReportsEnabled(ref.watch(sharedPreferencesProvider));

  Future<void> setEnabled(bool enabled) async {
    if (state == enabled) return;
    await ref.read(privacyCollectionApplierProvider).setCrashReports(enabled);
    await ref
        .read(sharedPreferencesProvider)
        .setBool(privacyCrashReportsKey, enabled);
    state = enabled;
  }
}

final crashReportsProvider = NotifierProvider<CrashReportsNotifier, bool>(
  CrashReportsNotifier.new,
);
