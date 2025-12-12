import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;

class GoogleSheetsDataSource {
  final http.Client _client;
  late final sheets.SheetsApi _sheetsApi;

  GoogleSheetsDataSource(this._client) {
    _sheetsApi = sheets.SheetsApi(_client);
  }

  /// Appends rows to a sheet (single API call for multiple rows).
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

  /// Batch append rows - same as appendRows but named explicitly for clarity.
  /// All rows are written in a single API call for efficiency.
  Future<void> batchAppendRows(String spreadsheetId, String range, List<List<dynamic>> values) async {
    if (values.isEmpty) return;
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

  /// Finds the row number containing a specific ID in column A.
  /// Returns the 1-based row number, or null if not found.
  Future<int?> findRowByIdInColumn(String spreadsheetId, String sheetName, String id) async {
    final rows = await readSheet(spreadsheetId, '$sheetName!A:A');
    if (rows == null) return null;

    for (var i = 0; i < rows.length; i++) {
      if (rows[i].isNotEmpty && rows[i][0].toString() == id) {
        return i + 1; // 1-based row number
      }
    }
    return null;
  }

  /// Deletes a row by its 1-based row number.
  Future<void> deleteRow(String spreadsheetId, String sheetName, int rowNumber) async {
    // Get the sheet ID first
    final spreadsheet = await _sheetsApi.spreadsheets.get(spreadsheetId);
    final sheet = spreadsheet.sheets?.firstWhere(
      (s) => s.properties?.title == sheetName,
      orElse: () => throw Exception('Sheet not found: $sheetName'),
    );
    final sheetId = sheet?.properties?.sheetId;
    if (sheetId == null) throw Exception('Sheet ID not found for: $sheetName');

    final request = sheets.BatchUpdateSpreadsheetRequest()
      ..requests = [
        sheets.Request(
          deleteDimension: sheets.DeleteDimensionRequest(
            range: sheets.DimensionRange(
              sheetId: sheetId,
              dimension: 'ROWS',
              startIndex: rowNumber - 1, // 0-based
              endIndex: rowNumber, // Exclusive
            ),
          ),
        ),
      ];
    await _sheetsApi.spreadsheets.batchUpdate(request, spreadsheetId);
  }

  /// Updates a row by finding it by ID and replacing the entire row.
  Future<bool> updateRowById(
    String spreadsheetId,
    String sheetName,
    String id,
    List<dynamic> newValues,
    int numColumns,
  ) async {
    final rowNumber = await findRowByIdInColumn(spreadsheetId, sheetName, id);
    if (rowNumber == null) return false;

    // Generate range like 'Investments!A5:G5'
    final endColumn = String.fromCharCode('A'.codeUnitAt(0) + numColumns - 1);
    final range = '$sheetName!A$rowNumber:$endColumn$rowNumber';

    await updateRow(spreadsheetId, range, newValues);
    return true;
  }

  /// Deletes a row by finding it by ID.
  Future<bool> deleteRowById(String spreadsheetId, String sheetName, String id) async {
    final rowNumber = await findRowByIdInColumn(spreadsheetId, sheetName, id);
    if (rowNumber == null) return false;

    await deleteRow(spreadsheetId, sheetName, rowNumber);
    return true;
  }
}
