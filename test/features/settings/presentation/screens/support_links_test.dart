import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:inv_tracker/core/providers/package_info_provider.dart';
import 'package:inv_tracker/features/settings/presentation/screens/about_screen.dart';
import 'package:inv_tracker/features/settings/presentation/screens/help_faq_screen.dart';
import 'package:inv_tracker/features/settings/presentation/screens/legal_content.dart';
import 'package:inv_tracker/features/settings/presentation/screens/legal_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The one privacy-policy URL and the one support address (A02, #750).
const _canonicalPolicyUrl =
    'https://ravitejakamalapuram.github.io/privacy/invtrack.html';
const _canonicalSupportEmail = 'support@invtracker.app';

/// The one web page where anyone, with or without the app, can ask for their
/// account to be deleted (A104, #869). Play Console's Data safety form must
/// show the same address.
const _canonicalDeletionUrl =
    'https://ravitejakamalapuram.github.io/privacy/invtrack-delete-account.html';

Widget _localized(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

/// Every source file in lib/ that a person edits (generated code excluded).
Iterable<File> _handWrittenLibFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart') || f.path.endsWith('.arb'))
    .where((f) => !f.path.contains('${Platform.pathSeparator}generated'))
    .where((f) => !f.path.endsWith('.g.dart'))
    .where((f) => !f.path.endsWith('.freezed.dart'));

/// Records every address the app asks the platform to open. url_launcher
/// sends it over this channel when no platform implementation is registered,
/// as in widget tests.
List<String> _captureLaunchedUrls() {
  final launched = <String>[];
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'launch') {
          launched.add((call.arguments as Map)['url'] as String);
        }
        return true;
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  return launched;
}

