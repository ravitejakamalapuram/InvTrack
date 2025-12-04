import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;

class GoogleSheetsDataSource {
  final http.Client _client;
  late final sheets.SheetsApi _sheetsApi;

  GoogleSheetsDataSource(this._client) {
    _sheetsApi = sheets.SheetsApi(_client);
  }

  /// Appends rows to a sheet.
  /// [spreadsheetId] is the ID of the spreadsheet.
  /// [range] is the A1 notation of the range (e.g., 'Sheet1!A1').
  /// [values] is a list of rows, where each row is a list of values.
  Future<void> appendRows(String spreadsheetId, String range, List<List<dynamic>> values) async {
    final valueRange = sheets.ValueRange()..values = values;
    await _sheetsApi.spreadsheets.values.append(
      valueRange,
      spreadsheetId,
      range,
      valueInputOption: 'USER_ENTERED',
    );
  }

  /// Reads rows from a sheet.
  Future<List<List<dynamic>>?> readSheet(String spreadsheetId, String range) async {
    final valueRange = await _sheetsApi.spreadsheets.values.get(spreadsheetId, range);
    return valueRange.values;
  }

  /// Updates rows in a sheet.
  Future<void> updateRow(String spreadsheetId, String range, List<dynamic> values) async {
    final valueRange = sheets.ValueRange()..values = [values];
    await _sheetsApi.spreadsheets.values.update(
      valueRange,
      spreadsheetId,
      range,
      valueInputOption: 'USER_ENTERED',
    );
  }

  /// Clears a range in a sheet.
  Future<void> clearSheet(String spreadsheetId, String range) async {
    await _sheetsApi.spreadsheets.values.clear(
      sheets.ClearValuesRequest(),
      spreadsheetId,
      range,
    );
  }
  
  /// Creates a new sheet (tab) in the spreadsheet if it doesn't exist.
  Future<void> createSheetIfNotExists(String spreadsheetId, String title) async {
    final spreadsheet = await _sheetsApi.spreadsheets.get(spreadsheetId);
    final sheetExists = spreadsheet.sheets?.any((s) => s.properties?.title == title) ?? false;
    
    if (!sheetExists) {
      final request = sheets.BatchUpdateSpreadsheetRequest()
        ..requests = [
          sheets.Request(
            addSheet: sheets.AddSheetRequest(
              properties: sheets.SheetProperties(title: title),
            ),
          ),
        ];
      await _sheetsApi.spreadsheets.batchUpdate(request, spreadsheetId);
    }
  }
}
