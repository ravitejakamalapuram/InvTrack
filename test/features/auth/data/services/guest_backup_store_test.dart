import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/auth/data/services/guest_backup_store.dart';
import 'package:path/path.dart' as path;

/// A05-F1 / auth-account-02: after a partial guest merge the backup is the
/// only copy of the guest data, so it must live in a file that outlasts the
/// dialog, the snackbar and the process. It holds one person's financial
/// data, so it belongs to one account and no other account on the device may
/// see it.
void main() {
  late Directory base;
  FileGuestBackupStore newStore() => FileGuestBackupStore(() async => base);

  setUp(() => base = Directory.systemTemp.createTempSync('guest_backup'));
  tearDown(() => base.deleteSync(recursive: true));

  final zip = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 9, 8, 7]);
  const owner = 'uidA';
  const other = 'uidB';

  test(
    "save writes the exact bytes in the owner's folder and lists them",
    () async {
      final store = newStore();

      final saved = await store.save(zip, ownerId: owner);

      expect(path.dirname(saved), path.join(base.path, 'guest_backups', owner));
      expect(path.extension(saved), '.zip');
      expect(File(saved).readAsBytesSync(), zip);
      expect(await store.list(ownerId: owner), [saved]);
      expect(
        Directory(path.join(base.path, 'guest_backups', owner)).listSync(),
        hasLength(1),
        reason: 'no temporary .part file may be left behind',
      );
    },
  );

  test(
    'a backup is still there for a new store, as after process death',
    () async {
      final saved = await newStore().save(zip, ownerId: owner);

      final afterRestart = newStore();

      expect(await afterRestart.list(ownerId: owner), [saved]);
      expect(File(saved).readAsBytesSync(), zip);
    },
  );

  test("another account does not see the owner's backups", () async {
    final store = newStore();
    await store.save(zip, ownerId: owner);

    expect(await store.list(ownerId: other), isEmpty);
  });

  test('transfer moves a backup to the new owner only', () async {
    final store = newStore();
    final saved = await store.save(zip, ownerId: owner);

    final moved = await store.transfer(saved, toOwnerId: other);

    expect(await store.list(ownerId: owner), isEmpty);
    expect(await store.list(ownerId: other), [moved]);
    expect(File(moved).readAsBytesSync(), zip);
    expect(File(saved).existsSync(), isFalse);
  });

  test('delete removes only that backup', () async {
    final store = newStore();
    final first = await store.save(zip, ownerId: owner);
    final second = await store.save(
      Uint8List.fromList([1, 2, 3]),
      ownerId: owner,
    );

    await store.delete(first);

    expect(await store.list(ownerId: owner), [second]);
  });

  test('delete ignores files the store did not write', () async {
    final store = newStore();
    final outside = File(path.join(base.path, 'other.zip'))
      ..writeAsBytesSync(zip);

    await store.delete(outside.path);

    expect(outside.existsSync(), isTrue);
  });

  test(
    "deleteAll removes every backup of that owner and no one else's",
    () async {
      final store = newStore();
      await store.save(zip, ownerId: owner);
      await store.save(zip, ownerId: owner);
      final kept = await store.save(zip, ownerId: other);

      await store.deleteAll(ownerId: owner);

      expect(await store.list(ownerId: owner), isEmpty);
      expect(await store.list(ownerId: other), [kept]);
    },
  );

  test('list is empty before anything was saved', () async {
    expect(await newStore().list(ownerId: owner), isEmpty);
  });

  for (final bad in ['', '.', '..', '../uidB', 'a/b', r'a\b']) {
    test('an owner id like "$bad" cannot reach outside its folder', () async {
      final store = newStore();

      await expectLater(store.save(zip, ownerId: bad), throwsArgumentError);
      await expectLater(store.list(ownerId: bad), throwsArgumentError);
      await expectLater(store.deleteAll(ownerId: bad), throwsArgumentError);
      expect(base.listSync(), isEmpty);
    });
  }
}
