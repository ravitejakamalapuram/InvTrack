import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/settings/data/services/backup_crypto.dart';

void main() {
  const fastIterations = 1000;
  final plain = Uint8List.fromList(List.generate(300, (i) => i % 256));

  Future<Uint8List> enc(Uint8List data, [String pw = 'correct horse']) =>
      BackupCrypto.encrypt(data, pw, iterations: fastIterations);

  test('default iterations are serialized in the header', () async {
    final blob = await BackupCrypto.encrypt(plain, 'pw');
    expect(
      BackupCrypto.readIterations(blob),
      equals(BackupCrypto.defaultIterations),
    );
  });

  test('round trips and starts with the magic header', () async {
    final blob = await enc(plain);
    expect(BackupCrypto.isEncrypted(blob), isTrue);
    expect(await BackupCrypto.decrypt(blob, 'correct horse'), plain);
  });

  test('plain ZIP bytes are not detected as encrypted', () {
    expect(
      BackupCrypto.isEncrypted(Uint8List.fromList([0x50, 0x4b, 3, 4])),
      isFalse,
    );
    expect(BackupCrypto.isEncrypted(Uint8List(0)), isFalse);
  });

  test('wrong password throws BackupDecryptionException', () async {
    final blob = await enc(plain);
    expect(
      BackupCrypto.decrypt(blob, 'wrong'),
      throwsA(isA<BackupDecryptionException>()),
    );
  });

  test('tampered ciphertext fails', () async {
    final blob = await enc(plain);
    blob[BackupCrypto.headerLength + 5] ^= 1;
    expect(
      BackupCrypto.decrypt(blob, 'correct horse'),
      throwsA(isA<BackupDecryptionException>()),
    );
  });

  test('tampered header (salt) fails', () async {
    final blob = await enc(plain);
    blob[16] ^= 1; // inside the salt
    expect(
      BackupCrypto.decrypt(blob, 'correct horse'),
      throwsA(isA<BackupDecryptionException>()),
    );
  });

  test('nonce and salt are unique per call', () async {
    final a = await enc(plain);
    final b = await enc(plain);
    expect(
      a.sublist(8, BackupCrypto.headerLength),
      isNot(b.sublist(8, BackupCrypto.headerLength)),
    );
  });

  test('empty payload round trips', () async {
    final blob = await enc(Uint8List(0));
    expect(await BackupCrypto.decrypt(blob, 'correct horse'), isEmpty);
  });

  test('large payload round trips', () async {
    final big = Uint8List(2 * 1024 * 1024)..fillRange(0, 2 * 1024 * 1024, 7);
    final blob = await enc(big);
    expect(await BackupCrypto.decrypt(blob, 'correct horse'), big);
  });

  test('iterations are read from the header, not the default', () async {
    final blob = await BackupCrypto.encrypt(plain, 'pw', iterations: 1234);
    expect(BackupCrypto.readIterations(blob), 1234);
    expect(await BackupCrypto.decrypt(blob, 'pw'), plain);
  });

  test(
    'truncated or unknown-version data throws BackupFormatException',
    () async {
      final blob = await enc(plain);
      expect(
        BackupCrypto.decrypt(blob.sublist(0, 10), 'pw'),
        throwsA(isA<BackupFormatException>()),
      );
      final v2 = Uint8List.fromList(blob)..[8] = 2;
      expect(
        BackupCrypto.decrypt(v2, 'pw'),
        throwsA(isA<BackupFormatException>()),
      );
    },
  );

  test('absurd iteration count in header is rejected', () async {
    final blob = Uint8List.fromList(await enc(plain));
    ByteData.sublistView(blob).setUint32(10, 0xFFFFFFFF);
    expect(
      BackupCrypto.decrypt(blob, 'pw'),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('empty password is rejected', () {
    expect(BackupCrypto.encrypt(plain, ''), throwsArgumentError);
  });

  test('encrypt rejects out-of-range iterations', () {
    for (final n in [0, -1, BackupCrypto.maxIterations + 1]) {
      expect(
        BackupCrypto.encrypt(plain, 'pw', iterations: n),
        throwsArgumentError,
      );
    }
  });

  test('decrypt rejects an empty password', () async {
    final blob = await enc(plain);
    expect(BackupCrypto.decrypt(blob, ''), throwsArgumentError);
  });

  test('valid header but too short for a tag is a format error', () async {
    final blob = await enc(plain);
    expect(
      BackupCrypto.decrypt(
        blob.sublist(0, BackupCrypto.headerLength + 5),
        'correct horse',
      ),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('in-range changed iteration count fails authentication', () async {
    final blob = Uint8List.fromList(await enc(plain));
    ByteData.sublistView(blob).setUint32(10, fastIterations + 1);
    expect(
      BackupCrypto.decrypt(blob, 'correct horse'),
      throwsA(isA<BackupDecryptionException>()),
    );
  });

  group('password normalisation (NFKC)', () {
    // "é" typed as one code point (Android keyboards) or as e + combining
    // acute (some iOS/macOS input paths) must open the same backup.
    const composed = 'caf\u00e9 \u00fcber';
    const decomposed = 'cafe\u0301 u\u0308ber';

    test('composed and decomposed forms are the same password', () async {
      final blob = await enc(plain, composed);
      expect(await BackupCrypto.decrypt(blob, decomposed), plain);
    });

    test('compatibility forms (full-width, ligature) match', () async {
      final blob = await enc(plain, '\uff50\uff41\uff53\uff53 \ufb01x');
      expect(await BackupCrypto.decrypt(blob, 'pass fix'), plain);
    });

    test('different passwords still differ', () async {
      final blob = await enc(plain, composed);
      expect(
        BackupCrypto.decrypt(blob, 'cafe uber'),
        throwsA(isA<BackupDecryptionException>()),
      );
    });
  });

  group('background helpers', () {
    test('encryptInBackground and decryptInBackground round trip', () async {
      final blob = await BackupCrypto.encryptInBackground(
        plain,
        'pw',
        iterations: fastIterations,
      );
      expect(BackupCrypto.isEncrypted(blob), isTrue);
      expect(await BackupCrypto.decryptInBackground(blob, 'pw'), plain);
    });

    test('decryptInBackground surfaces a wrong password', () async {
      final blob = await enc(plain);
      expect(
        BackupCrypto.decryptInBackground(blob, 'nope'),
        throwsA(isA<BackupDecryptionException>()),
      );
    });
  });
}
