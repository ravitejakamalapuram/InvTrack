// A document type's colour is painted as text and as an icon on a pale tint of
// itself in the document list, the document viewer, and the add-document sheet
// (the chip of each file and the type picker), and a template's colour on the
// selected card of the quick-start row. The audit never judged them: the amber
// of a statement and the emerald of a receipt are 2:1 to 3:1 on their own tint.
//
// The real widgets are pumped here for every type, in both themes, and what
// they painted is measured:
//
//  - a type name on its chip reaches 4.5:1, an icon on its tile or chip 3:1;
//  - the name and the icon are still shown, so the type never rests on colour.
import 'dart:io';

import 'package:file_picker/file_picker.dart';
// The platform interface is the documented way to replace the picker.
// ignore: implementation_imports
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_theme.dart';
import 'package:inv_tracker/features/investment/domain/models/investment_template.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/document_viewer_screen.dart';
import 'package:inv_tracker/features/investment/presentation/ui_extensions/investment_ui.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/add_document_sheet.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/document_list_widget.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/template_selector.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/contrast.dart';
import '../../../../mocks/mock_security_service.dart';

ThemeData _theme(Brightness b) =>
    b == Brightness.dark ? AppTheme.darkTheme : AppTheme.lightTheme;

/// The plain colour of the nearest Container or Ink around [of] that has one,
/// composed over [ground] the way it is painted.
Color _fillBehind(Finder of, Color ground) {
  final containers = find.ancestor(
    of: of,
    matching: find.byWidgetPredicate((w) => w is Container || w is Ink),
  );
  for (final element in containers.evaluate()) {
    final widget = element.widget;
    final decoration = widget is Container
        ? widget.decoration
        : (widget as Ink).decoration;
    if (decoration is BoxDecoration && decoration.color != null) {
      return composeOver(decoration.color!, ground);
    }
  }
  return ground;
}

DocumentEntity _document(DocumentType type) => DocumentEntity(
  id: 'doc-${type.name}',
  investmentId: 'inv-1',
  name: 'Demo ${type.name}',
  fileName: 'demo.pdf',
  type: type,
  localPath: '/demo/demo.pdf',
  mimeType: 'application/pdf',
  fileSize: 2048,
  createdAt: DateTime(2025, 1, 1),
  updatedAt: DateTime(2025, 1, 1),
);

class _FakePicker extends FilePickerPlatform {
  _FakePicker(this.paths);

