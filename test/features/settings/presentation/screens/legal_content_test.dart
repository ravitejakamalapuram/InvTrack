import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:inv_tracker/features/settings/presentation/screens/legal_content.dart';
import 'package:inv_tracker/features/settings/presentation/screens/legal_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

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
      expect(
        privacyPolicyContent,
        contains(
          'We also ask Google Analytics to delete the events tied to your '
          'user ID; Google carries this out on its own schedule.',
        ),
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

    test('says plainly that analytics and crash reports cannot be turned '
        'off, for as long as that is true', () {
      expect(
        privacyPolicyContent,
        contains('There is currently no switch to turn off'),
      );
      // The day a switch exists, the withdrawal text must change with it.
      final switches = <String>[];
      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        if (file.path.contains('${Platform.pathSeparator}generated')) continue;
        if (RegExp(
          r'set(Analytics|Crashlytics|Performance)CollectionEnabled\((?!\s*(?:true|shouldEnable)\b)',
        ).hasMatch(file.readAsStringSync())) {
          switches.add(file.path);
        }
      }
      expect(
        switches,
        isEmpty,
        reason: 'a collection switch exists: update the withdrawal text',
      );
    });

    test('says the app shows no ads, for as long as no screen shows one', () {
      expect(privacyPolicyContent, contains('The app shows no ads.'));
      final screens = <String>[];
      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final path = file.path;
        if (path.contains(
              '${Platform.pathSeparator}ads${Platform.pathSeparator}',
            ) ||
            path.endsWith('native_ad_widget.dart')) {
          continue;
        }
        if (file.readAsStringSync().contains('NativeAdWidget(')) {
          screens.add(path);
        }
      }
      expect(screens, isEmpty);
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
