import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// The password is wrong or the data was modified (indistinguishable by design).
class BackupDecryptionException implements Exception {
  const BackupDecryptionException();
  @override
  String toString() =>
      'BackupDecryptionException: wrong password or corrupted backup';
}

/// The bytes are not a supported encrypted backup (truncated, bad header, unknown version).
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;
  @override
  String toString() => 'BackupFormatException: $message';
}

/// Password-based AES-256-GCM container for backup ZIP bytes.
///
/// Layout (big-endian): magic(8) | version(1) | kdf(1) | iterations(4) |
/// salt(16) | nonce(12) | ciphertext | tag(16). The header is the GCM AAD.
/// KDF id 1 = PBKDF2-HMAC-SHA256.
abstract final class BackupCrypto {
  static const defaultIterations = 600000;
  static const maxIterations = 10000000;
  static const headerLength = 42;

  static const _magic = [0x49, 0x4E, 0x56, 0x45, 0x4E, 0x43, 0x31, 0x00];
  static const _version = 1;
  static const _kdfPbkdf2Sha256 = 1;
  static const _saltLength = 16;
  static const _tagLength = 16;
  static const _iterationsOffset = 10;
  static const _saltOffset = 14;
  static const _nonceOffset = 30;

  static final _cipher = AesGcm.with256bits();

  static bool isEncrypted(Uint8List data) {
    if (data.length < _magic.length) return false;
    for (var i = 0; i < _magic.length; i++) {
      if (data[i] != _magic[i]) return false;
    }
    return true;
  }

  /// Iteration count stored in the header of [data].
  static int readIterations(Uint8List data) {
    _checkHeader(data);
    return ByteData.sublistView(data).getUint32(_iterationsOffset);
  }

  static Future<Uint8List> encrypt(
    Uint8List plain,
    String password, {
    int iterations = defaultIterations,
  }) async {
    if (password.isEmpty) throw ArgumentError('password must not be empty');
    final header = Uint8List(headerLength)
      ..setRange(0, _magic.length, _magic)
      ..[8] = _version
      ..[9] = _kdfPbkdf2Sha256;
    ByteData.sublistView(header).setUint32(_iterationsOffset, iterations);
    final random = Random.secure();
    for (var i = 0; i < _saltLength; i++) {
      header[_saltOffset + i] = random.nextInt(256);
    }
    header.setRange(_nonceOffset, headerLength, _cipher.newNonce());

    final box = await _cipher.encrypt(
      plain,
      secretKey: await _deriveKey(password, header, iterations),
      nonce: header.sublist(_nonceOffset),
      aad: header,
    );
    return Uint8List.fromList([...header, ...box.cipherText, ...box.mac.bytes]);
  }

  static Future<Uint8List> decrypt(Uint8List data, String password) async {
    _checkHeader(data);
    if (data.length < headerLength + _tagLength) {
      throw const BackupFormatException('truncated backup');
    }
    final header = data.sublist(0, headerLength);
    final iterations = ByteData.sublistView(data).getUint32(_iterationsOffset);
    final box = SecretBox(
      data.sublist(headerLength, data.length - _tagLength),
      nonce: header.sublist(_nonceOffset),
      mac: Mac(data.sublist(data.length - _tagLength)),
    );
    try {
      final key = await _deriveKey(password, header, iterations);
      return Uint8List.fromList(
        await _cipher.decrypt(box, secretKey: key, aad: header),
      );
    } on SecretBoxAuthenticationError {
      throw const BackupDecryptionException();
    }
  }

  static void _checkHeader(Uint8List data) {
    if (data.length < headerLength || !isEncrypted(data)) {
      throw const BackupFormatException('not an encrypted backup');
    }
    if (data[8] != _version || data[9] != _kdfPbkdf2Sha256) {
      throw const BackupFormatException('unsupported version or KDF');
    }
    final iterations = ByteData.sublistView(data).getUint32(_iterationsOffset);
    if (iterations < 1 || iterations > maxIterations) {
      throw const BackupFormatException('invalid iteration count');
    }
  }

  static Future<SecretKey> _deriveKey(
    String password,
    Uint8List header,
    int iterations,
  ) => Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256)
      .deriveKeyFromPassword(
        password: password,
        nonce: header.sublist(_saltOffset, _saltOffset + _saltLength),
      );
}