void main() {
  group('canonical contact values', () {
    test('policy URL and support email have the canonical values', () {
      expect(hostedPrivacyPolicyUrl, _canonicalPolicyUrl);
      expect(supportEmailAddress, _canonicalSupportEmail);
    });

    test('web account-deletion URL has the canonical value', () {
      expect(hostedAccountDeletionUrl, _canonicalDeletionUrl);
    });

    test('in-app privacy policy names the same URL and address', () async {
      await initializeDateFormatting();
      final privacyPolicyContent = privacyPolicyText(
        lookupAppLocalizations(const Locale('en')),
      );
      expect(privacyPolicyContent, contains(hostedPrivacyPolicyUrl));
      expect(privacyPolicyContent, contains(hostedAccountDeletionUrl));
      expect(privacyPolicyContent, contains(supportEmailAddress));
    });

    test('lib/ spells out the support email and policy URL only once', () {
      final emailPattern = RegExp(r'[\w.+-]+@[\w-]+(?:\.[\w-]+)+');
      final policyUrlPattern = RegExp(r'https?://[\w.-]+\.github\.io/[\w./-]*');
      final emailHits = <String>[];
      final urlHits = <String>[];
      for (final file in _handWrittenLibFiles()) {
        final text = file.readAsStringSync();
        for (final m in emailPattern.allMatches(text)) {
          emailHits.add('${file.path}: ${m[0]}');
        }
        for (final m in policyUrlPattern.allMatches(text)) {
          urlHits.add('${file.path}: ${m[0]}');
        }
      }
      final legalContent = [
        'lib',
        'features',
        'settings',
        'presentation',
        'screens',
        'legal_content.dart',
      ].join(Platform.pathSeparator);
      expect(emailHits, ['$legalContent: $_canonicalSupportEmail']);
      expect(urlHits, [
        '$legalContent: $_canonicalPolicyUrl',
        '$legalContent: $_canonicalDeletionUrl',
      ]);
    });

    test('no other account-deletion page URL is spelled out in lib/', () {
      // Any web address with "delet" in it: a second copy would drift from
      // the one the Play Console shows.
      final deletionUrlPattern = RegExp(
        r'''https?://[^\s'"]*delet[^\s'"]*''',
        caseSensitive: false,
      );
      final hits = <String>[];
      for (final file in _handWrittenLibFiles()) {
        for (final m in deletionUrlPattern.allMatches(
          file.readAsStringSync(),
        )) {
          hits.add('${file.path}: ${m[0]}');
        }
      }
      final legalContent = [
        'lib',
        'features',
        'settings',
        'presentation',
        'screens',
        'legal_content.dart',
      ].join(Platform.pathSeparator);
      expect(hits, ['$legalContent: $_canonicalDeletionUrl']);
    });
  });

  group('outside the app', () {
    test('app-metadata.json registers the same privacy policy URL', () {
      final metadata =
          jsonDecode(File('app-metadata.json').readAsStringSync())
              as Map<String, dynamic>;
      final modules = (metadata['modules'] as List).cast<Map>();
      final urls = modules
          .map((m) => (m['playStoreListing'] as Map?)?['privacyPolicyUrl'])
          .whereType<String>()
          .toList();
      expect(urls, [hostedPrivacyPolicyUrl]);
    });

    test('README shows the same privacy policy URL and support email', () {
      final readme = File('README.md').readAsStringSync();
      expect(readme, contains(hostedPrivacyPolicyUrl));
      expect(readme, contains(hostedAccountDeletionUrl));
      expect(readme, contains(supportEmailAddress));
    });
  });

  group('screens', () {
    final packageInfo = PackageInfo(
      appName: 'InvTrack',
      packageName: 'com.invtracker.inv_tracker',
      version: '1.2.3',
      buildNumber: '45',
    );

    testWidgets('About shows the support constant and links the policy URL', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            packageInfoProvider.overrideWith((ref) async => packageInfo),
          ],
          child: _localized(const AboutScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text(supportEmailAddress),
        200,
        scrollable: scrollable,
      );
      expect(find.text(supportEmailAddress), findsOneWidget);

      final context = tester.element(find.byType(AboutScreen));
      final l10n = AppLocalizations.of(context);
      await tester.scrollUntilVisible(
        find.text(l10n.privacyPolicy),
        -200,
        scrollable: scrollable,
      );
      await tester.tap(find.text(l10n.privacyPolicy));
      await tester.pumpAndSettle();

      final legal = tester.widget<LegalScreen>(find.byType(LegalScreen));
      expect(legal.linkUri, Uri.parse(_canonicalPolicyUrl));
      expect(legal.content, contains(_canonicalSupportEmail));
    });

    testWidgets('About shows "Delete your account on the web" and a tap opens '
        'the deletion page', (tester) async {
      final launched = _captureLaunchedUrls();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            packageInfoProvider.overrideWith((ref) async => packageInfo),
          ],
          child: _localized(const AboutScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(AboutScreen)),
      );
      final tile = find.text(l10n.deleteAccountOnTheWeb);
      await tester.scrollUntilVisible(
        tile,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(l10n.deleteAccountOnTheWeb, 'Delete your account on the web');
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(launched, [_canonicalDeletionUrl]);
    });

    testWidgets('Help & FAQ shows "Delete your account on the web" and a tap '
        'opens the deletion page', (tester) async {
      final launched = _captureLaunchedUrls();
      await tester.pumpWidget(
        _localized(const HelpFaqScreen(showDeveloperFaq: true)),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(HelpFaqScreen)),
      );
      final link = find.text(l10n.deleteAccountOnTheWeb);
      await tester.scrollUntilVisible(
        link,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(link);
      await tester.pumpAndSettle();

      expect(launched, [_canonicalDeletionUrl]);
    });

    testWidgets('Help & FAQ shows the support constant', (tester) async {
      await tester.pumpWidget(
        _localized(const HelpFaqScreen(showDeveloperFaq: true)),
      );
      await tester.pumpAndSettle();

      final finder = find.textContaining(supportEmailAddress);
      await tester.scrollUntilVisible(
        finder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(finder, findsOneWidget);
    });
  });
}
