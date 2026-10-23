import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/settings/data/services/backup_crypto.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/backup_password_dialogs.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

Widget _host(Future<void> Function(BuildContext context) onOpen) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => onOpen(context),
          child: const Text('open'),
        ),
      ),
    ),
  ),
);

void main() {
  group('export dialog', () {
    Future<BackupExportChoice?> open(
      WidgetTester tester,
      void Function(BackupExportChoice?) onResult,
    ) async {
      await tester.pumpWidget(
        _host((c) async => onResult(await showBackupExportDialog(c))),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return null;
    }

    testWidgets('warns about an unprotected file and exports without one', (
      tester,
    ) async {
      BackupExportChoice? result;
      var closed = false;
      await open(tester, (r) {
        result = r;
        closed = true;
      });
      expect(find.textContaining('anyone who gets this file'), findsOneWidget);
      expect(find.text('Confirm Password'), findsNothing);

      await tester.tap(find.text('Export Backup').last);
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(result!.password, isNull);
    });

    testWidgets('password mode shows the no-recovery warning and validates', (
      tester,
    ) async {
      BackupExportChoice? result;
      await open(tester, (r) => result = r);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.textContaining('can’t recover your backup'), findsOneWidget);
      expect(find.textContaining('anyone who gets this file'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'short',
      );
      await tester.tap(find.text('Export Backup').last);
      await tester.pumpAndSettle();
      expect(find.text('Use at least 8 characters.'), findsOneWidget);
      expect(result, isNull);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'long enough pw',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        'different pw!',
      );
      await tester.tap(find.text('Export Backup').last);
      await tester.pumpAndSettle();
      expect(find.text('The passwords don’t match.'), findsOneWidget);
      expect(result, isNull);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        'long enough pw',
      );
      await tester.tap(find.text('Export Backup').last);
      await tester.pumpAndSettle();
      expect(result!.password, 'long enough pw');
    });

    testWidgets('password fields are obscured and the toggle is 48dp', (
      tester,
    ) async {
      await open(tester, (_) {});
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields, hasLength(2));
      expect(fields.every((f) => f.obscureText), isTrue);

      final toggle = find.byTooltip('Show Password');
      expect(toggle, findsWidgets);
      final size = tester.getSize(toggle.first);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      await tester.tap(toggle.first);
      await tester.pump();
      expect(find.byTooltip('Hide Password'), findsWidgets);
    });

    testWidgets('cancel returns null', (tester) async {
      BackupExportChoice? result = const BackupExportChoice(password: 'x');
      await open(tester, (r) => result = r);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    });
  });

  group('unlock dialog', () {
    final plain = Uint8List.fromList([1, 2, 3]);

    Future<void> open(
      WidgetTester tester,
      Future<Uint8List> Function(String) unlock,
      void Function(Uint8List?) onResult,
    ) async {
      await tester.pumpWidget(
        _host(
          (c) async =>
              onResult(await showBackupUnlockDialog(c, unlock: unlock)),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('right password returns the unlocked bytes', (tester) async {
      Uint8List? result;
      String? seen;
      await open(tester, (pw) async {
        seen = pw;
        return plain;
      }, (r) => result = r);
      await tester.enterText(find.byType(TextField), 'secret pw');
      await tester.tap(find.text('Unlock').last);
      await tester.pumpAndSettle();
      expect(seen, 'secret pw');
      expect(result, plain);
    });

    testWidgets('wrong password shows a specific error and stays open', (
      tester,
    ) async {
      Uint8List? result;
      var closed = false;
      await open(tester, (_) async => throw const BackupDecryptionException(), (
        r,
      ) {
        result = r;
        closed = true;
      });
      await tester.enterText(find.byType(TextField), 'nope');
      await tester.tap(find.text('Unlock').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('didn’t work'), findsOneWidget);
      expect(find.textContaining('Nothing was changed'), findsOneWidget);
      expect(closed, isFalse);
      expect(result, isNull);
    });

    testWidgets('an unsupported file shows its own error', (tester) async {
      await open(
        tester,
        (_) async => throw const BackupFormatException('bad'),
        (_) {},
      );
      await tester.enterText(find.byType(TextField), 'anything');
      await tester.tap(find.text('Unlock').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('isn’t supported'), findsOneWidget);
    });

    testWidgets('cancel returns null and does not unlock', (tester) async {
      var called = false;
      Uint8List? result = plain;
      await open(tester, (_) async {
        called = true;
        return plain;
      }, (r) => result = r);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(called, isFalse);
    });
  });
}
