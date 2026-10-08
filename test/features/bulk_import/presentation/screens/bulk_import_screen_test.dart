import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
// The platform interface is the documented way to replace the picker.
// ignore: implementation_imports
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/bulk_import/presentation/screens/bulk_import_screen.dart';
import 'package:inv_tracker/features/bulk_import/presentation/screens/import_confirmation_screen.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class _FakePicker extends FilePickerPlatform {
  _FakePicker(this.content);

  final String content;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
    AndroidSAFOptions? androidSafOptions,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    return FilePickerResult([
      PlatformFile(name: 'portfolio.csv', size: bytes.length, bytes: bytes),
    ]);
  }
}

class _TestSecurityNotifier extends SecurityNotifier {
  @override
  SecurityState build() => const SecurityState();
}

class _Privacy extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

final _l10n = lookupAppLocalizations(const Locale('en'));

/// A25 review: the import screen asks about the file's date order and
/// decimal mark, reads the file with the answers, and stops on Cancel.
void main() {
  late FilePickerPlatform originalPicker;

  setUp(() => originalPicker = FilePickerPlatform.instance);
  tearDown(() => FilePickerPlatform.instance = originalPicker);

  Future<void> pickFile(WidgetTester tester, String content) async {
    FilePickerPlatform.instance = _FakePicker(content);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currencyCodeProvider.overrideWithValue('INR'),
          securityProvider.overrideWith(_TestSecurityNotifier.new),
          privacyModeProvider.overrideWith(_Privacy.new),
          allInvestmentsProvider.overrideWith((ref) => Stream.value(const [])),
          allCashFlowsStreamProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          archivedInvestmentsProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const BulkImportScreen(),
        ),
      ),
    );
    final upload = find.text(_l10n.uploadCsv);
    await tester.ensureVisible(upload);
    await tester.tap(upload);
    // The upload button spins while a question is open, so frames are
    // pumped for the dialog or the next screen instead of settling.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  ImportConfirmationScreen? confirmation(WidgetTester tester) {
    final found = find.byType(ImportConfirmationScreen);
    return found.evaluate().isEmpty
        ? null
        : tester.widget<ImportConfirmationScreen>(found);
  }

  const header = 'Date,Investment Name,Type,Amount';
  const ambiguousDates =
      '$header\n05/03/2024,A,INVEST,100\n04/02/2024,A,INVEST,200';
  const ambiguousAmounts =
      '$header\n2024-01-01,A,INVEST,"1,500"\n2024-01-02,A,INVEST,"50,00"';

  group('date order', () {
    testWidgets('month-first reads every date month-first', (tester) async {
      await pickFile(tester, ambiguousDates);

      expect(find.text(_l10n.importDateOrderTitle), findsOneWidget);
      await tester.tap(
        find.text(_l10n.importDateOrderMonthFirst('3 May 2024')),
      );
      await tester.pumpAndSettle();

      expect(
        confirmation(tester)!.parseResult.rows.map((r) => r.date).toList(),
        [DateTime(2024, 5, 3), DateTime(2024, 4, 2)],
      );
    });

    testWidgets('Cancel stops the import', (tester) async {
      await pickFile(tester, ambiguousDates);

      await tester.tap(find.text(_l10n.cancel));
      await tester.pumpAndSettle();

      expect(confirmation(tester), isNull);
      expect(find.byType(BulkImportScreen), findsOneWidget);
    });
  });

  group('decimal mark', () {
    testWidgets('a decimal comma reads 1,500 as 1.5', (tester) async {
      await pickFile(tester, ambiguousAmounts);

      expect(find.text(_l10n.importDecimalMarkTitle), findsOneWidget);
      await tester.tap(find.text(_l10n.importDecimalMarkComma));
      await tester.pumpAndSettle();

      final result = confirmation(tester)!.parseResult;
      expect(result.rows.map((r) => r.amount).toList(), [1.5, 50.0]);
      expect(result.errors, isEmpty);
    });

    testWidgets('a decimal point reads 1,500 as 1500', (tester) async {
      await pickFile(tester, ambiguousAmounts);

      await tester.tap(find.text(_l10n.importDecimalMarkPoint));
      await tester.pumpAndSettle();

      final result = confirmation(tester)!.parseResult;
      expect(result.rows.map((r) => r.amount).toList(), [1500]);
      expect(result.errors, ['Row 3: Invalid amount: 50,00']);
    });

    testWidgets('Cancel stops the import', (tester) async {
      await pickFile(tester, ambiguousAmounts);

      await tester.tap(find.text(_l10n.cancel));
      await tester.pumpAndSettle();

      expect(confirmation(tester), isNull);
    });
  });

  testWidgets('a file that settles both asks nothing', (tester) async {
    await pickFile(tester, '$header\n13/02/2024,A,INVEST,"1,00,000"');

    expect(find.byType(AlertDialog), findsNothing);
    expect(confirmation(tester)!.parseResult.rows.single.amount, 100000);
  });
}
