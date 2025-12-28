import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/document_entity.dart';

void main() {
  group('DocumentType', () {
    group('displayName', () {
      test('statement should have correct display name', () {
        expect(DocumentType.statement.displayName, 'Statement');
      });

      test('receipt should have correct display name', () {
        expect(DocumentType.receipt.displayName, 'Receipt');
      });

      test('contract should have correct display name', () {
        expect(DocumentType.contract.displayName, 'Contract');
      });

      test('certificate should have correct display name', () {
        expect(DocumentType.certificate.displayName, 'Certificate');
      });

      test('image should have correct display name', () {
        expect(DocumentType.image.displayName, 'Image');
      });

      test('other should have correct display name', () {
        expect(DocumentType.other.displayName, 'Other');
      });
    });

    group('fromString', () {
      test('should parse statement', () {
        expect(DocumentType.fromString('statement'), DocumentType.statement);
      });

      test('should parse receipt', () {
        expect(DocumentType.fromString('receipt'), DocumentType.receipt);
      });

      test('should parse contract', () {
        expect(DocumentType.fromString('contract'), DocumentType.contract);
      });

      test('should parse certificate', () {
        expect(
          DocumentType.fromString('certificate'),
          DocumentType.certificate,
        );
      });

      test('should default to other for unknown values', () {
        expect(DocumentType.fromString('unknown'), DocumentType.other);
      });

      test('should default to other for wrong case', () {
        // Current implementation uses exact enum name matching
        expect(DocumentType.fromString('STATEMENT'), DocumentType.other);
        expect(DocumentType.fromString('Statement'), DocumentType.other);
      });
    });
  });

  group('DocumentMimeTypes', () {
    group('isSupported', () {
      test('should support PDF files', () {
        expect(DocumentMimeTypes.isSupported('document.pdf'), true);
        expect(DocumentMimeTypes.isSupported('document.PDF'), true);
      });

      test('should support JPG files', () {
        expect(DocumentMimeTypes.isSupported('image.jpg'), true);
        expect(DocumentMimeTypes.isSupported('image.jpeg'), true);
        expect(DocumentMimeTypes.isSupported('image.JPG'), true);
      });

      test('should support PNG files', () {
        expect(DocumentMimeTypes.isSupported('image.png'), true);
        expect(DocumentMimeTypes.isSupported('image.PNG'), true);
      });

      test('should support GIF files', () {
        expect(DocumentMimeTypes.isSupported('image.gif'), true);
      });

      test('should support WEBP files', () {
        expect(DocumentMimeTypes.isSupported('image.webp'), true);
      });

      test('should not support unsupported extensions', () {
        expect(DocumentMimeTypes.isSupported('document.doc'), false);
        expect(DocumentMimeTypes.isSupported('document.txt'), false);
        expect(DocumentMimeTypes.isSupported('archive.zip'), false);
      });
    });

    group('isImage', () {
      test('should identify images by file extension', () {
        expect(DocumentMimeTypes.isImage('photo.jpg'), true);
        expect(DocumentMimeTypes.isImage('photo.jpeg'), true);
        expect(DocumentMimeTypes.isImage('image.png'), true);
        expect(DocumentMimeTypes.isImage('animation.gif'), true);
        expect(DocumentMimeTypes.isImage('modern.webp'), true);
      });

      test('should not identify non-images', () {
        expect(DocumentMimeTypes.isImage('document.pdf'), false);
        expect(DocumentMimeTypes.isImage('file.txt'), false);
      });
    });

    group('isPdf', () {
      test('should identify PDF by file extension', () {
        expect(DocumentMimeTypes.isPdf('document.pdf'), true);
        expect(DocumentMimeTypes.isPdf('DOCUMENT.PDF'), true);
      });

      test('should not identify non-PDFs', () {
        expect(DocumentMimeTypes.isPdf('image.jpg'), false);
      });
    });
  });

  group('DocumentEntity', () {
    test('copyWith should create copy with updated fields', () {
      final now = DateTime.now();
      final original = DocumentEntity(
        id: 'doc-1',
        investmentId: 'inv-1',
        name: 'Original',
        fileName: 'original.pdf',
        type: DocumentType.statement,
        localPath: '/path/to/original.pdf',
        mimeType: 'application/pdf',
        fileSize: 1024,
        createdAt: now,
        updatedAt: now,
      );

      final copy = original.copyWith(
        name: 'Updated',
        type: DocumentType.receipt,
      );

      expect(copy.id, 'doc-1');
      expect(copy.investmentId, 'inv-1');
      expect(copy.name, 'Updated');
      expect(copy.type, DocumentType.receipt);
      expect(copy.fileName, 'original.pdf');
    });

    test('isImage should return true for image mime types', () {
      final imageDoc = DocumentEntity(
        id: 'doc-1',
        investmentId: 'inv-1',
        name: 'Image',
        fileName: 'image.jpg',
        type: DocumentType.other,
        localPath: '/path/to/image.jpg',
        mimeType: 'image/jpeg',
        fileSize: 1024,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(imageDoc.isImage, true);
    });
  });
}
