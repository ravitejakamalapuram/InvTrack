import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/sync/data/datasources/google_drive_datasource.dart';
import 'package:inv_tracker/features/sync/data/datasources/google_sheets_datasource.dart';
import 'package:inv_tracker/features/sync/domain/repositories/cloud_repository.dart';

/// Provider for cloud repository.
final cloudRepositoryProvider = Provider<CloudRepository>((ref) {
  final googleSignIn = ref.watch(googleSignInProvider);
  return CloudRepositoryImpl(googleSignIn);
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

/// Implementation of CloudRepository using Google Sheets.
class CloudRepositoryImpl implements CloudRepository {
  final GoogleSignIn _googleSignIn;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _spreadsheetName = 'InvTracker_Data';
  static const String _spreadsheetIdKey = 'invtracker_spreadsheet_id';

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');

  CloudRepositoryImpl(this._googleSignIn);

  /// Get authenticated HTTP client, throws if not authenticated.
  Future<http.Client> _getClient() async {
    final client = await _googleSignIn.authenticatedClient();
    if (client == null) {
      throw Exception('Not authenticated with Google');
    }
    return client;
  }

  /// Get or create spreadsheet, returns ID.
  Future<String> _getSpreadsheetId() async {
    // Check cache first
    final cachedId = await _secureStorage.read(key: _spreadsheetIdKey);
    if (cachedId != null && cachedId.isNotEmpty) {
      final client = await _getClient();
      final driveDataSource = GoogleDriveDataSource(client);
      final exists = await driveDataSource.verifySpreadsheetExists(cachedId);
      if (exists) {
        return cachedId;
      }
      await _secureStorage.delete(key: _spreadsheetIdKey);
    }

    // Search or create
    final client = await _getClient();
    final driveDataSource = GoogleDriveDataSource(client);
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

  @override
  Future<bool> hasSpreadsheet() async {
    try {
      final client = await _getClient();
      final driveDataSource = GoogleDriveDataSource(client);
      final existingId = await driveDataSource.findSpreadsheetByName(_spreadsheetName);
      return existingId != null;
    } catch (e) {
      debugPrint('[CloudRepo] Error checking spreadsheet: $e');
      return false;
    }
  }

  @override
  Future<String> ensureSpreadsheetExists() async {
    final spreadsheetId = await _getSpreadsheetId();
    final client = await _getClient();
    final sheetsDataSource = GoogleSheetsDataSource(client);

    await sheetsDataSource.createSheetIfNotExists(spreadsheetId, 'Investments');
    await sheetsDataSource.createSheetIfNotExists(spreadsheetId, 'CashFlows');

    return spreadsheetId;
  }

  @override
  Future<int> getInvestmentCount() async {
    try {
      final client = await _getClient();
      final driveDataSource = GoogleDriveDataSource(client);
      final existingId = await driveDataSource.findSpreadsheetByName(_spreadsheetName);

      if (existingId == null) return 0;

      final sheetsDataSource = GoogleSheetsDataSource(client);
      final rows = await sheetsDataSource.readSheet(existingId, 'Investments!A2:A');
      return rows?.length ?? 0;
    } catch (e) {
      debugPrint('[CloudRepo] Error getting investment count: $e');
      return 0;
    }
  }

  // ============ INVESTMENTS ============

  @override
  Future<List<InvestmentEntity>> fetchAllInvestments() async {
    try {
      final client = await _getClient();
      final driveDataSource = GoogleDriveDataSource(client);
      final existingId = await driveDataSource.findSpreadsheetByName(_spreadsheetName);

      if (existingId == null) {
        debugPrint('[CloudRepo] No spreadsheet found');
        return [];
      }

      await _secureStorage.write(key: _spreadsheetIdKey, value: existingId);
      final sheetsDataSource = GoogleSheetsDataSource(client);

      final rows = await sheetsDataSource.readSheet(existingId, 'Investments!A:G');
      if (rows == null || rows.length <= 1) return [];

      final investments = <InvestmentEntity>[];
      for (int i = 1; i < rows.length; i++) {
        final investment = _rowToInvestment(rows[i]);
        if (investment != null) {
          investments.add(investment);
        }
      }

      debugPrint('[CloudRepo] Fetched ${investments.length} investments');
      return investments;
    } catch (e) {
      debugPrint('[CloudRepo] Error fetching investments: $e');
      rethrow;
    }
  }

  @override
  Future<InvestmentEntity> addInvestment(InvestmentEntity investment) async {
    final spreadsheetId = await ensureSpreadsheetExists();
    final client = await _getClient();
    final sheetsDataSource = GoogleSheetsDataSource(client);

    final row = _investmentToRow(investment);
    await sheetsDataSource.appendRows(spreadsheetId, 'Investments!A:G', [row]);

    debugPrint('[CloudRepo] Added investment: ${investment.name}');
    return investment;
  }

  @override
  Future<void> updateInvestment(InvestmentEntity investment) async {
    final spreadsheetId = await _getSpreadsheetId();
    final client = await _getClient();
    final sheetsDataSource = GoogleSheetsDataSource(client);

    final row = _investmentToRow(investment);
    final success = await sheetsDataSource.updateRowById(
      spreadsheetId,
      'Investments',
      investment.id,
      row,
      _investmentHeaders.length,
    );

    if (!success) {
      throw Exception('Investment not found in cloud: ${investment.id}');
    }
    debugPrint('[CloudRepo] Updated investment: ${investment.name}');
  }

  @override
  Future<void> deleteInvestment(String investmentId) async {
    final spreadsheetId = await _getSpreadsheetId();
    final client = await _getClient();
    final sheetsDataSource = GoogleSheetsDataSource(client);

    // First delete all cash flows for this investment
    final cashFlows = await fetchAllCashFlows();
    for (final cf in cashFlows.where((cf) => cf.investmentId == investmentId)) {
      await sheetsDataSource.deleteRowById(spreadsheetId, 'CashFlows', cf.id);
    }

    // Then delete the investment
    await sheetsDataSource.deleteRowById(spreadsheetId, 'Investments', investmentId);
    debugPrint('[CloudRepo] Deleted investment: $investmentId');
  }

  // ============ CASH FLOWS ============

  @override
  Future<List<CashFlowEntity>> fetchAllCashFlows() async {
    try {
      final client = await _getClient();
      final driveDataSource = GoogleDriveDataSource(client);
      final existingId = await driveDataSource.findSpreadsheetByName(_spreadsheetName);

      if (existingId == null) return [];

      final sheetsDataSource = GoogleSheetsDataSource(client);
      final rows = await sheetsDataSource.readSheet(existingId, 'CashFlows!A:H');
      if (rows == null || rows.length <= 1) return [];

      final cashFlows = <CashFlowEntity>[];
      for (int i = 1; i < rows.length; i++) {
        final cashFlow = _rowToCashFlow(rows[i]);
        if (cashFlow != null) {
          cashFlows.add(cashFlow);
        }
      }

      debugPrint('[CloudRepo] Fetched ${cashFlows.length} cash flows');
      return cashFlows;
    } catch (e) {
      debugPrint('[CloudRepo] Error fetching cash flows: $e');
      rethrow;
    }
  }

  @override
  Future<CashFlowEntity> addCashFlow(CashFlowEntity cashFlow) async {
    final spreadsheetId = await ensureSpreadsheetExists();
    final client = await _getClient();
    final sheetsDataSource = GoogleSheetsDataSource(client);

    // Get investment name for the row
    final investments = await fetchAllInvestments();
    final investment = investments.where((i) => i.id == cashFlow.investmentId).firstOrNull;
    final investmentName = investment?.name ?? 'Unknown';

    final row = _cashFlowToRow(cashFlow, investmentName);
    await sheetsDataSource.appendRows(spreadsheetId, 'CashFlows!A:H', [row]);

    debugPrint('[CloudRepo] Added cash flow: ${cashFlow.id}');
    return cashFlow;
  }

  @override
  Future<void> updateCashFlow(CashFlowEntity cashFlow) async {
    final spreadsheetId = await _getSpreadsheetId();
    final client = await _getClient();
    final sheetsDataSource = GoogleSheetsDataSource(client);

    // Get investment name for the row
    final investments = await fetchAllInvestments();
    final investment = investments.where((i) => i.id == cashFlow.investmentId).firstOrNull;
    final investmentName = investment?.name ?? 'Unknown';

    final row = _cashFlowToRow(cashFlow, investmentName);
    final success = await sheetsDataSource.updateRowById(
      spreadsheetId,
      'CashFlows',
      cashFlow.id,
      row,
      _cashFlowHeaders.length,
    );

    if (!success) {
      throw Exception('CashFlow not found in cloud: ${cashFlow.id}');
    }
    debugPrint('[CloudRepo] Updated cash flow: ${cashFlow.id}');
  }

  @override
  Future<void> deleteCashFlow(String cashFlowId) async {
    final spreadsheetId = await _getSpreadsheetId();
    final client = await _getClient();
    final sheetsDataSource = GoogleSheetsDataSource(client);

    await sheetsDataSource.deleteRowById(spreadsheetId, 'CashFlows', cashFlowId);
    debugPrint('[CloudRepo] Deleted cash flow: $cashFlowId');
  }

  // ============ BULK OPERATIONS ============

  @override
  Future<void> uploadAll(
    List<InvestmentEntity> investments,
    List<CashFlowEntity> cashFlows,
  ) async {
    final spreadsheetId = await ensureSpreadsheetExists();
    final client = await _getClient();
    final sheetsDataSource = GoogleSheetsDataSource(client);

    final investmentNameMap = {for (var inv in investments) inv.id: inv.name};

    // Build sheet data with headers
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

    // Clear and write CashFlows
    await sheetsDataSource.clearSheet(spreadsheetId, 'CashFlows!A:H');
    await sheetsDataSource.batchAppendRows(spreadsheetId, 'CashFlows!A:H', cashFlowRows);

    debugPrint('[CloudRepo] Uploaded ${investments.length} investments, ${cashFlows.length} cash flows');
  }

  // ============ MAPPERS ============

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

  InvestmentEntity? _rowToInvestment(List<dynamic> row) {
    try {
      if (row.length < 7) return null;

      final id = row[0]?.toString();
      final name = row[1]?.toString();
      if (id == null || id.isEmpty || name == null || name.isEmpty) return null;
      if (id == 'ID') return null; // Skip header

      final typeStr = row[2]?.toString() ?? '';
      InvestmentType type = InvestmentType.other;
      for (final t in InvestmentType.values) {
        if (t.displayName.toLowerCase() == typeStr.toLowerCase()) {
          type = t;
          break;
        }
      }

      final statusStr = (row[3]?.toString() ?? 'open').toLowerCase();
      final status = statusStr == 'closed' ? InvestmentStatus.closed : InvestmentStatus.open;

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
      debugPrint('[CloudRepo] Error parsing investment row: $e');
      return null;
    }
  }

  CashFlowEntity? _rowToCashFlow(List<dynamic> row) {
    try {
      if (row.length < 8) return null;

      final id = row[0]?.toString();
      final investmentId = row[1]?.toString();
      if (id == null || id.isEmpty || investmentId == null || investmentId.isEmpty) return null;
      if (id == 'ID') return null; // Skip header

      final typeStr = row[3]?.toString() ?? '';
      CashFlowType type = CashFlowType.invest;
      for (final t in CashFlowType.values) {
        if (t.displayName.toLowerCase() == typeStr.toLowerCase()) {
          type = t;
          break;
        }
      }

      DateTime date;
      try {
        date = _dateFormat.parse(row[4]?.toString() ?? '');
      } catch (_) {
        date = DateTime.now();
      }

      double amount;
      try {
        amount = double.parse(row[5]?.toString() ?? '0');
      } catch (_) {
        amount = 0;
      }

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
      debugPrint('[CloudRepo] Error parsing cashflow row: $e');
      return null;
    }
  }
}

