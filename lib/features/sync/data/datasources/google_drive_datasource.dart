import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

class GoogleDriveDataSource {
  final http.Client _client;
  late final drive.DriveApi _driveApi;

  GoogleDriveDataSource(this._client) {
    _driveApi = drive.DriveApi(_client);
  }

  /// Finds a spreadsheet by name or creates it if it doesn't exist.
  /// Returns the file ID.
  Future<String> getOrCreateSpreadsheet(String name) async {
    final existingId = await findSpreadsheetByName(name);
    if (existingId != null) {
      return existingId;
    }
    return await createSpreadsheet(name);
  }

  /// Finds a spreadsheet by name. Returns null if not found.
  /// Checks only for files that are not trashed and are of mimeType 'application/vnd.google-apps.spreadsheet'.
  Future<String?> findSpreadsheetByName(String name) async {
    final query = "name = '$name' and mimeType = 'application/vnd.google-apps.spreadsheet' and trashed = false";
    final fileList = await _driveApi.files.list(q: query, spaces: 'drive');

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      return fileList.files!.first.id;
    }
    return null;
  }

  /// Creates a new spreadsheet with the given name.
  Future<String> createSpreadsheet(String name) async {
    final file = drive.File()
      ..name = name
      ..mimeType = 'application/vnd.google-apps.spreadsheet';

    final createdFile = await _driveApi.files.create(file);
    if (createdFile.id == null) {
      throw Exception('Failed to create spreadsheet');
    }
    return createdFile.id!;
  }

  /// Verifies that a spreadsheet with the given ID exists and is accessible.
  /// Returns false if the file is trashed or doesn't exist.
  Future<bool> verifySpreadsheetExists(String fileId) async {
    try {
      // Request the 'trashed' field to check if file is in trash
      final file = await _driveApi.files.get(
        fileId,
        $fields: 'id,name,trashed',
      ) as drive.File;

      // Return false if file is trashed
      if (file.trashed == true) {
        return false;
      }
      return true;
    } catch (e) {
      // File not found or not accessible (404 error)
      return false;
    }
  }
}
