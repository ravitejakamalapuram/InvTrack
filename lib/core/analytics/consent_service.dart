/// The user's analytics and crash-reporting choices (A34, #778).
///
/// Both default to on, so an existing user keeps today's behaviour until they
/// switch one off. The stored choice is applied to Firebase on every start.
library;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String analyticsConsentPrefKey = 'consent_analytics_enabled';
const String crashReportingConsentPrefKey = 'consent_crash_reporting_enabled';

/// Whether the user allows crash reports; true when they never chose.
bool crashReportingConsentFrom(SharedPreferences prefs) =>
    prefs.getBool(crashReportingConsentPrefKey) ?? true;

class ConsentService {
  ConsentService(
    this._prefs, {
    FirebaseAnalytics? analytics,
    FirebaseCrashlytics? crashlytics,
  }) : _analytics = analytics,
       _crashlytics = crashlytics;

  final SharedPreferences _prefs;
  final FirebaseAnalytics? _analytics;
  final FirebaseCrashlytics? _crashlytics;

  FirebaseAnalytics get _a => _analytics ?? FirebaseAnalytics.instance;
  FirebaseCrashlytics get _c => _crashlytics ?? FirebaseCrashlytics.instance;

  bool get analyticsEnabled => _prefs.getBool(analyticsConsentPrefKey) ?? true;
  bool get crashReportingEnabled => crashReportingConsentFrom(_prefs);

  /// Applies the stored choices. Crashlytics is touched only to switch it off:
  /// [CrashlyticsService.initialize] owns the debug-build rule for switching
  /// it on, and also honours the choice.
  Future<void> applyAtStartup() async {
    await _a.setAnalyticsCollectionEnabled(analyticsEnabled);
    if (!crashReportingEnabled) {
      await _c.setCrashlyticsCollectionEnabled(false);
      // Reports written while collection was off must never be sent later.
      await _c.deleteUnsentReports();
    }
  }

  /// Applies the choice to Firebase first and stores it only if that worked.
  Future<void> setAnalytics(bool value) async {
    await _a.setAnalyticsCollectionEnabled(value);
    await _prefs.setBool(analyticsConsentPrefKey, value);
  }

  Future<void> setCrashReporting(bool value) async {
    final wasEnabled = crashReportingEnabled;
    final enabled =
        value && (!kDebugMode || CrashlyticsService.enableInDebugMode);
    if (value && !wasEnabled) {
      // Collection is still off here, so this removes what was cached while
      // the user had opted out, before any of it can be sent.
      await _c.deleteUnsentReports();
    }
    await _c.setCrashlyticsCollectionEnabled(enabled);
    if (!value) await _c.deleteUnsentReports();
    await _prefs.setBool(crashReportingConsentPrefKey, value);
  }
}

final consentServiceProvider = Provider<ConsentService>(
  (ref) => ConsentService(ref.watch(sharedPreferencesProvider)),
);

class AnalyticsConsentNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(consentServiceProvider).analyticsEnabled;

  Future<void> setEnabled(bool value) async {
    await ref.read(consentServiceProvider).setAnalytics(value);
    state = value;
  }
}

class CrashReportingConsentNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(consentServiceProvider).crashReportingEnabled;

  Future<void> setEnabled(bool value) async {
    await ref.read(consentServiceProvider).setCrashReporting(value);
    state = value;
  }
}

final analyticsConsentProvider =
    NotifierProvider<AnalyticsConsentNotifier, bool>(
      AnalyticsConsentNotifier.new,
    );

final crashReportingConsentProvider =
    NotifierProvider<CrashReportingConsentNotifier, bool>(
      CrashReportingConsentNotifier.new,
    );
