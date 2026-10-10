/// #959: Settings > Import from ZIP must tell the user when part of a backup
/// was skipped (`ZipImportResult.warnings`), with the count only. Warning
/// texts hold investment and goal names, so they never reach the screen
/// (money rules 7 and 8).
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
// The platform interface is the documented way to replace the picker.
// ignore: implementation_imports
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/data/providers/data_import_provider.dart';
import 'package:inv_tracker/features/settings/data/services/data_import_service.dart';
import 'package:inv_tracker/features/settings/data/services/deletion_request_service.dart';
import 'package:inv_tracker/features/settings/presentation/providers/deletion_request_status_provider.dart';
import 'package:inv_tracker/features/settings/presentation/screens/data_management_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class _FakePicker extends FilePickerPlatform {
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
    final bytes = Uint8List.fromList(const [1, 2, 3]);
    return FilePickerResult([
      PlatformFile(name: 'backup.zip', size: bytes.length, bytes: bytes),
    ]);
  }
}

/// Answers every import with [result], so the screen is tested on its own.
class _FixedImport extends ZipImportNotifier {
  _FixedImport(this.result);

  final ZipImportResult result;

  @override
  Future<ZipImportResult> importFromZip(
    Uint8List zipBytes,
    ImportStrategy strategy,
  ) async => result;
}

class _TestSecurityNotifier extends SecurityNotifier {
  @override
  SecurityState build() => const SecurityState();
}

class _Privacy extends PrivacyModeNotifier {
  _Privacy(this.on);

  final bool on;

  @override
  bool build() => on;
}

ZipImportResult _result({
  List<String> errors = const [],
  List<String> warnings = const [],
}) => ZipImportResult(
  investmentsImported: 3,
  cashflowsImported: 12,
  goalsImported: 1,
  documentsImported: 0,
  errors: errors,
  warnings: warnings,
);

void main() {
  const user = UserEntity(id: 'user-1', email: 'user@example.com');

  late FilePickerPlatform originalPicker;

  setUp(() {
    originalPicker = FilePickerPlatform.instance;
    FilePickerPlatform.instance = _FakePicker();
  });
  tearDown(() => FilePickerPlatform.instance = originalPicker);

  Future<void> importZip(
    WidgetTester tester,
    ZipImportResult result, {
    bool privacy = false,
    ImportStrategy strategy = ImportStrategy.merge,
    Brightness brightness = Brightness.light,
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(user)),
          securityProvider.overrideWith(_TestSecurityNotifier.new),
          privacyModeProvider.overrideWith(() => _Privacy(privacy)),
          deletionRequestStatusProvider.overrideWith(
            (ref) => Stream.value(DeletionRequestStatus.none),
          ),
          zipImportStateProvider.overrideWith(() => _FixedImport(result)),
        ],
        child: MaterialApp(
          theme: ThemeData(brightness: brightness),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DataManagementScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import from ZIP'));
    await tester.pumpAndSettle();
    if (strategy == ImportStrategy.replace) {
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Replace All'));
    } else {
      await tester.tap(find.text('Merge'));
    }
    await tester.pumpAndSettle();
  }

  /// Every string the snackbar shows.
  List<String> snackBarTexts(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(of: find.byType(SnackBar), matching: find.byType(Text)),
      )
      .map((text) => text.data ?? '')
      .toList();

  testWidgets('two warnings: says so, with the count and no warning text, '
      'and not the plain success message', (tester) async {
    final semantics = tester.ensureSemantics();
    await importZip(
      tester,
      _result(
        warnings: const [
          'Archived goals not imported: goals_archived.csv is invalid',
          'FIRE settings not imported: fire_settings.json is invalid',
        ],
      ),
    );

    expect(find.text('Imported with 2 warnings'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Imported with 2 warnings')).label,
      'Imported with 2 warnings\n'
      'Some items in the backup were not imported.',
    );
    expect(find.textContaining('Imported 3 investments'), findsNothing);
    expect(find.textContaining('goals_archived'), findsNothing);
    expect(find.textContaining('fire_settings'), findsNothing);
    semantics.dispose();
  });

  testWidgets('the text can be read on the warning background in both '
      'themes (4.5:1)', (tester) async {
    for (final brightness in Brightness.values) {
      await importZip(
        tester,
        _result(warnings: const ['Archived goals not imported: invalid']),
        brightness: brightness,
      );

      final background = tester
          .widget<SnackBar>(find.byType(SnackBar))
          .backgroundColor!;
      final text = DefaultTextStyle.of(
        tester.element(find.text('Imported with 1 warning')),
      ).style.color!;
      final lighter = math.max(
        background.computeLuminance(),
        text.computeLuminance(),
      );
      final darker = math.min(
        background.computeLuminance(),
        text.computeLuminance(),
      );
      expect(
        (lighter + 0.05) / (darker + 0.05),
        greaterThanOrEqualTo(4.5),
        reason: '$brightness',
      );
    }
  });

  testWidgets('one warning is singular', (tester) async {
    await importZip(
      tester,
      _result(warnings: const ['Dated values not imported: invalid']),
    );

    expect(find.text('Imported with 1 warning'), findsOneWidget);
    expect(find.textContaining('1 warnings'), findsNothing);
  });

  testWidgets('Replace says so too, because it deleted what the skipped file '
      'would have replaced', (tester) async {
    await importZip(
      tester,
      _result(warnings: const ['Archived goals not imported: invalid']),
      strategy: ImportStrategy.replace,
    );

    expect(find.text('Imported with 1 warning'), findsOneWidget);
    expect(find.textContaining('Imported 3 investments'), findsNothing);
  });

  testWidgets('no warnings: still the plain success text', (tester) async {
    await importZip(tester, _result());

    expect(
      find.text('Imported 3 investments, 12 cashflows, 1 goals, 0 documents'),
      findsOneWidget,
    );
    expect(find.textContaining('warning'), findsNothing);
  });

  testWidgets('privacy mode: the message holds no names, file names or '
      'amounts', (tester) async {
    final semantics = tester.ensureSemantics();
    await importZip(
      tester,
      _result(
        warnings: const [
          'Goal "Retirement Fund" not imported: Rs 5,00,000 target invalid',
          'Failed to import document: /data/user/0/app/files/payslip.pdf',
        ],
      ),
      privacy: true,
    );

    expect(snackBarTexts(tester), [
      'Imported with 2 warnings',
      'Some items in the backup were not imported.',
    ]);
    final label = tester
        .getSemantics(find.text('Imported with 2 warnings'))
        .label;
    for (final leaked in ['Retirement', '5,00,000', 'payslip', 'Rs']) {
      expect(label, isNot(contains(leaked)));
    }
    semantics.dispose();
  });

  testWidgets('errors still win: the errors message is shown as before', (
    tester,
  ) async {
    await importZip(
      tester,
      _result(
        errors: const ['Invalid backup'],
        warnings: const ['Archived goals not imported: invalid'],
      ),
    );

    expect(
      find.text('Import completed with errors: Invalid backup'),
      findsOneWidget,
    );
    expect(find.textContaining('warning'), findsNothing);
  });
}
