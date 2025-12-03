import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import 'package:inv_tracker/data/datasources/secure_token_storage.dart';

/// Service for Google Sheets sync operations.
class GoogleSheetsService {
  static const sheetName = 'InvTracker_Master';
  static const appPropertyKey = 'invtracker';
  static const appPropertyValue = 'true';

  final SecureTokenStorage _tokenStorage;
  String? _spreadsheetId;

  GoogleSheetsService(this._tokenStorage);

  /// Get or create the InvTracker spreadsheet.
  Future<String> getOrCreateSpreadsheet(String accessToken) async {
    // Check cached ID first
    _spreadsheetId ??= await _tokenStorage.getSpreadsheetId();
    if (_spreadsheetId != null) return _spreadsheetId!;

    final client = _AuthenticatedClient(accessToken);
    final driveApi = drive.DriveApi(client);

    // Search for existing spreadsheet
    final existing = await _findExistingSheet(driveApi);
    if (existing != null) {
      _spreadsheetId = existing;
      await _tokenStorage.saveSpreadsheetId(existing);
      return existing;
    }

    // Create new spreadsheet
    final sheetsApi = sheets.SheetsApi(client);
    final newId = await _createNewSheet(sheetsApi);
    _spreadsheetId = newId;
    await _tokenStorage.saveSpreadsheetId(newId);
    return newId;
  }

  Future<String?> _findExistingSheet(drive.DriveApi driveApi) async {
    try {
      final query = "mimeType='application/vnd.google-apps.spreadsheet' and name='$sheetName' and trashed=false";
      final result = await driveApi.files.list(q: query, spaces: 'drive', $fields: 'files(id, name)');
      if (result.files != null && result.files!.isNotEmpty) {
        return result.files!.first.id;
      }
    } catch (e) {
      // Ignore errors, will create new sheet
    }
    return null;
  }

  Future<String> _createNewSheet(sheets.SheetsApi sheetsApi) async {
    final spreadsheet = sheets.Spreadsheet(
      properties: sheets.SpreadsheetProperties(title: sheetName),
      sheets: [
        sheets.Sheet(properties: sheets.SheetProperties(title: 'Investments', index: 0)),
        sheets.Sheet(properties: sheets.SheetProperties(title: 'Entries', index: 1)),
        sheets.Sheet(properties: sheets.SheetProperties(title: '_meta', index: 2)),
      ],
    );

    final created = await sheetsApi.spreadsheets.create(spreadsheet);
    final id = created.spreadsheetId!;

    // Add headers
    await _addHeaders(sheetsApi, id);
    return id;
  }

  Future<void> _addHeaders(sheets.SheetsApi api, String spreadsheetId) async {
    final investmentHeaders = ['id', 'name', 'category', 'notes', 'startDate', 'createdAt', 'updatedAt', 'isDeleted'];
    final entryHeaders = ['id', 'investmentId', 'type', 'amount', 'units', 'pricePerUnit', 'date', 'note', 'createdAt', 'updatedAt'];
    final metaHeaders = ['key', 'value'];

    await api.spreadsheets.values.update(
      sheets.ValueRange(values: [investmentHeaders]),
      spreadsheetId, 'Investments!A1',
      valueInputOption: 'RAW',
    );
    await api.spreadsheets.values.update(
      sheets.ValueRange(values: [entryHeaders]),
      spreadsheetId, 'Entries!A1',
      valueInputOption: 'RAW',
    );
    await api.spreadsheets.values.update(
      sheets.ValueRange(values: [metaHeaders, ['version', '1'], ['lastSync', DateTime.now().toIso8601String()]]),
      spreadsheetId, '_meta!A1',
      valueInputOption: 'RAW',
    );
  }

  /// Sync investments to Google Sheets.
  Future<void> syncInvestments(String accessToken, List<Map<String, dynamic>> investments) async {
    final id = await getOrCreateSpreadsheet(accessToken);
    final client = _AuthenticatedClient(accessToken);
    final api = sheets.SheetsApi(client);

    // Clear existing data (except header)
    await api.spreadsheets.values.clear(sheets.ClearValuesRequest(), id, 'Investments!A2:Z');

    if (investments.isEmpty) return;

    // Write data
    final rows = investments.map((inv) => [
      inv['id'], inv['name'], inv['category'], inv['notes'] ?? '',
      inv['startDate'], inv['createdAt'], inv['updatedAt'], inv['isDeleted'].toString(),
    ]).toList();

    await api.spreadsheets.values.update(
      sheets.ValueRange(values: rows),
      id, 'Investments!A2',
      valueInputOption: 'RAW',
    );
  }

  /// Sync entries to Google Sheets.
  Future<void> syncEntries(String accessToken, List<Map<String, dynamic>> entries) async {
    final id = await getOrCreateSpreadsheet(accessToken);
    final client = _AuthenticatedClient(accessToken);
    final api = sheets.SheetsApi(client);

    await api.spreadsheets.values.clear(sheets.ClearValuesRequest(), id, 'Entries!A2:Z');

    if (entries.isEmpty) return;

    final rows = entries.map((e) => [
      e['id'], e['investmentId'], e['type'], e['amount'].toString(),
      e['units']?.toString() ?? '', e['pricePerUnit']?.toString() ?? '',
      e['date'], e['note'] ?? '', e['createdAt'], e['updatedAt'],
    ]).toList();

    await api.spreadsheets.values.update(
      sheets.ValueRange(values: rows),
      id, 'Entries!A2',
      valueInputOption: 'RAW',
    );
  }

  /// Update last sync timestamp.
  Future<void> updateLastSync(String accessToken) async {
    final id = await getOrCreateSpreadsheet(accessToken);
    final client = _AuthenticatedClient(accessToken);
    final api = sheets.SheetsApi(client);

    await api.spreadsheets.values.update(
      sheets.ValueRange(values: [['lastSync', DateTime.now().toIso8601String()]]),
      id, '_meta!A3',
      valueInputOption: 'RAW',
    );
  }
}

/// HTTP client with auth header.
class _AuthenticatedClient extends http.BaseClient {
  final String _accessToken;
  final http.Client _inner = http.Client();

  _AuthenticatedClient(this._accessToken);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_accessToken';
    return _inner.send(request);
  }
}

