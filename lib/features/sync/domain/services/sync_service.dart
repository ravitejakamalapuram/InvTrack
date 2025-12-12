import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/sync/data/datasources/google_drive_datasource.dart';
import 'package:inv_tracker/features/sync/data/datasources/google_sheets_datasource.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref);
});

/// Header row for Investments sheet
const List<String> _investmentHeaders = [
  'ID',
  'Name',
  'Type',
  'Status',
  'Notes',
  'Created',
  'Updated',
];

/// Header row for CashFlows sheet
const List<String> _cashFlowHeaders = [
  'ID',
  'Investment ID',
  'Investment Name',
  'Type',
  'Date',
  'Amount',
  'Notes',
  'Created',
];

/// Sync service for Google Sheets integration.
///
/// Current implementation uses Full Sync (clear + rewrite all data).
///
/// ---
/// FUTURE: Multi-Device Sync Conflict Resolution Options
/// ---
///
/// OPTION A: Last-Write-Wins (Current - Simple)
/// - Each sync overwrites the entire sheet
/// - Most recent device's data wins
/// - Pros: Simple, no conflicts
/// - Cons: Data loss possible if devices sync simultaneously
///
/// OPTION B: Timestamp-Based Merge (Recommended for future)
/// - Each record has createdAt + updatedAt timestamp
/// - On sync: compare timestamps, keep newer version of each record
/// - Pros: Better data preservation
/// - Cons: Conflicts if same record edited on 2 devices simultaneously
/// - Implementation:
///   1. Add "lastSyncAt" column to each record
///   2. On sync:
///      a. Fetch all records from Google Sheet
///      b. Compare each record by ID:
///         - If local.updatedAt > sheet.updatedAt → push local
///         - If local.updatedAt < sheet.updatedAt → pull from sheet
///         - If equal → no change
///      c. For new records: add to sheet
///      d. For deleted records: soft-delete with "deletedAt" column
///
/// OPTION C: Full CRDT/Operational Transform (Complex)
/// - Track all operations (create, update, delete)
/// - Merge operations rather than final state
/// - Pros: Robust conflict resolution
/// - Cons: Complex implementation, storage overhead
///
class SyncService {
  final Ref _ref;
  static const String _spreadsheetName = 'InvTracker_Data';
  static const String _spreadsheetIdKey = 'invtracker_spreadsheet_id';
  static const String _hasImportedKey = 'invtracker_has_imported';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');

  SyncService(this._ref);

