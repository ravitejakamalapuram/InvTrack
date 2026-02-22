import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class SecurityUtils {
  /// Hashes a PIN using PBKDF2-HMAC-SHA256.
  ///
  /// Returns a string in the format: `salt:iterations:hash`
  ///
  /// [pin] The PIN to hash.
  /// [salt] The salt to use (should be random and unique per user).
  /// [iterations] The number of iterations (default 100,000).
  ///
  /// **Security Note:**
  /// OWASP recommends 600,000 iterations for PBKDF2-HMAC-SHA256 (as of 2023).
  /// However, due to performance constraints of pure Dart implementation on mobile devices,
  /// we default to 100,000 iterations which provides a balance between security and UX (~1s on older devices).
  ///
  /// [keyLength] The length of the derived key in bytes (default 32 for SHA-256).
  static String hashPin(
    String pin,
    String salt, {
    int iterations = 100000,
    int keyLength = 32,
  }) {
    final key = _pbkdf2(
      utf8.encode(pin),
      utf8.encode(salt),
      iterations,
      keyLength,
    );
    return '$salt:$iterations:${base64.encode(key)}';
  }

  /// Verifies a PIN against a stored hash.
  ///
  /// Supports v3 format: `salt:iterations:hash`
  ///
  /// Returns true if the PIN matches the stored hash.
  static bool verifyPin(String pin, String storedHash) {
    final parts = storedHash.split(':');
    if (parts.length != 3) {
      return false; // Not v3 format
    }

    final salt = parts[0];
    final iterations = int.tryParse(parts[1]);
    final expectedHash = parts[2];

    if (iterations == null) return false;

    final key = _pbkdf2(
      utf8.encode(pin),
      utf8.encode(salt),
      iterations,
      32, // Assuming 32 bytes for SHA-256
    );

    final actualHash = base64.encode(key);
    return constantTimeEquals(actualHash, expectedHash);
  }

  /// Compares two strings in constant time to prevent timing attacks.
  ///
  /// This avoids the early-exit optimization of standard string comparison,
  /// ensuring that the comparison time depends only on the length of the strings,
  /// not on how many characters match.
  static bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) {
      return false;
    }

    final aUnits = a.codeUnits;
    final bUnits = b.codeUnits;
    var result = 0;

    for (var i = 0; i < aUnits.length; i++) {
      result |= aUnits[i] ^ bUnits[i];
    }

    return result == 0;
  }

  /// PBKDF2 implementation using HMAC-SHA256.
  static Uint8List _pbkdf2(
    List<int> password,
    List<int> salt,
    int iterations,
    int keyLength,
  ) {
    final hmac = Hmac(sha256, password);
    final derivedKey = Uint8List(keyLength);
    // SHA-256 block size is 64 bytes, but output size is 32 bytes.
    // Wait, hmac.convert([]).bytes.length returns the output size of the hash function?
    // Yes, for SHA-256 it's 32 bytes (256 bits).
    final hashLength = 32;
    final numberOfBlocks = (keyLength / hashLength).ceil();

    for (var i = 1; i <= numberOfBlocks; i++) {
      var block = _computeBlock(hmac, salt, iterations, i, hashLength);
      var offset = (i - 1) * hashLength;
      var copyLength = (offset + hashLength > keyLength)
          ? keyLength - offset
          : hashLength;
      derivedKey.setRange(offset, offset + copyLength, block.take(copyLength));
    }

    return derivedKey;
  }

  static Uint8List _computeBlock(
    Hmac hmac,
    List<int> salt,
    int iterations,
    int blockIndex,
    int hashLength,
  ) {
    // F(P, S, c, i) = U1 ^ U2 ^ ... ^ Uc
    // U1 = PRF(P, S || INT_32_BE(i))

    // Construct S || INT_32_BE(i)
    final initialInput = [...salt, ..._intToBytes(blockIndex)];
    var u = hmac.convert(initialInput).bytes;
    var block = Uint8List.fromList(u);

    for (var j = 1; j < iterations; j++) {
      u = hmac.convert(u).bytes;
      for (var k = 0; k < block.length; k++) {
        block[k] ^= u[k];
      }
    }

    return block;
  }

  static List<int> _intToBytes(int i) {
    return [
      (i >> 24) & 0xff,
      (i >> 16) & 0xff,
      (i >> 8) & 0xff,
      i & 0xff,
    ];
  }
}
