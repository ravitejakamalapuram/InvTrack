import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/delete_account_web_link.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

void main() {
  // The widget is pure UI: a screen decides what a tap does (open the page,
  // or copy the address when no browser can), so the widget itself must not
  // launch anything or touch the clipboard.
  testWidgets('a tap runs the callback once and does nothing else', (
    tester,
  ) async {
    final launches = <String>[];
    final clipboardWrites = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async {
        launches.add(call.method);
        return true;
      },
    );
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardWrites.add((call.arguments as Map)['text'] as String);
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

    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: DeleteAccountWebLink(onPressed: () => taps++)),
      ),
    );

    await tester.tap(find.byKey(const Key('delete_account_web_link')));
    await tester.pumpAndSettle();

    expect(taps, 1);
    expect(launches, isEmpty);
    expect(clipboardWrites, isEmpty);
  });
}
