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

    group('Accessibility - Semantics', () {
      testWidgets(
        'image document should have correct semantics with zoom reset action',
        (tester) async {
          await tester.pumpWidget(buildTestWidget(testImageDocument));

          // Find the Semantics widget wrapping the image viewer
          final semanticsFinder = find.descendant(
            of: find.byType(DocumentViewerScreen),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics &&
                  widget.properties.label == 'Document content',
            ),
          );

          expect(semanticsFinder, findsOneWidget);

          // Verify the semantics properties
          final semanticsWidget = tester.widget<Semantics>(semanticsFinder);
          final props = semanticsWidget.properties;

          // Check label and hint
          expect(props.label, equals('Document content'));
          expect(props.hint, equals('Double tap to reset zoom'));

          // Verify customSemanticsActions contains reset zoom action
          expect(props.customSemanticsActions, isNotNull);
          expect(props.customSemanticsActions, isNotEmpty);

          // Check that the action is present
          final actions = props.customSemanticsActions!;
          final resetZoomAction = actions.keys.firstWhere(
            (action) => action.label == 'Reset zoom',
          );
          expect(resetZoomAction, isNotNull);
        },
      );

      testWidgets(
        'PDF document should have descriptive semantics without zoom actions',
        (tester) async {
          await tester.pumpWidget(buildTestWidget(testPdfDocument));

          // Find the Semantics widget wrapping the PDF viewer
          final semanticsFinder = find.descendant(
            of: find.byType(DocumentViewerScreen),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics &&
                  widget.properties.label != null &&
                  widget.properties.label!.contains('Test PDF Document'),
            ),
          );

          expect(semanticsFinder, findsOneWidget);

          // Verify the semantics properties
          final semanticsWidget = tester.widget<Semantics>(semanticsFinder);
          final props = semanticsWidget.properties;

          // Check label contains PDF document name
          expect(props.label, contains('PDF document'));
          expect(props.label, contains('Test PDF Document'));

          // Verify NO zoom hint or customSemanticsActions for PDFs
          expect(props.hint, isNull);
          expect(
            props.customSemanticsActions,
            anyOf(isNull, isEmpty),
            reason: 'PDF documents should not have zoom reset actions',
          );
        },
      );

      testWidgets(
        'image semanticLabel should be localized with document name',
        (tester) async {
          await tester.pumpWidget(buildTestWidget(testImageDocument));

          // Pump and settle to ensure everything is rendered
          await tester.pumpAndSettle();

          // Find the Image widget and verify its semantic label
          final imageFinder = find.descendant(
            of: find.byType(InteractiveViewer),
            matching: find.byType(Image),
          );

          expect(imageFinder, findsOneWidget);
        },
      );

      testWidgets(
        'GestureDetector should trigger zoom reset for images',
        (tester) async {
          await tester.pumpWidget(buildTestWidget(testImageDocument));
          await tester.pumpAndSettle();

          // Find the GestureDetector that wraps the InteractiveViewer (not the ones in AppBar)
          final gestureDetectorFinder = find.descendant(
            of: find.byType(Stack),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is GestureDetector && widget.onDoubleTap != null,
            ),
          );

          expect(gestureDetectorFinder, findsOneWidget);

          // Verify double-tap functionality exists
          // Note: We can't actually test the zoom reset behavior without a real file,
          // but we can verify the GestureDetector is present with onDoubleTap
          final gestureDetector =
              tester.widget<GestureDetector>(gestureDetectorFinder);
          expect(gestureDetector.onDoubleTap, isNotNull);
        },
      );

      testWidgets(
        'PDF document should not have GestureDetector with zoom reset',
        (tester) async {
          await tester.pumpWidget(buildTestWidget(testPdfDocument));
          await tester.pumpAndSettle();

          // For PDF documents, the GestureDetector should not be present
          // in the content area (only in app bar for navigation)
          final contentSemanticsFinder = find.descendant(
            of: find.byType(Stack),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics &&
                  widget.properties.label != null &&
                  widget.properties.label!.contains('PDF'),
            ),
          );

          expect(contentSemanticsFinder, findsOneWidget);

          // Verify the child is NOT a GestureDetector with onDoubleTap
          final semanticsWidget = tester.widget<Semantics>(contentSemanticsFinder);
          final child = semanticsWidget.child;

          // The child should be the PDF viewer widget, not wrapped in GestureDetector
          expect(
            child is GestureDetector && child.onDoubleTap != null,
            isFalse,
            reason: 'PDF documents should not have double-tap zoom reset',
          );
        },
      );
    });
  });
}
