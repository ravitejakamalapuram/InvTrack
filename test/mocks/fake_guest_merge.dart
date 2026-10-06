import 'dart:io';
import 'dart:typed_data';

import 'package:inv_tracker/features/auth/data/services/guest_backup_store.dart';
import 'package:inv_tracker/features/settings/data/services/data_export_service.dart';
import 'package:inv_tracker/features/settings/data/services/data_import_service.dart';
import 'package:mocktail/mocktail.dart';

/// The guest's data as a ZIP, as built by the merge flow.
final guestBackupBytes = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 1, 2, 3]);

/// An import that added every record of [guestExport].
const completeGuestImport = ZipImportResult(
  investmentsImported: 2,
  cashflowsImported: 5,
  goalsImported: 1,
  documentsImported: 0,
);

/// An import that skipped an investment the account already has.
const incompleteGuestImport = ZipImportResult(
  investmentsImported: 1,
  cashflowsImported: 3,
  goalsImported: 1,
  documentsImported: 0,
  warnings: ['Skipped "FD" - already exists'],
);

/// A guest export whose every record the ZIP carries.
ZipExport guestExport() => ZipExport(
  bytes: guestBackupBytes,
  investments: completeGuestImport.investmentsImported,
  cashFlows: completeGuestImport.cashflowsImported,
  goals: completeGuestImport.goalsImported,
  documents: completeGuestImport.documentsImported,
  hasFireSettings: false,
  investmentsWithDetailsNotInExport: 0,
  investmentsNotInExport: 0,
  expectedCashFlows: 0,
);

/// In-memory stand-in for the app-private backup folder.
class InMemoryGuestBackupStore implements GuestBackupStore {
  InMemoryGuestBackupStore({this.calls});

  final files = <String, Uint8List>{};

  /// Owner user id of each file in [files].
  final owners = <String, String>{};

  /// Records 'save' when a backup is written, if set.
  final List<String>? calls;
  var _next = 0;

  /// Makes [transfer] fail, like a rename the file system refuses.
  var failTransfers = false;

  String _path(String ownerId, String name) =>
      '/data/app/files/guest_backups/$ownerId/$name';

  @override
  Future<String> save(Uint8List bytes, {required String ownerId}) async {
    calls?.add('save');
    final path = _path(ownerId, 'backup_${_next++}.zip');
    files[path] = bytes;
    owners[path] = ownerId;
    return path;
  }

  @override
  Future<String> transfer(String filePath, {required String toOwnerId}) async {
    if (failTransfers) throw const FileSystemException('rename failed');
    final moved = _path(toOwnerId, filePath.split('/').last);
    files[moved] = files.remove(filePath)!;
    owners.remove(filePath);
    owners[moved] = toOwnerId;
    return moved;
  }

  @override
  Future<List<String>> list({required String ownerId}) async => [
    for (final MapEntry(:key, :value) in owners.entries)
      if (value == ownerId) key,
  ];

  @override
  Future<void> delete(String filePath) async {
    files.remove(filePath);
    owners.remove(filePath);
  }

  @override
  Future<void> deleteAll({required String ownerId}) async {
    for (final path in await list(ownerId: ownerId)) {
      await delete(path);
    }
  }
}

class FakeGuestExportService extends Fake implements DataExportService {
  final sharedFiles = <List<String>>[];

  /// Thrown by [shareZipFiles] instead of sharing, when set.
  Object? shareError;

  @override
  Future<ZipExport> exportAsZipBytes() async => guestExport();

  @override
  Future<void> shareZipFiles(List<String> filePaths) async {
    if (shareError != null) throw shareError!;
    sharedFiles.add(filePaths);
  }
}

class RecordingGuestImportService extends Fake implements DataImportService {
  RecordingGuestImportService({this.result = completeGuestImport});

  ZipImportResult result;

  /// Thrown instead of returning [result] when set.
  Object? error;
  final calls = <(Uint8List, ImportStrategy, String)>[];

  @override
  Future<ZipImportResult> importFromZip(
    Uint8List zipBytes,
    ImportStrategy strategy, {
    required String baseCurrency,
  }) async {
    calls.add((zipBytes, strategy, baseCurrency));
    if (error != null) throw error!;
    return result;
  }
}
