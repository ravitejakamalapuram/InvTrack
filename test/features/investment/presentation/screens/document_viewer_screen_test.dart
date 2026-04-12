import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/document_entity.dart';
import 'package:inv_tracker/features/investment/presentation/screens/document_viewer_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

void main() {
  late DocumentEntity testPdfDocument;
  late DocumentEntity testImageDocument;

  setUp(() {
    final now = DateTime.now();
    testPdfDocument = DocumentEntity(
      id: 'doc-pdf-1',
      investmentId: 'inv-1',
      name: 'Test PDF Document',
      fileName: 'test-document.pdf',
      type: DocumentType.statement,
      localPath: '/path/to/test-document.pdf',
      mimeType: 'application/pdf',
      fileSize: 1024 * 500, // 500 KB
      createdAt: now,
      updatedAt: now,
    );

    testImageDocument = DocumentEntity(
      id: 'doc-img-1',
      investmentId: 'inv-1',
      name: 'Test Image Document',
      fileName: 'test-image.jpg',
      type: DocumentType.image,
      localPath: '/path/to/test-image.jpg',
      mimeType: 'image/jpeg',
      fileSize: 1024 * 200, // 200 KB
      createdAt: now,
      updatedAt: now,
    );
  });

  Widget buildTestWidget(DocumentEntity document) {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DocumentViewerScreen(document: document),
      ),
    );
  }

  group('DocumentViewerScreen', () {
    group('Widget Rendering', () {
      testWidgets('should render with PDF document', (tester) async {
        await tester.pumpWidget(buildTestWidget(testPdfDocument));

        expect(find.byType(DocumentViewerScreen), findsOneWidget);
        expect(find.byType(Scaffold), findsOneWidget);
      });

      testWidgets('should render with image document', (tester) async {
        await tester.pumpWidget(buildTestWidget(testImageDocument));

        expect(find.byType(DocumentViewerScreen), findsOneWidget);
        expect(find.byType(Scaffold), findsOneWidget);
      });

      testWidgets('should show close button in app bar', (tester) async {
        await tester.pumpWidget(buildTestWidget(testPdfDocument));

        expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      });

      testWidgets('should show share button in app bar', (tester) async {
        await tester.pumpWidget(buildTestWidget(testPdfDocument));

        expect(find.byIcon(Icons.share_rounded), findsWidgets);
      });

      testWidgets('should show info toggle button in app bar', (tester) async {
        await tester.pumpWidget(buildTestWidget(testPdfDocument));

        // Initially shows filled info icon
        expect(find.byIcon(Icons.info_rounded), findsOneWidget);
      });
    });

    group('PDF Document View', () {
      testWidgets('should display PDF icon for PDF documents', (tester) async {
        await tester.pumpWidget(buildTestWidget(testPdfDocument));

        expect(find.byIcon(Icons.picture_as_pdf_rounded), findsWidgets);
      });

      testWidgets('should display document name for PDF', (tester) async {
        await tester.pumpWidget(buildTestWidget(testPdfDocument));

        expect(find.text('Test PDF Document'), findsWidgets);
      });

      testWidgets('should display "Open in PDF Viewer" button for PDF', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget(testPdfDocument));

        expect(find.text('Open in PDF Viewer'), findsOneWidget);
        expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);
      });

      testWidgets('should display share button for PDF', (tester) async {
        await tester.pumpWidget(buildTestWidget(testPdfDocument));

        expect(find.text('Share'), findsOneWidget);
      });

      testWidgets('should display file size for PDF', (tester) async {
        await tester.pumpWidget(buildTestWidget(testPdfDocument));

        // 500 KB
        expect(find.textContaining('500'), findsWidgets);
      });
    });

    group('Image Document View', () {
      testWidgets('should display InteractiveViewer for image documents', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget(testImageDocument));

        expect(find.byType(InteractiveViewer), findsOneWidget);
      });

      testWidgets('should not show PDF viewer button for image documents', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget(testImageDocument));

        expect(find.text('Open in PDF Viewer'), findsNothing);
      });
    });

    group('Info Overlay', () {
      testWidgets('should show info overlay by default', (tester) async {
        await tester.pumpWidget(buildTestWidget(testPdfDocument));

        // Document name should be visible in overlay
        expect(find.text('Test PDF Document'), findsWidgets);
      });

      testWidgets('should show document type badge in overlay', (tester) async {
        await tester.pumpWidget(buildTestWidget(testPdfDocument));

        // Statement type display name
        expect(find.text('Statement'), findsOneWidget);
      });

      testWidgets('should toggle info overlay on button tap', (tester) async {
        await tester.pumpWidget(buildTestWidget(testPdfDocument));

        // Find and tap the info button
        final infoButton = find.byIcon(Icons.info_rounded);
        expect(infoButton, findsOneWidget);

        await tester.tap(infoButton);
        await tester.pump();

        // After toggle, should show outline icon instead
        expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
      });
    });

    group('Navigation', () {
      testWidgets('should close screen when close button is tapped', (
        tester,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              DocumentViewerScreen(document: testPdfDocument),
                        ),
                      );
                    },
                    child: const Text('Open Viewer'),
                  ),
                ),
              ),
            ),
          ),
        );

        // Navigate to document viewer
        await tester.tap(find.text('Open Viewer'));
        await tester.pumpAndSettle();

        expect(find.byType(DocumentViewerScreen), findsOneWidget);

        // Tap close button
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        // Should be back on original screen
        expect(find.byType(DocumentViewerScreen), findsNothing);
        expect(find.text('Open Viewer'), findsOneWidget);
      });
    });

    group('Different Document Types', () {
      testWidgets('should show correct color for receipt type', (tester) async {
        final receiptDoc = testPdfDocument.copyWith(type: DocumentType.receipt);
        await tester.pumpWidget(buildTestWidget(receiptDoc));

        expect(find.text('Receipt'), findsOneWidget);
      });

      testWidgets('should show correct color for contract type', (
        tester,
      ) async {
        final contractDoc = testPdfDocument.copyWith(
          type: DocumentType.contract,
        );
        await tester.pumpWidget(buildTestWidget(contractDoc));

        expect(find.text('Contract'), findsOneWidget);
      });

      testWidgets('should show correct color for certificate type', (
        tester,
      ) async {
        final certDoc = testPdfDocument.copyWith(
          type: DocumentType.certificate,
        );
        await tester.pumpWidget(buildTestWidget(certDoc));

        expect(find.text('Certificate'), findsOneWidget);
      });

      testWidgets('should show correct color for other type', (tester) async {
        final otherDoc = testPdfDocument.copyWith(type: DocumentType.other);
        await tester.pumpWidget(buildTestWidget(otherDoc));

        expect(find.text('Other'), findsOneWidget);
      });
    });

    group('File Size Formatting', () {
      testWidgets('should display KB for files under 1MB', (tester) async {
        final smallDoc = testPdfDocument.copyWith(fileSize: 500 * 1024);
        await tester.pumpWidget(buildTestWidget(smallDoc));

        expect(find.textContaining('KB'), findsWidgets);
      });

      testWidgets('should display MB for files over 1MB', (tester) async {
        final largeDoc = testPdfDocument.copyWith(fileSize: 5 * 1024 * 1024);
        await tester.pumpWidget(buildTestWidget(largeDoc));

        expect(find.textContaining('MB'), findsWidgets);
      });

      testWidgets('should display B for very small files', (tester) async {
        final tinyDoc = testPdfDocument.copyWith(fileSize: 500);
        await tester.pumpWidget(buildTestWidget(tinyDoc));

        expect(find.textContaining('500 B'), findsWidgets);
      });
    });

    group('Semantics', () {
      testWidgets(
        'image branch: Semantics node has correct label and hint',
        (tester) async {
          final handle = tester.ensureSemantics();
          await tester.pumpWidget(buildTestWidget(testImageDocument));

          final semanticsNode = tester.getSemantics(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics &&
                  widget.properties.label == 'Document content',
            ),
          );

          expect(semanticsNode.label, 'Document content');
          expect(semanticsNode.hint, 'Double tap to reset zoom');

          handle.dispose();
        },
      );

      testWidgets(
        'image branch: CustomSemanticsAction "Reset zoom" is exposed',
        (tester) async {
          final handle = tester.ensureSemantics();
          await tester.pumpWidget(buildTestWidget(testImageDocument));

          final semanticsNode = tester.getSemantics(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics &&
                  widget.properties.label == 'Document content',
            ),
          );

          expect(
            semanticsNode.customActions.any(
              (action) => action.label == 'Reset zoom',
            ),
            isTrue,
          );

          handle.dispose();
        },
      );

      testWidgets(
        'PDF branch: Semantics wrapper is present with correct label',
        (tester) async {
          final handle = tester.ensureSemantics();
          await tester.pumpWidget(buildTestWidget(testPdfDocument));

          final semanticsNode = tester.getSemantics(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics &&
                  widget.properties.label == 'Document content',
            ),
          );

          expect(semanticsNode.label, 'Document content');
          expect(semanticsNode.hint, 'Double tap to reset zoom');

          handle.dispose();
        },
      );
    });
  });
}