  final List<String> paths;

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
  }) async => FilePickerResult([
    for (final p in paths)
      PlatformFile(name: p.split('/').last, path: p, size: 4),
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  for (final brightness in Brightness.values) {
    final theme = brightness.name;
    final dark = brightness == Brightness.dark;
    final tileGround = dark ? AppColors.surfaceDark : Colors.white;

    group('the document list in $theme', () {
      for (final type in DocumentType.values) {
        testWidgets('${type.name}: the type name and icon are readable', (
          tester,
        ) async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                documentsByInvestmentProvider(
                  'inv-1',
                ).overrideWith((ref) => Stream.value([_document(type)])),
              ],
              child: MaterialApp(
                theme: _theme(brightness),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const Scaffold(
                  body: DocumentListWidget(investmentId: 'inv-1'),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final name = find.text(type.displayName);
          expect(name, findsOneWidget);
          final pill = _fillBehind(name, tileGround);
          final ratio = contrastRatio(
            tester.widget<Text>(name).style!.color!,
            pill,
          );
          expect(
            ratio,
            greaterThanOrEqualTo(kMinText),
            reason: 'doc-${type.name}-$theme: the list pill is $ratio',
          );

          final glyph = find.byIcon(Icons.picture_as_pdf_rounded);
          expect(glyph, findsOneWidget);
          final tile = _fillBehind(glyph, tileGround);
          final iconRatio = contrastRatio(
            tester.widget<Icon>(glyph).color!,
            tile,
          );
          expect(
            iconRatio,
            greaterThanOrEqualTo(kMinGraphic),
            reason: 'doc-${type.name}-$theme: the list icon is $iconRatio',
          );
        });
      }
    });

    group('the document viewer in $theme', () {
      for (final type in DocumentType.values) {
        testWidgets('${type.name}: the type pill is readable on the dark '
            'overlay', (tester) async {
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: _theme(brightness),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: DocumentViewerScreen(document: _document(type)),
              ),
            ),
          );
          await tester.pump();

          // The overlay is black at 80% over the picture, in either theme, so
          // the pill is judged over black.
          final name = find.text(type.displayName);
          expect(name, findsOneWidget);
          final pill = _fillBehind(name, Colors.black);
          final ratio = contrastRatio(
            tester.widget<Text>(name).style!.color!,
            pill,
          );
          expect(
            ratio,
            greaterThanOrEqualTo(kMinText),
            reason: 'doc-${type.name}-$theme: the viewer pill is $ratio',
          );
          final glyph = find.descendant(
            of: find.ancestor(of: name, matching: find.byType(Row)).first,
            matching: find.byIcon(type.icon),
          );
          expect(glyph, findsOneWidget);
          final iconRatio = contrastRatio(
            tester.widget<Icon>(glyph).color!,
            pill,
          );
          expect(
            iconRatio,
            greaterThanOrEqualTo(kMinGraphic),
            reason: 'doc-${type.name}-$theme: the viewer icon is $iconRatio',
          );
        });
      }
    });

    group('the add-document sheet in $theme', () {
      late Directory dir;
      late SharedPreferences prefs;
      late FilePickerPlatform originalPicker;

      setUpAll(() => originalPicker = FilePickerPlatform.instance);

      setUp(() async {
        dir = Directory.systemTemp.createTempSync('doc_contrast_');
        File('${dir.path}/a.pdf').writeAsBytesSync([1, 2, 3, 4]);
        File('${dir.path}/b.pdf').writeAsBytesSync([1, 2, 3, 4]);
        SharedPreferences.setMockInitialValues({});
        prefs = await SharedPreferences.getInstance();
      });

      tearDown(() {
        dir.deleteSync(recursive: true);
        FilePickerPlatform.instance = originalPicker;
      });

      testWidgets('each file chip and the type picker are readable for every '
          'type', (tester) async {
        tester.view.physicalSize = const Size(1000, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        FilePickerPlatform.instance = _FakePicker([
          '${dir.path}/a.pdf',
          '${dir.path}/b.pdf',
        ]);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              flutterSecureStorageProvider.overrideWithValue(
                FakeFlutterSecureStorage(),
              ),
              localAuthProvider.overrideWithValue(FakeLocalAuthentication()),
            ],
            child: MaterialApp(
              theme: _theme(brightness),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(
                body: AddDocumentSheet(investmentId: 'inv-1'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.runAsync(() async {
          await tester.tap(find.text('Select Files'));
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });
        await tester.pumpAndSettle();
        expect(find.text('2 files selected'), findsOneWidget);

        // Both files start as a receipt; the first file's chip is the first
        // text of its type in the list.
        var current = DocumentType.receipt;
        final inSheet = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Text),
        );
        expect(inSheet, findsNothing);

        for (final type in DocumentType.values) {
          // Open the picker of the first file and choose [type].
          await tester.tap(find.text(current.displayName).first);
          await tester.pumpAndSettle();
          await tester.tap(
            find.descendant(
              of: find.byType(BottomSheet),
              matching: find.text(type.displayName),
            ),
          );
          await tester.pumpAndSettle();
          current = type;

          final name = find.text(type.displayName).first;
          final chip = _fillBehind(name, tileGround);
          final ratio = contrastRatio(
            tester.widget<Text>(name).style!.color!,
            chip,
          );
          expect(
            ratio,
            greaterThanOrEqualTo(kMinText),
            reason: 'doc-${type.name}-$theme: the file chip is $ratio',
          );
          final arrow = find.descendant(
            of: find.ancestor(of: name, matching: find.byType(Row)).first,
            matching: find.byIcon(Icons.arrow_drop_down),
          );
          expect(arrow, findsOneWidget);
          expect(
            contrastRatio(tester.widget<Icon>(arrow).color!, chip),
            greaterThanOrEqualTo(kMinGraphic),
            reason: 'doc-${type.name}-$theme: the chip arrow',
          );

          // Open it again: [type] is the selected option.
          await tester.tap(name);
          await tester.pumpAndSettle();
          final option = find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text(type.displayName),
          );
          expect(option, findsOneWidget);
          final fill = _fillBehind(option, tileGround);
          expect(
            contrastRatio(tester.widget<Text>(option).style!.color!, fill),
            greaterThanOrEqualTo(kMinText),
            reason: 'doc-${type.name}-$theme: the selected option',
          );
          final glyph = find.descendant(
            of: find.byType(BottomSheet),
            matching: find.byIcon(type.icon),
          );
          expect(glyph, findsOneWidget);
          expect(
            contrastRatio(tester.widget<Icon>(glyph).color!, fill),
            greaterThanOrEqualTo(kMinGraphic),
            reason: 'doc-${type.name}-$theme: the selected option icon',
          );
          // Close it by choosing the same type.
          await tester.tap(option);
          await tester.pumpAndSettle();
        }
      });
    });

    group('the quick-start templates in $theme', () {
      for (final template in InvestmentTemplates.all) {
        testWidgets('${template.id}: the selected card name is readable', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(2400, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              theme: _theme(brightness),
              home: Scaffold(
                body: TemplateSelector(
                  selectedTemplate: template,
                  onTemplateSelected: (_) {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final name = find.text(template.name);
          expect(name, findsOneWidget);
          final card = _fillBehind(
            name,
            dark ? AppColors.backgroundDark : AppColors.backgroundLight,
          );
          final ratio = contrastRatio(
            tester.widget<Text>(name).style!.color!,
            card,
          );
          expect(
            ratio,
            greaterThanOrEqualTo(kMinText),
            reason: 'template-${template.id}-$theme: the name is $ratio',
          );
          // The name and the emoji are still shown beside the colour.
          expect(find.text(template.emoji), findsOneWidget);
        });
      }
    });
  }
}
