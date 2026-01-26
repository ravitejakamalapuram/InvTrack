import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/document_viewer_screen.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/document_list_widget.dart';

void main() {
  late List<DocumentEntity> testDocuments;
  final now = DateTime.now();

  setUp(() {
    testDocuments = [
      DocumentEntity(
        id: 'doc-1',
        investmentId: 'inv-1',
        name: 'Bank Statement Q1',
        fileName: 'statement_q1.pdf',
        type: DocumentType.statement,
        localPath: '/path/to/statement_q1.pdf',
        mimeType: 'application/pdf',
        fileSize: 1024 * 500,
        createdAt: now,
        updatedAt: now,
      ),
      DocumentEntity(
        id: 'doc-2',
        investmentId: 'inv-1',
        name: 'Investment Receipt',
        fileName: 'receipt.jpg',
        type: DocumentType.receipt,
        localPath: '/path/to/receipt.jpg',
        mimeType: 'image/jpeg',
        fileSize: 1024 * 200,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  });

  Widget buildTestWidget({
    List<DocumentEntity> documents = const [],
    bool isReadOnly = false,
  }) {
    return ProviderScope(
      overrides: [
        documentsByInvestmentProvider(
          'inv-1',
        ).overrideWith((ref) => Stream.value(documents)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: DocumentListWidget(
            investmentId: 'inv-1',
            isReadOnly: isReadOnly,
          ),
        ),
      ),
    );
  }

  group('DocumentListWidget', () {
    group('Empty State', () {
      testWidgets('should display empty state when no documents', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget(documents: []));
        await tester.pumpAndSettle();

        expect(find.text('No documents yet'), findsOneWidget);
        expect(
          find.text('Tap + to add receipts, contracts, or statements'),
          findsOneWidget,
        );
      });

      testWidgets('should show empty state icon', (tester) async {
        await tester.pumpWidget(buildTestWidget(documents: []));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.folder_open_rounded), findsOneWidget);
      });

      testWidgets('should hide helper text in read-only mode', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(documents: [], isReadOnly: true),
        );
        await tester.pumpAndSettle();

        expect(find.text('No documents yet'), findsOneWidget);
        expect(
          find.text('Tap + to add receipts, contracts, or statements'),
          findsNothing,
        );
      });
    });

    group('Document List', () {
      testWidgets('should display list of documents', (tester) async {
        await tester.pumpWidget(buildTestWidget(documents: testDocuments));
        await tester.pumpAndSettle();

        expect(find.text('Bank Statement Q1'), findsOneWidget);
        expect(find.text('Investment Receipt'), findsOneWidget);
      });

      testWidgets('should show document type badges', (tester) async {
        await tester.pumpWidget(buildTestWidget(documents: testDocuments));
        await tester.pumpAndSettle();

        expect(find.text('Statement'), findsOneWidget);
        expect(find.text('Receipt'), findsOneWidget);
      });

      testWidgets('should show PDF icon for PDF documents', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(documents: [testDocuments.first]),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);
      });
    });

    group('Document Navigation', () {
      testWidgets('should navigate to viewer when document is tapped', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget(documents: testDocuments));
        await tester.pumpAndSettle();

        // Tap on document card
        await tester.tap(find.text('Bank Statement Q1'));
        await tester.pumpAndSettle();

        // Should navigate to document viewer
        expect(find.byType(DocumentViewerScreen), findsOneWidget);
      });
    });

    group('Read Only Mode', () {
      testWidgets('should hide swipe hint in read-only mode', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(documents: testDocuments, isReadOnly: true),
        );
        await tester.pumpAndSettle();

        // Swipe hint icon should be hidden in read-only mode
        expect(find.byIcon(Icons.swipe_rounded), findsNothing);
      });

      testWidgets('should show swipe hint in edit mode', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(documents: testDocuments, isReadOnly: false),
        );
        await tester.pumpAndSettle();

        // Swipe hint icon should be visible (one per document)
        expect(find.byIcon(Icons.swipe_rounded), findsNWidgets(2));
      });
    });
  });
}
