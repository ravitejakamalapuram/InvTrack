import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;

/// Keeps guest-data backups in app-private storage, so the only copy of a
/// guest's data survives a closed dialog, a timed-out snackbar and process
/// death until the user saves or deletes it.
///
/// Android Auto Backup is off for this app, so these files stay on the
/// device and are not reachable by other apps.
abstract class GuestBackupStore {
  /// Writes [bytes] as a new backup and returns its file path.
  Future<String> save(Uint8List bytes);

  /// Paths of every backup kept on this device, oldest first.
  Future<List<String>> list();

  /// Deletes the backup at [filePath], if it still exists.
  Future<void> delete(String filePath);

  /// Deletes every backup kept on this device.
  Future<void> deleteAll();
}

/// [GuestBackupStore] that writes ZIP files under
/// `<baseDirectory>/guest_backups`.
class FileGuestBackupStore implements GuestBackupStore {
  FileGuestBackupStore(this._baseDirectory);

  /// Resolves the app-private base directory, for example
  /// `getApplicationSupportDirectory`.
  final Future<Directory> Function() _baseDirectory;

  static const _folder = 'guest_backups';

  Future<Directory> get _directory async =>
      Directory(path.join((await _baseDirectory()).path, _folder));

  @override
  Future<String> save(Uint8List bytes) async {
    final directory = await _directory;
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
  Future<List<String>> list() async {
    final directory = await _directory;
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
    final directory = await _directory;
    // Only ever delete files this store wrote.
    if (!path.isWithin(directory.path, filePath)) return;
    final file = File(filePath);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> deleteAll() async {
    final directory = await _directory;
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
