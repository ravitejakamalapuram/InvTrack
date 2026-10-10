import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:inv_tracker/features/settings/presentation/screens/legal_content.dart';
import 'package:inv_tracker/features/settings/presentation/screens/legal_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Hand-written Dart files under lib/ with their text, paths as `lib/...`.
List<({String path, String source})> _libDartFiles() => [
  for (final file in Directory('lib').listSync(recursive: true))
    if (file is File &&
        file.path.endsWith('.dart') &&
        !file.path.contains('${Platform.pathSeparator}generated'))
      (
        path: file.path.replaceAll(Platform.pathSeparator, '/'),
        source: file.readAsStringSync(),
      ),
];

void main() {
  late String privacyPolicyContent;

  setUpAll(() async {
    // main.dart initialises date symbols for every locale before runApp.
    await initializeDateFormatting();
    privacyPolicyContent = privacyPolicyText(
      lookupAppLocalizations(const Locale('en')),
    );
  });

  // The policy is user-facing text, so it lives in the ARB file (rule 16),
  // with the support address, hosted URL and date filled in by the app.
  test('privacy policy text comes from the ARB file', () {
    final arb =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    final meta = arb['@privacyPolicyBody'] as Map<String, dynamic>;
    expect(meta['description'], isNotEmpty);
    expect(
      (meta['placeholders'] as Map<String, dynamic>).keys,
      containsAll(['lastUpdated', 'supportEmail', 'policyUrl']),
    );
    expect(arb['privacyPolicyBody'], isNot(contains(supportEmailAddress)));
    expect(arb['privacyPolicyBody'], isNot(contains(hostedPrivacyPolicyUrl)));

    final dart = File(
      'lib/features/settings/presentation/screens/legal_content.dart',
    ).readAsStringSync();
    expect(dart, isNot(contains('Data Collection')));

    expect(
      privacyPolicyContent,
      contains('contact us at $supportEmailAddress.'),
    );
  });
  test('privacy policy text matches real Firebase behaviour', () {
    final text = privacyPolicyContent.toLowerCase();
    expect(privacyPolicyContent, contains('Google Firebase'));
    expect(privacyPolicyContent, contains('Crashlytics'));
    expect(privacyPolicyContent, contains(hostedPrivacyPolicyUrl));
    expect(text, isNot(contains('stored locally')));
    expect(text, isNot(contains('never uploaded')));
  });

  // A69 (C074, SEC-05): the data sits in the developer's Firebase project
  // without client-side encryption, so the operator can read it. The policy
  // must not say that only the user can read it or call it a private cloud.
  test('privacy policy does not claim only the user can read the data', () {
    final text = privacyPolicyContent.toLowerCase();
    expect(text, isNot(contains('only you can read')));
    expect(text, isNot(contains('private cloud')));
    expect(
      privacyPolicyContent,
      isNot(
        contains(
          RegExp(r'only\s+you\s+can\s+(read|see|access)', caseSensitive: false),
        ),
      ),
    );
    expect(
      privacyPolicyContent,
      isNot(contains(RegExp(r'private\s+cloud', caseSensitive: false))),
    );
  });

  test('privacy policy says plainly who can read stored data', () {
    expect(privacyPolicyContent, contains('Last updated: October 10, 2026'));
    expect(
      privacyPolicyContent,
      contains(
        "Your data is stored in InvTrack's Google Firebase (Cloud Firestore) "
        'project under your account, so it syncs across your devices and '
        'works offline. Google encrypts it in transit and at rest. In the '
        'app, only your signed-in account can see your records. The '
        'developer can technically access stored data and does so only to '
        'answer a support request from you, to process a deletion request, '
        'or when the law requires it. We do not sell your data, and we do '
        'not use it for advertising.',
      ),
    );
  });

  // A39 (minimal part) and A102: the policy names who processes the data,
  // why, where it is stored, how long it is kept, how to use your rights and
  // whom to ask. Every sentence is backed by code; the PR lists the evidence.
  group('privacy policy facts', () {
    test('was last updated on 10 October 2026', () {
      expect(privacyPolicyLastUpdated, DateTime(2026, 10, 10));
    });

    test('names every processor the app calls', () {
      for (final name in [
        'Firebase Authentication',
        'Cloud Firestore',
        'Analytics',
        'Crashlytics',
        'Performance Monitoring',
        'Google Sign-In',
        'Google Fonts',
        'Google Play',
        'api.frankfurter.dev',
        'api.exchangerate-api.com',
      ]) {
        expect(privacyPolicyContent, contains(name));
      }
    });

    // The fixed list above can drift from the build. This one reads
    // pubspec.yaml: any Google or Firebase SDK that ships must be named here
    // (and so in the policy) before the test passes.
    test('names every Google and Firebase SDK that ships in the build', () {
      const named = {
        'firebase_auth': 'Firebase Authentication',
        'cloud_firestore': 'Cloud Firestore',
        'firebase_analytics': 'Analytics',
        'firebase_crashlytics': 'Crashlytics',
        'firebase_performance': 'Performance Monitoring',
        'google_sign_in': 'Google Sign-In',
        'google_fonts': 'Google Fonts',
        'google_mobile_ads': 'Google Mobile Ads',
        'in_app_update': 'in-app update',
        'in_app_review': 'review prompt',
      };
      // Plumbing with no data flow of its own.
      const plumbing = {'firebase_core'};
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final runtime = pubspec.substring(
        pubspec.indexOf('\ndependencies:'),
        pubspec.indexOf('\ndev_dependencies:'),
      );
      final shipped = RegExp(
        r'^  ((?:firebase_|google_|cloud_|in_app_)\w+):',
        multiLine: true,
      ).allMatches(runtime).map((m) => m[1]!).toSet();
      expect(
        shipped.difference({...named.keys, ...plumbing}),
        isEmpty,
        reason: 'an SDK ships that the privacy policy does not name',
      );
      expect(
        named.keys.toSet().difference(shipped),
        isEmpty,
        reason: 'the policy names an SDK that no longer ships: update this map',
      );
      for (final phrase in named.values) {
        expect(privacyPolicyContent, contains(phrase));
      }
    });

    test('says the ads library and advertising ID permission are present', () {
      expect(privacyPolicyContent, contains('The app shows no ads.'));
      expect(privacyPolicyContent, contains('Google Mobile Ads'));
      expect(privacyPolicyContent, contains('advertising ID'));
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains('com.google.android.gms.permission.AD_ID'));
    });

    test('says who shows the app-rating prompt', () {
      expect(
        privacyPolicyContent,
        contains(
          'Google Play shows and handles the review prompt; the app is not '
          'told whether you left a review.',
        ),
      );
    });

    test('names every exchange-rate host the currency service calls', () {
      final source = File(
        'lib/core/services/currency_conversion_service.dart',
      ).readAsStringSync();
      final hosts = RegExp(
        r"_(?:primary|fallback)ApiBaseUrl\s*=\s*'https://([\w.-]+)",
      ).allMatches(source).map((m) => m[1]!).toList();
      expect(hosts, hasLength(2));
      for (final host in hosts) {
        expect(privacyPolicyContent, contains(host));
      }
    });

    test('says what the exchange-rate services are sent', () {
      expect(
        privacyPolicyContent,
        contains('It sends only currency codes and dates'),
      );
    });

    test('says the data may be stored outside India', () {
      expect(privacyPolicyContent, contains('outside India'));
    });

    test('says how long records, analytics and crash reports are kept', () {
      expect(
        privacyPolicyContent,
        contains(
          'Your records stay until you delete them or delete your account.',
        ),
      );
      expect(
        privacyPolicyContent,
        contains(
          'Analytics events and crash reports are kept by Google for its own '
          'retention period for each service, and are then deleted '
          'automatically.',
        ),
      );
    });

    test('says what happens to analytics and crash data after deletion', () {
      // True whether or not the deletion job asks Google Analytics to delete
      // the events (it needs GA4_PROPERTY_ID and a scheduled live run), so
      // the policy must not promise that request.
      expect(
        privacyPolicyContent,
        contains(
          'Analytics events tied to your user ID are deleted automatically at '
          'the end of Google\'s retention period. We may also ask Google to '
          'delete them sooner; Google carries out any such request on its own '
          'schedule.',
        ),
      );
      expect(
        privacyPolicyContent,
        isNot(contains('We also ask Google Analytics')),
      );
      expect(
        privacyPolicyContent,
        contains(
          'We cannot delete individual crash reports. They are deleted '
          'automatically at the end of the Crashlytics retention period.',
        ),
      );
      expect(
        privacyPolicyContent,
        contains(
          'Once you are signed out, new crash and analytics reports from '
          'this device no longer carry your user ID.',
        ),
      );
    });

    test('tells you where in the app to export, correct and delete', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        privacyPolicyContent,
        contains('Settings > ${l10n.dataAndAccount} > Export as CSV'),
      );
      expect(
        privacyPolicyContent,
        contains('Settings > ${l10n.dataAndAccount} > ${l10n.deleteAccount}'),
      );
      expect(privacyPolicyContent, contains('edit any record in the app'));
    });

    test('points to the web deletion page and the support email', () {
      expect(privacyPolicyContent, contains(hostedAccountDeletionUrl));
      expect(privacyPolicyContent, contains(supportEmailAddress));
    });

    // The next two tests are heuristics: they catch the usual ways the
    // statement would stop being true, not every possible way. They list what
    // is allowed instead of what is forbidden, so a new call site fails until
    // someone has read it and updated the policy.
    test('says plainly that analytics and crash reports cannot be turned '
        'off, for as long as that is true', () {
      expect(
        privacyPolicyContent,
        contains('There is currently no switch to turn off'),
      );

      // 1. Every call that changes collection or consent is known.
      final call = RegExp(
        r'\b(set(?:Analytics|Crashlytics|Performance)CollectionEnabled|setConsent)\s*\(\s*([^)]*?)\s*\)',
      );
      final calls = <String>[];
      for (final file in _libDartFiles()) {
        for (final m in call.allMatches(file.source)) {
          calls.add('${file.path}: ${m[1]}(${m[2]})');
        }
      }
      const crashlyticsFile = 'lib/core/analytics/crashlytics_service.dart';
      const performanceFile = 'lib/core/performance/performance_service.dart';
      expect(
        calls..sort(),
        [
          '$crashlyticsFile: setCrashlyticsCollectionEnabled(shouldEnable)',
          '$crashlyticsFile: setCrashlyticsCollectionEnabled(shouldEnable)',
          '$performanceFile: setPerformanceCollectionEnabled(true)',
        ],
        reason:
            'a collection or consent call changed: update the withdrawal text',
      );

      // 2. shouldEnable is the debug-build rule, which is always true in a
      // release build, and never a stored choice.
      final crashlytics = File(crashlyticsFile).readAsStringSync();
      final rules = RegExp(
        r'shouldEnable\s*=\s*([^;]+);',
      ).allMatches(crashlytics).map((m) => m[1]!.trim()).toList();
      expect(rules, hasLength(2));
      expect(rules, everyElement(startsWith('!kDebugMode ||')));

      // 3. No platform-level collection switch in the manifest.
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(
        RegExp(
          r'firebase_\w+_collection_(?:enabled|deactivated)|google_analytics_\w+',
        ).allMatches(manifest).map((m) => m[0]).toList(),
        isEmpty,
        reason: 'a manifest collection flag exists: update the withdrawal text',
      );
    });

    test('says the app shows no ads, for as long as only the ads layer '
        'knows about ads', () {
      expect(privacyPolicyContent, contains('The app shows no ads.'));
      const adsLayer = {
        'lib/core/ads/ad_placement_strategy.dart',
        'lib/core/ads/ad_provider.dart',
        'lib/core/ads/ad_service.dart',
        'lib/core/widgets/native_ad_widget.dart',
      };
      final outsiders = [
        for (final file in _libDartFiles())
          if (!adsLayer.contains(file.path) &&
              RegExp(
                r'google_mobile_ads|core/ads/|NativeAd|AdService|MobileAds|adServiceProvider',
              ).hasMatch(file.source))
            file.path,
      ];
      expect(
        outsiders,
        isEmpty,
        reason: 'a file outside the ads layer uses ads: update the ads text',
      );
    });
  });

  testWidgets('LegalScreen shows hosted-policy link when provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LegalScreen(
          title: 'Privacy',
          content: 'x',
          linkUri: Uri.parse(hostedPrivacyPolicyUrl),
          linkLabel: 'View online',
        ),
      ),
    );
    expect(find.byKey(const Key('legal_screen_link')), findsOneWidget);
    expect(find.text('View online'), findsOneWidget);
  });

  testWidgets('LegalScreen has no link by default', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LegalScreen(title: 'T', content: 'x'),
      ),
    );
    expect(find.byKey(const Key('legal_screen_link')), findsNothing);
  });
}
