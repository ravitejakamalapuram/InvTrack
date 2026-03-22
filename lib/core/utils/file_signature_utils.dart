import 'dart:typed_data';

class FileSignatureUtils {
  /// Validates that the file content (magic numbers) matches the expected extension.
  ///
  /// Returns true if the signature is valid for the extension.
  /// Returns false if there is a mismatch or if the extension is not supported
  /// (fail-secure: unknown extensions are rejected).
  static bool validateFileSignature(Uint8List bytes, String fileName) {
    if (bytes.isEmpty) return false;

    final ext = fileName.split('.').last.toLowerCase();

    switch (ext) {
      case 'pdf':
        return _isPdf(bytes);
      case 'jpg':
      case 'jpeg':
        return _isJpg(bytes);
      case 'png':
        return _isPng(bytes);
      case 'gif':
        return _isGif(bytes);
      case 'webp':
        return _isWebp(bytes);
      case 'heic':
        return _isHeic(bytes);
      case 'doc':
      case 'xls':
        return _isOldOffice(bytes);
      case 'docx':
      case 'xlsx':
        return _isZipBasedOffice(bytes);
      default:
        // Fail-secure: If we don't have a signature check for an extension, reject it.
        // This prevents extension spoofing for unsupported types.
        return false;
    }
  }

  static bool _isOldOffice(Uint8List bytes) {
    // DOC, XLS (OLE Compound File) - D0 CF 11 E0 A1 B1 1A E1
    if (bytes.length < 8) return false;
    return bytes[0] == 0xD0 &&
        bytes[1] == 0xCF &&
        bytes[2] == 0x11 &&
        bytes[3] == 0xE0 &&
        bytes[4] == 0xA1 &&
        bytes[5] == 0xB1 &&
        bytes[6] == 0x1A &&
        bytes[7] == 0xE1;
  }

  static bool _isZipBasedOffice(Uint8List bytes) {
    // DOCX, XLSX are zip files - PK.. (50 4B 03 04)
    if (bytes.length < 4) return false;
    return bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;
  }

  static bool _isPdf(Uint8List bytes) {
    // %PDF- (25 50 44 46 2D)
    if (bytes.length < 5) return false;
    return bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46 &&
        bytes[4] == 0x2D;
  }

  static bool _isJpg(Uint8List bytes) {
    // FF D8 FF
    if (bytes.length < 3) return false;
    return bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
  }

  static bool _isPng(Uint8List bytes) {
    // 89 50 4E 47 0D 0A 1A 0A
    if (bytes.length < 8) return false;
    return bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;
  }

  static bool _isGif(Uint8List bytes) {
    // GIF87a or GIF89a
    if (bytes.length < 6) return false;
    // GIF (47 49 46)
    if (bytes[0] != 0x47 || bytes[1] != 0x49 || bytes[2] != 0x46) return false;
    // 8
    if (bytes[3] != 0x38) return false;
    // 7 or 9
    if (bytes[4] != 0x37 && bytes[4] != 0x39) return false;
    // a
    if (bytes[5] != 0x61) return false;

    return true;
  }

  static bool _isWebp(Uint8List bytes) {
    // RIFF .... WEBP
    // 0-3: RIFF (52 49 46 46)
    // 8-11: WEBP (57 45 42 50)
    if (bytes.length < 12) return false;

    // RIFF
    if (bytes[0] != 0x52 ||
        bytes[1] != 0x49 ||
        bytes[2] != 0x46 ||
        bytes[3] != 0x46) {
      return false;
    }

    // WEBP
    if (bytes[8] != 0x57 ||
        bytes[9] != 0x45 ||
        bytes[10] != 0x42 ||
        bytes[11] != 0x50) {
      return false;
    }

    return true;
  }

  static bool _isHeic(Uint8List bytes) {
    // HEIC usually starts with an ftyp box.
    // 4-7: ftyp (66 74 79 70)
    // 8-11: major brand (heic, heix, heim, heis, hevc, hevm, hevs, etc.)
    // We will just check for ftyp box for now as a basic check.
    if (bytes.length < 12) return false;

    // Bytes 4-7 should be 'ftyp'
    if (bytes[4] != 0x66 ||
        bytes[5] != 0x74 ||
        bytes[6] != 0x79 ||
        bytes[7] != 0x70) {
      return false;
    }

    return true;
  }
}
