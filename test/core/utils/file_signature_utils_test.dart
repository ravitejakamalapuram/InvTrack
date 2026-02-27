import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/file_signature_utils.dart';

void main() {
  group('FileSignatureUtils', () {
    test('validateFileSignature returns false for empty bytes', () {
      final bytes = Uint8List(0);
      expect(FileSignatureUtils.validateFileSignature(bytes, 'file.pdf'), isFalse);
    });

    test('validates PDF signature', () {
      // %PDF-
      final validPdf = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 0x00]);
      expect(FileSignatureUtils.validateFileSignature(validPdf, 'document.pdf'), isTrue);

      final invalidPdf = Uint8List.fromList([0x00, 0x00, 0x00, 0x00, 0x00]);
      expect(FileSignatureUtils.validateFileSignature(invalidPdf, 'document.pdf'), isFalse);
    });

    test('validates JPG signature', () {
      // FF D8 FF
      final validJpg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);
      expect(FileSignatureUtils.validateFileSignature(validJpg, 'image.jpg'), isTrue);
      expect(FileSignatureUtils.validateFileSignature(validJpg, 'image.jpeg'), isTrue);

      final invalidJpg = Uint8List.fromList([0x00, 0x00, 0x00]);
      expect(FileSignatureUtils.validateFileSignature(invalidJpg, 'image.jpg'), isFalse);
    });

    test('validates PNG signature', () {
      // 89 50 4E 47 0D 0A 1A 0A
      final validPng = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      expect(FileSignatureUtils.validateFileSignature(validPng, 'image.png'), isTrue);

      final invalidPng = Uint8List.fromList([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
      expect(FileSignatureUtils.validateFileSignature(invalidPng, 'image.png'), isFalse);
    });

    test('validates GIF signature', () {
      // GIF87a
      final validGif87a = Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x37, 0x61]);
      expect(FileSignatureUtils.validateFileSignature(validGif87a, 'image.gif'), isTrue);

      // GIF89a
      final validGif89a = Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]);
      expect(FileSignatureUtils.validateFileSignature(validGif89a, 'image.gif'), isTrue);

      final invalidGif = Uint8List.fromList([0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
      expect(FileSignatureUtils.validateFileSignature(invalidGif, 'image.gif'), isFalse);
    });

    test('validates WEBP signature', () {
      // RIFF .... WEBP
      final validWebp = Uint8List.fromList([
        0x52, 0x49, 0x46, 0x46, // RIFF
        0x00, 0x00, 0x00, 0x00, // Size (dummy)
        0x57, 0x45, 0x42, 0x50  // WEBP
      ]);
      expect(FileSignatureUtils.validateFileSignature(validWebp, 'image.webp'), isTrue);

      final invalidWebp = Uint8List.fromList([
        0x52, 0x49, 0x46, 0x46,
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00
      ]);
      expect(FileSignatureUtils.validateFileSignature(invalidWebp, 'image.webp'), isFalse);
    });

    test('validates HEIC signature', () {
      // ftyp at offset 4
      final validHeic = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x18, // Size
        0x66, 0x74, 0x79, 0x70, // ftyp
        0x68, 0x65, 0x69, 0x63  // heic (brand)
      ]);
      expect(FileSignatureUtils.validateFileSignature(validHeic, 'image.heic'), isTrue);

      final invalidHeic = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x18,
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00
      ]);
      expect(FileSignatureUtils.validateFileSignature(invalidHeic, 'image.heic'), isFalse);
    });

    test('defaults to true for unknown extensions', () {
      final randomBytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);
      expect(FileSignatureUtils.validateFileSignature(randomBytes, 'file.unknown'), isTrue);
      expect(FileSignatureUtils.validateFileSignature(randomBytes, 'file.docx'), isTrue);
    });

    test('is case insensitive for extensions', () {
      final validPdf = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D]);
      expect(FileSignatureUtils.validateFileSignature(validPdf, 'DOCUMENT.PDF'), isTrue);
    });
  });
}