  /// Push all local data to Google Sheets (full sync).
  Future<void> pushToSheet() async {
    final googleSignIn = _ref.read(googleSignInProvider);
    final currentUser = googleSignIn.currentUser;

    if (currentUser == null) {
      debugPrint('Push skipped: User not signed in');
      return;
    }

    try {
      final client = await googleSignIn.authenticatedClient();
      if (client == null) {
        throw Exception('Failed to get authenticated client');
      }

      final driveDataSource = GoogleDriveDataSource(client);
      final sheetsDataSource = GoogleSheetsDataSource(client);

      final spreadsheetId = await _getOrCreateSpreadsheet(driveDataSource);
      debugPrint('Using spreadsheet: $spreadsheetId');

      await sheetsDataSource.createSheetIfNotExists(spreadsheetId, 'Investments');
      await sheetsDataSource.createSheetIfNotExists(spreadsheetId, 'CashFlows');

      await _pushAllData(spreadsheetId, sheetsDataSource);

      debugPrint('Push completed successfully');
    } catch (e, st) {
      debugPrint('Push failed: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    }
  }

  /// Import data from Google Sheet on first login.
  /// Returns true if data was imported, false if no data or already imported.
  ///
  /// [force] - if true, bypasses the "already imported" check (used for Connect Guest to Google)
  Future<bool> importFromSheetOnLogin({bool force = false}) async {
    // Check if we've already imported (skip check if force=true)
    if (!force) {
      final hasImported = await _secureStorage.read(key: _hasImportedKey);
      if (hasImported == 'true') {
        debugPrint('Import skipped: Already imported previously');
        return false;
      }
    }

    final googleSignIn = _ref.read(googleSignInProvider);
    final currentUser = googleSignIn.currentUser;

    if (currentUser == null) {
      debugPrint('Import skipped: User not signed in');
      return false;
    }

    try {
      final client = await googleSignIn.authenticatedClient();
      if (client == null) {
        throw Exception('Failed to get authenticated client');
      }

      final driveDataSource = GoogleDriveDataSource(client);

      // Check if spreadsheet exists
      final existingId = await driveDataSource.findSpreadsheetByName(_spreadsheetName);
      if (existingId == null) {
        debugPrint('Import skipped: No existing spreadsheet found');
        if (!force) {
          await _secureStorage.write(key: _hasImportedKey, value: 'true');
        }
        return false;
      }

      // Cache the spreadsheet ID
      await _secureStorage.write(key: _spreadsheetIdKey, value: existingId);

      final sheetsDataSource = GoogleSheetsDataSource(client);

      // Import data
      final imported = await _importAllData(existingId, sheetsDataSource);

      // Mark as imported
      await _secureStorage.write(key: _hasImportedKey, value: 'true');

      debugPrint('Import completed: $imported items imported');
      return imported > 0;
    } catch (e, st) {
      debugPrint('Import failed: $e');
      debugPrint('Stack trace: $st');
      // Don't rethrow - import failure shouldn't block login
      return false;
    }
  }

  /// Push all local data to sheets (clear and rewrite).
  Future<void> _pushAllData(
    String spreadsheetId,
    GoogleSheetsDataSource sheetsDataSource,
  ) async {
    final investments = await _ref.read(investmentRepositoryProvider).getAllInvestments();
    final cashFlows = await _ref.read(investmentRepositoryProvider).getAllCashFlows();

    final investmentNameMap = {for (var inv in investments) inv.id: inv.name};

    // Build sheet data
    final investmentRows = <List<dynamic>>[
      _investmentHeaders,
      ...investments.map((inv) => _investmentToRow(inv)),
    ];

    final cashFlowRows = <List<dynamic>>[
      _cashFlowHeaders,
      ...cashFlows.map((cf) => _cashFlowToRow(cf, investmentNameMap[cf.investmentId] ?? 'Unknown')),
    ];

    // Clear and write Investments
    await sheetsDataSource.clearSheet(spreadsheetId, 'Investments!A:G');
    await sheetsDataSource.batchAppendRows(spreadsheetId, 'Investments!A:G', investmentRows);
    debugPrint('Pushed ${investments.length} investments');

    // Clear and write CashFlows
    await sheetsDataSource.clearSheet(spreadsheetId, 'CashFlows!A:H');
    await sheetsDataSource.batchAppendRows(spreadsheetId, 'CashFlows!A:H', cashFlowRows);
    debugPrint('Pushed ${cashFlows.length} cashflows');
  }

  /// Import all data from sheets to local database.
  /// Returns count of items imported.
  Future<int> _importAllData(
    String spreadsheetId,
    GoogleSheetsDataSource sheetsDataSource,
  ) async {
    int importedCount = 0;
    final repo = _ref.read(investmentRepositoryProvider);

    // Import Investments first
    try {
      final investmentRows = await sheetsDataSource.readSheet(spreadsheetId, 'Investments!A:G');
      if (investmentRows != null && investmentRows.length > 1) {
        for (int i = 1; i < investmentRows.length; i++) {
          final row = investmentRows[i];
          if (row.isEmpty) continue;

          final investment = _rowToInvestment(row);
          if (investment != null) {
            try {
              await repo.createInvestment(investment);
              importedCount++;
              debugPrint('Imported investment: ${investment.name}');
            } catch (e) {
              debugPrint('Investment already exists or error: ${investment.id}');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error reading Investments sheet: $e');
    }

    // Import CashFlows
    try {
      final cashFlowRows = await sheetsDataSource.readSheet(spreadsheetId, 'CashFlows!A:H');
      if (cashFlowRows != null && cashFlowRows.length > 1) {
        for (int i = 1; i < cashFlowRows.length; i++) {
          final row = cashFlowRows[i];
          if (row.isEmpty) continue;

          final cashFlow = _rowToCashFlow(row);
          if (cashFlow != null) {
            try {
              await repo.addCashFlow(cashFlow);
              importedCount++;
              debugPrint('Imported cashflow: ${cashFlow.id}');
            } catch (e) {
              debugPrint('CashFlow already exists or error: ${cashFlow.id}');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error reading CashFlows sheet: $e');
    }

    return importedCount;
  }

  /// Convert Investment entity to sheet row
  List<dynamic> _investmentToRow(InvestmentEntity inv) {
    return [
      inv.id,
      inv.name,
      inv.type.displayName,
      inv.status.name.toUpperCase(),
      inv.notes ?? '',
      _dateTimeFormat.format(inv.createdAt),
      _dateTimeFormat.format(inv.updatedAt),
    ];
  }

  /// Convert CashFlow entity to sheet row
  List<dynamic> _cashFlowToRow(CashFlowEntity cf, String investmentName) {
    return [
      cf.id,
      cf.investmentId,
      investmentName,
      cf.type.displayName,
      _dateFormat.format(cf.date),
      cf.amount,
      cf.notes ?? '',
      _dateTimeFormat.format(cf.createdAt),
    ];
  }

  /// Convert sheet row to Investment entity
  InvestmentEntity? _rowToInvestment(List<dynamic> row) {
    try {
      if (row.length < 7) return null;

      final id = row[0]?.toString();
      final name = row[1]?.toString();
      if (id == null || id.isEmpty || name == null || name.isEmpty) return null;
      if (id == 'ID') return null; // Skip header

      // Parse type
      final typeStr = row[2]?.toString() ?? '';
      InvestmentType type = InvestmentType.other;
      for (final t in InvestmentType.values) {
        if (t.displayName.toLowerCase() == typeStr.toLowerCase()) {
          type = t;
          break;
        }
      }

      // Parse status
      final statusStr = (row[3]?.toString() ?? 'open').toLowerCase();
      final status = statusStr == 'closed' ? InvestmentStatus.closed : InvestmentStatus.open;

      // Parse dates
      DateTime createdAt;
      DateTime updatedAt;
      try {
        createdAt = _dateTimeFormat.parse(row[5]?.toString() ?? '');
      } catch (_) {
        createdAt = DateTime.now();
      }
      try {
        updatedAt = _dateTimeFormat.parse(row[6]?.toString() ?? '');
      } catch (_) {
        updatedAt = DateTime.now();
      }

      return InvestmentEntity(
        id: id,
        name: name,
        type: type,
        status: status,
        notes: row[4]?.toString().isEmpty == true ? null : row[4]?.toString(),
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    } catch (e) {
      debugPrint('Error parsing investment row: $e');
      return null;
    }
  }

  /// Convert sheet row to CashFlow entity
  CashFlowEntity? _rowToCashFlow(List<dynamic> row) {
    try {
      if (row.length < 8) return null;

      final id = row[0]?.toString();
      final investmentId = row[1]?.toString();
      if (id == null || id.isEmpty || investmentId == null || investmentId.isEmpty) return null;
      if (id == 'ID') return null; // Skip header

      // Parse type
      final typeStr = row[3]?.toString() ?? '';
      CashFlowType type = CashFlowType.invest;
      for (final t in CashFlowType.values) {
        if (t.displayName.toLowerCase() == typeStr.toLowerCase()) {
          type = t;
          break;
        }
      }

      // Parse date
      DateTime date;
      try {
        date = _dateFormat.parse(row[4]?.toString() ?? '');
      } catch (_) {
        date = DateTime.now();
      }

      // Parse amount
      double amount;
      try {
        amount = double.parse(row[5]?.toString() ?? '0');
      } catch (_) {
        amount = 0;
      }

      // Parse createdAt
      DateTime createdAt;
      try {
        createdAt = _dateTimeFormat.parse(row[7]?.toString() ?? '');
      } catch (_) {
        createdAt = DateTime.now();
      }

      return CashFlowEntity(
        id: id,
        investmentId: investmentId,
        type: type,
        date: date,
        amount: amount,
        notes: row[6]?.toString().isEmpty == true ? null : row[6]?.toString(),
        createdAt: createdAt,
      );
    } catch (e) {
      debugPrint('Error parsing cashflow row: $e');
      return null;
    }
  }

  /// Gets or creates the spreadsheet, caching the ID locally.
  Future<String> _getOrCreateSpreadsheet(GoogleDriveDataSource driveDataSource) async {
    // Check cache first
    final cachedId = await _secureStorage.read(key: _spreadsheetIdKey);
    if (cachedId != null && cachedId.isNotEmpty) {
      final exists = await driveDataSource.verifySpreadsheetExists(cachedId);
      if (exists) {
        return cachedId;
      }
      await _secureStorage.delete(key: _spreadsheetIdKey);
    }

    // Search for existing
    final existingId = await driveDataSource.findSpreadsheetByName(_spreadsheetName);
    if (existingId != null) {
      await _secureStorage.write(key: _spreadsheetIdKey, value: existingId);
      return existingId;
    }

    // Create new
    final newId = await driveDataSource.createSpreadsheet(_spreadsheetName);
    await _secureStorage.write(key: _spreadsheetIdKey, value: newId);
    return newId;
  }

  /// Clear import flag (for testing or re-import scenarios)
  Future<void> clearImportFlag() async {
    await _secureStorage.delete(key: _hasImportedKey);
  }

  /// Check if Google account has existing sheet data.
  /// Returns true if a spreadsheet exists with data.
  Future<bool> checkForExistingSheetData() async {
    final googleSignIn = _ref.read(googleSignInProvider);
    final currentUser = googleSignIn.currentUser;

    debugPrint('[CheckExisting] Starting check, currentUser: ${currentUser?.email}');

    if (currentUser == null) {
      debugPrint('[CheckExisting] No current user, returning false');
      return false;
    }

    try {
      final client = await googleSignIn.authenticatedClient();
      if (client == null) {
        debugPrint('[CheckExisting] No authenticated client, returning false');
        return false;
      }

      final driveDataSource = GoogleDriveDataSource(client);
      final sheetsDataSource = GoogleSheetsDataSource(client);

      // First, search for existing spreadsheet by name (don't rely on cache)
      debugPrint('[CheckExisting] Searching for spreadsheet: $_spreadsheetName');
      final existingId = await driveDataSource.findSpreadsheetByName(_spreadsheetName);

      if (existingId == null) {
        debugPrint('[CheckExisting] No spreadsheet found, returning false');
        return false;
      }

      debugPrint('[CheckExisting] Found spreadsheet: $existingId');
      await _secureStorage.write(key: _spreadsheetIdKey, value: existingId);

      // Check if spreadsheet has data in Investments sheet
      try {
        final rows = await sheetsDataSource.readSheet(existingId, 'Investments!A2:A');
        final hasData = rows != null && rows.isNotEmpty;
        debugPrint('[CheckExisting] Investments sheet has data: $hasData (rows: ${rows?.length ?? 0})');
        return hasData;
      } catch (sheetError) {
        // Sheet might not exist yet, but spreadsheet does - that's still "no data"
        debugPrint('[CheckExisting] Could not read Investments sheet: $sheetError');
        return false;
      }
    } catch (e, st) {
      debugPrint('[CheckExisting] Error: $e');
      debugPrint('[CheckExisting] Stack: $st');
      return false;
    }
  }

  /// Check for cloud data and import it atomically.
  /// Returns a record with (hasCloudData, importedCount).
  /// Use this for Connect Guest to Google flow to avoid race conditions.
  Future<({bool hasCloudData, int importedCount})> checkAndImportCloudData() async {
    final googleSignIn = _ref.read(googleSignInProvider);
    final currentUser = googleSignIn.currentUser;

    debugPrint('[CheckAndImport] Starting, currentUser: ${currentUser?.email}');

    if (currentUser == null) {
      debugPrint('[CheckAndImport] No current user');
      return (hasCloudData: false, importedCount: 0);
    }

    try {
      final client = await googleSignIn.authenticatedClient();
      if (client == null) {
        debugPrint('[CheckAndImport] No authenticated client');
        return (hasCloudData: false, importedCount: 0);
      }

      final driveDataSource = GoogleDriveDataSource(client);
      final sheetsDataSource = GoogleSheetsDataSource(client);

      // Search for existing spreadsheet
      debugPrint('[CheckAndImport] Searching for spreadsheet: $_spreadsheetName');
      final existingId = await driveDataSource.findSpreadsheetByName(_spreadsheetName);

      if (existingId == null) {
        debugPrint('[CheckAndImport] No spreadsheet found');
        return (hasCloudData: false, importedCount: 0);
      }

      debugPrint('[CheckAndImport] Found spreadsheet: $existingId');
      await _secureStorage.write(key: _spreadsheetIdKey, value: existingId);

      // Check if spreadsheet has data
      List<List<dynamic>>? rows;
      try {
        rows = await sheetsDataSource.readSheet(existingId, 'Investments!A2:A');
      } catch (e) {
        debugPrint('[CheckAndImport] Could not read sheet: $e');
        return (hasCloudData: false, importedCount: 0);
      }

      final hasCloudData = rows != null && rows.isNotEmpty;
      debugPrint('[CheckAndImport] Cloud has data: $hasCloudData (${rows?.length ?? 0} rows)');

      if (!hasCloudData) {
        return (hasCloudData: false, importedCount: 0);
      }

      // Import the data
      final importedCount = await _importAllData(existingId, sheetsDataSource);
      debugPrint('[CheckAndImport] Imported $importedCount items');

      return (hasCloudData: true, importedCount: importedCount);
    } catch (e, st) {
      debugPrint('[CheckAndImport] Error: $e');
      debugPrint('[CheckAndImport] Stack: $st');
      return (hasCloudData: false, importedCount: 0);
    }
  }

  /// Check if cloud has data WITHOUT importing.
  /// Returns count of investments in cloud (0 if no data).
  Future<int> getCloudDataCount() async {
    final googleSignIn = _ref.read(googleSignInProvider);
    final currentUser = googleSignIn.currentUser;

    debugPrint('[GetCloudCount] Starting, currentUser: ${currentUser?.email}');

    if (currentUser == null) {
      debugPrint('[GetCloudCount] No current user');
      return 0;
    }

    try {
      final client = await googleSignIn.authenticatedClient();
      if (client == null) {
        debugPrint('[GetCloudCount] No authenticated client');
        return 0;
      }

      final driveDataSource = GoogleDriveDataSource(client);
      final sheetsDataSource = GoogleSheetsDataSource(client);

      // Search for existing spreadsheet
      final existingId = await driveDataSource.findSpreadsheetByName(_spreadsheetName);
      if (existingId == null) {
        debugPrint('[GetCloudCount] No spreadsheet found');
        return 0;
      }

      // Cache the spreadsheet ID
      await _secureStorage.write(key: _spreadsheetIdKey, value: existingId);

      // Count investments in sheet
      try {
        final rows = await sheetsDataSource.readSheet(existingId, 'Investments!A2:A');
        final count = rows?.length ?? 0;
        debugPrint('[GetCloudCount] Found $count investments in cloud');
        return count;
      } catch (e) {
        debugPrint('[GetCloudCount] Could not read sheet: $e');
        return 0;
      }
    } catch (e, st) {
      debugPrint('[GetCloudCount] Error: $e');
      debugPrint('[GetCloudCount] Stack: $st');
      return 0;
    }
  }

  /// Import cloud data (use after getCloudDataCount confirmed data exists).
  Future<int> importCloudData() async {
    final googleSignIn = _ref.read(googleSignInProvider);
    final currentUser = googleSignIn.currentUser;

    if (currentUser == null) {
      debugPrint('[ImportCloud] No current user');
      return 0;
    }

    try {
      final client = await googleSignIn.authenticatedClient();
      if (client == null) {
        debugPrint('[ImportCloud] No authenticated client');
        return 0;
      }

      // Get cached spreadsheet ID
      final spreadsheetId = await _secureStorage.read(key: _spreadsheetIdKey);
      if (spreadsheetId == null) {
        debugPrint('[ImportCloud] No cached spreadsheet ID');
        return 0;
      }

      final sheetsDataSource = GoogleSheetsDataSource(client);
      final count = await _importAllData(spreadsheetId, sheetsDataSource);
      debugPrint('[ImportCloud] Imported $count items');
      return count;
    } catch (e, st) {
      debugPrint('[ImportCloud] Error: $e');
      debugPrint('[ImportCloud] Stack: $st');
      return 0;
    }
  }
}
