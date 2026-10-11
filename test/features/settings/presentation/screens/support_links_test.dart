import 'dart:async';
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

/// The one web page (APP-333) where anyone with a Google account, with or
/// without the app, can ask for their account to be deleted (A104, #869).
/// Play Console's Data safety form must show the same address.
const _canonicalDeletionUrl =
    'https://ravitejakamalapuram.github.io/delete/invtrack.html';

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

/// Makes the platform answer every launch with [launched], or fail with an
/// exception whose text must never reach the screen. Returns the clipboard
/// text, which stays null until the app copies something. A [launchGate] or
/// [clipboardGate] holds that answer back until the test completes it, so a
/// test can act while the app is still waiting.
ValueNotifier<String?> _mockLauncherAndClipboard({
  bool launched = true,
  bool throws = false,
  Completer<bool>? launchGate,
  Completer<void>? clipboardGate,
}) {
  final clipboard = ValueNotifier<String?>(null);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/url_launcher'),
    (call) async {
      if (throws) {
        throw PlatformException(code: 'ERROR', message: _secretDetail);
      }
      if (launchGate != null) return launchGate.future;
      return launched;
    },
  );
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') {
      clipboard.value = (call.arguments as Map)['text'] as String?;
      await clipboardGate?.future;
    }
    return null;
  });
  addTearDown(() {
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      null,
    );
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });
  return clipboard;
}

const _secretDetail = 'internal-launcher-detail';
const _copiedMessage =
    'Could not open the browser. Link copied to clipboard: $_canonicalDeletionUrl';

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

    // Screen readers: both entry points are buttons named after the link and
    // say that they open the browser, so nobody is surprised by leaving the app.
    testWidgets('About tile is a button that says it opens the browser', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
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
      final tile = find.widgetWithText(ListTile, l10n.deleteAccountOnTheWeb);
      await tester.scrollUntilVisible(
        tile,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(l10n.opensInBrowser, 'Opens in your browser');
      expect(
        tester.getSemantics(tile),
        containsSemantics(
          label: l10n.deleteAccountOnTheWeb,
          hint: l10n.opensInBrowser,
          isButton: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('Help & FAQ link is a button that says it opens the browser', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _localized(const HelpFaqScreen(showDeveloperFaq: true)),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(HelpFaqScreen)),
      );
      final link = find.byKey(const Key('delete_account_web_link'));
      await tester.scrollUntilVisible(
        link,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester.getSemantics(link),
        containsSemantics(
          label: l10n.deleteAccountOnTheWeb,
          hint: l10n.opensInBrowser,
          isButton: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
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

    // No browser can open the page: launchUrl answers false or throws. The
    // tap must not do nothing: the address goes to the clipboard and a
    // snackbar says so. The exception text is never shown.
    final entryPoints = <String, Future<void> Function(WidgetTester)>{
      'About': (tester) async {
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
        await tester.tap(tile);
        await tester.pumpAndSettle();
      },
      'Help & FAQ': (tester) async {
        await tester.pumpWidget(
          _localized(const HelpFaqScreen(showDeveloperFaq: true)),
        );
        await tester.pumpAndSettle();
        final link = find.byKey(const Key('delete_account_web_link'));
        await tester.scrollUntilVisible(
          link,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(link);
        await tester.pumpAndSettle();
      },
    };

    for (final entry in entryPoints.entries) {
      for (final failure in ['returns false', 'throws']) {
        testWidgets(
          '${entry.key}: when the browser launch $failure, the address is '
          'copied and a snackbar says so',
          (tester) async {
            final semantics = tester.ensureSemantics();
            final clipboard = _mockLauncherAndClipboard(
              launched: false,
              throws: failure == 'throws',
            );

            await entry.value(tester);

            expect(clipboard.value, _canonicalDeletionUrl);
            expect(find.text(_copiedMessage), findsOneWidget);
            expect(find.textContaining(_secretDetail), findsNothing);
            expect(
              tester.getSemantics(find.text(_copiedMessage)),
              containsSemantics(label: _copiedMessage),
            );
            semantics.dispose();
          },
        );
      }

      testWidgets(
        '${entry.key}: when the browser opens, nothing is copied and no '
        'snackbar shows',
        (tester) async {
          final clipboard = _mockLauncherAndClipboard();

          await entry.value(tester);

          expect(clipboard.value, isNull);
          expect(find.byType(SnackBar), findsNothing);
        },
      );
    }

    // The user can leave the screen while the browser launch or the clipboard
    // write is still pending. The fallback must then stop: no clipboard write
    // after the launch, and no snackbar on the screen they went to.
    Future<void> openFromHome(WidgetTester tester, Widget screen) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            packageInfoProvider.overrideWith((ref) async => packageInfo),
          ],
          child: _localized(
            Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute<void>(builder: (_) => screen)),
                  child: const Text('open screen'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open screen'));
      await tester.pumpAndSettle();
    }

    final leavingEntryPoints =
        <String, ({Type screen, Future<void> Function(WidgetTester) tapLink})>{
          'About': (
            screen: AboutScreen,
            tapLink: (tester) async {
              await openFromHome(tester, const AboutScreen());
              final l10n = AppLocalizations.of(
                tester.element(find.byType(AboutScreen)),
              );
              final tile = find.text(l10n.deleteAccountOnTheWeb);
              await tester.scrollUntilVisible(
                tile,
                200,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.tap(tile);
              await tester.pump();
            },
          ),
          'Help & FAQ': (
            screen: HelpFaqScreen,
            tapLink: (tester) async {
              await openFromHome(
                tester,
                const HelpFaqScreen(showDeveloperFaq: true),
              );
              final link = find.byKey(const Key('delete_account_web_link'));
              await tester.scrollUntilVisible(
                link,
                300,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.tap(link);
              await tester.pump();
            },
          ),
        };

    for (final entry in leavingEntryPoints.entries) {
      Future<void> leave(WidgetTester tester) async {
        Navigator.of(tester.element(find.byType(entry.value.screen))).pop();
        await tester.pumpAndSettle();
        expect(find.byType(entry.value.screen), findsNothing);
      }

      testWidgets(
        '${entry.key}: leaving the screen while the browser launch is '
        'pending copies nothing and shows no snackbar',
        (tester) async {
          final launchGate = Completer<bool>();
          final clipboard = _mockLauncherAndClipboard(launchGate: launchGate);

          await entry.value.tapLink(tester);
          await leave(tester);
          launchGate.complete(false);
          await tester.pumpAndSettle();

          expect(clipboard.value, isNull);
          expect(find.byType(SnackBar), findsNothing);
        },
      );

      testWidgets(
        '${entry.key}: leaving the screen while the address is being copied '
        'shows no snackbar',
        (tester) async {
          final clipboardGate = Completer<void>();
          final clipboard = _mockLauncherAndClipboard(
            launched: false,
            clipboardGate: clipboardGate,
          );

          await entry.value.tapLink(tester);
          await tester.pumpAndSettle();
          // The launch failed, so the copy has started and is waiting.
          expect(clipboard.value, _canonicalDeletionUrl);
          await leave(tester);
          clipboardGate.complete();
          await tester.pumpAndSettle();

          expect(find.byType(SnackBar), findsNothing);
        },
      );
    }
  });
}
