import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/auth/data/services/guest_backup_store.dart';
import 'package:path/path.dart' as path;

/// A05-F1 / auth-account-02: after a partial guest merge the backup is the
/// only copy of the guest data, so it must live in a file that outlasts the
/// dialog, the snackbar and the process.
void main() {
  late Directory base;
  FileGuestBackupStore newStore() => FileGuestBackupStore(() async => base);

  setUp(() => base = Directory.systemTemp.createTempSync('guest_backup'));
  tearDown(() => base.deleteSync(recursive: true));

  final zip = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 9, 8, 7]);

  test(
    'save writes the exact bytes under guest_backups and lists them',
    () async {
      final store = newStore();

      final saved = await store.save(zip);

      expect(path.dirname(saved), path.join(base.path, 'guest_backups'));
      expect(path.extension(saved), '.zip');
      expect(File(saved).readAsBytesSync(), zip);
      expect(await store.list(), [saved]);
      expect(
        Directory(path.join(base.path, 'guest_backups')).listSync(),
        hasLength(1),
        reason: 'no temporary .part file may be left behind',
      );
    },
  );

  test(
    'a backup is still there for a new store, as after process death',
    () async {
      final saved = await newStore().save(zip);

      final afterRestart = newStore();

      expect(await afterRestart.list(), [saved]);
      expect(File(saved).readAsBytesSync(), zip);
    },
  );

  test('delete removes only that backup', () async {
    final store = newStore();
    final first = await store.save(zip);
    final second = await store.save(Uint8List.fromList([1, 2, 3]));

    await store.delete(first);

    expect(await store.list(), [second]);
  });

  test('delete ignores files the store did not write', () async {
    final store = newStore();
    final outside = File(path.join(base.path, 'other.zip'))
      ..writeAsBytesSync(zip);

    await store.delete(outside.path);

    expect(outside.existsSync(), isTrue);
  });

  test('deleteAll removes every backup', () async {
    final store = newStore();
    await store.save(zip);
    await store.save(zip);

    await store.deleteAll();

    expect(await store.list(), isEmpty);
  });

  test('list is empty before anything was saved', () async {
    expect(await newStore().list(), isEmpty);
  });
}
