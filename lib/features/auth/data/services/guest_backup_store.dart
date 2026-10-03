import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;

/// Keeps guest-data backups in app-private storage, so the only copy of a
/// guest's data survives a closed dialog, a timed-out snackbar and process
/// death until the user saves or deletes it.
///
/// Every backup belongs to one account (its owner's user id). A backup holds
/// that person's investments and amounts, so it is listed, shared and
/// deleted only for its owner, never for another account on the same device.
///
/// Android Auto Backup is off for this app, so these files stay on the
/// device and are not reachable by other apps.
abstract class GuestBackupStore {
  /// Writes [bytes] as a new backup owned by [ownerId] and returns its path.
  Future<String> save(Uint8List bytes, {required String ownerId});

  /// Hands the backup at [filePath] to [toOwnerId] and returns its new path.
  Future<String> transfer(String filePath, {required String toOwnerId});

  /// Paths of every backup owned by [ownerId], oldest first.
  Future<List<String>> list({required String ownerId});

  /// Deletes the backup at [filePath], if it still exists.
  Future<void> delete(String filePath);

  /// Deletes every backup owned by [ownerId].
  Future<void> deleteAll({required String ownerId});
}

/// [GuestBackupStore] that writes ZIP files under
/// `<baseDirectory>/guest_backups/<ownerId>`.
class FileGuestBackupStore implements GuestBackupStore {
  FileGuestBackupStore(this._baseDirectory);

  /// Resolves the app-private base directory, for example
  /// `getApplicationSupportDirectory`.
  final Future<Directory> Function() _baseDirectory;

  static const _folder = 'guest_backups';

  /// Firebase user ids are letters and digits; anything that could name
  /// another folder is refused.
  static final _validOwnerId = RegExp(r'^[A-Za-z0-9_-]+$');

  Future<Directory> get _root async =>
      Directory(path.join((await _baseDirectory()).path, _folder));

  Future<Directory> _ownerDirectory(String ownerId) async {
    if (!_validOwnerId.hasMatch(ownerId)) {
      throw ArgumentError.value(ownerId, 'ownerId', 'Not a valid user id');
    }
    return Directory(path.join((await _root).path, ownerId));
  }

  @override
  Future<String> save(Uint8List bytes, {required String ownerId}) async {
    final directory = await _ownerDirectory(ownerId);
    await directory.create(recursive: true);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final file = File(
      path.join(directory.path, 'InvTrack_Guest_Backup_$stamp.zip'),
    );
    // Write to a temporary name first so a crash mid-write never leaves a
    // truncated file that looks like a complete backup.
    final partial = File('${file.path}.part');
    await partial.writeAsBytes(bytes, flush: true);
    await partial.rename(file.path);
    return file.path;
  }

  @override
  Future<String> transfer(String filePath, {required String toOwnerId}) async {
    final directory = await _ownerDirectory(toOwnerId);
    if (!path.isWithin((await _root).path, filePath)) {
      throw ArgumentError.value(filePath, 'filePath', 'Not a guest backup');
    }
    await directory.create(recursive: true);
    final moved = await File(
      filePath,
    ).rename(path.join(directory.path, path.basename(filePath)));
    return moved.path;
  }

  @override
  Future<List<String>> list({required String ownerId}) async {
    final directory = await _ownerDirectory(ownerId);
    if (!await directory.exists()) return const [];
    final paths = await directory
        .list()
        .where((e) => e is File && e.path.endsWith('.zip'))
        .map((e) => e.path)
        .toList();
    return paths..sort();
  }

  @override
  Future<void> delete(String filePath) async {
    // Only ever delete files this store wrote.
    if (!path.isWithin((await _root).path, filePath)) return;
    final file = File(filePath);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> deleteAll({required String ownerId}) async {
    final directory = await _ownerDirectory(ownerId);
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
