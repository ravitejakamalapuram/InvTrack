import 'dart:convert';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/sync/data/datasources/google_drive_datasource.dart';
import 'package:inv_tracker/features/sync/data/datasources/google_sheets_datasource.dart';



final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref);
});

class SyncService {
  final Ref _ref;
  static const String _spreadsheetName = 'InvTracker_Data';

  SyncService(this._ref);

  Future<void> sync() async {
    final googleSignIn = _ref.read(googleSignInProvider);
    final currentUser = googleSignIn.currentUser;
    
    if (currentUser == null) {
      // Not signed in, cannot sync
      return;
    }

    try {
      final client = await googleSignIn.authenticatedClient();
      if (client == null) {
        throw Exception('Failed to get authenticated client');
      }

      final driveDataSource = GoogleDriveDataSource(client);
      final sheetsDataSource = GoogleSheetsDataSource(client);

      // 1. Get or Create Spreadsheet
      final spreadsheetId = await driveDataSource.getOrCreateSpreadsheet(_spreadsheetName);

      // 2. Ensure Sheets Exist
      await sheetsDataSource.createSheetIfNotExists(spreadsheetId, 'Investments');
      await sheetsDataSource.createSheetIfNotExists(spreadsheetId, 'CashFlows');

      // 3. Process Sync Queue (Local -> Remote)
      await _pushLocalChanges(spreadsheetId, sheetsDataSource);

      // 4. Pull Remote Changes (Remote -> Local)
      await _pullRemoteChanges(spreadsheetId, sheetsDataSource);

    } catch (e) {
      debugPrint('Sync failed: $e');
      rethrow;
    }
  }

  Future<void> retryItem(int id) async {
    await _ref.read(syncRepositoryProvider).retryItem(id);
    // Optionally trigger sync immediately
    sync();
  }

  Future<void> _pushLocalChanges(String spreadsheetId, GoogleSheetsDataSource sheetsDataSource) async {
    final syncRepo = _ref.read(syncRepositoryProvider);
    final pendingItems = await syncRepo.getPendingItems();

    for (final item in pendingItems) {
      try {
        final sheetName = _getSheetName(item.entityType);
        
        if (item.operation == 'CREATE') {
          final payload = jsonDecode(item.payload) as Map<String, dynamic>;
          final values = _mapPayloadToRow(item.entityType, payload);
          await sheetsDataSource.appendRows(spreadsheetId, '$sheetName!A:A', [values]);
        }
        // TODO: Handle UPDATE and DELETE

        await syncRepo.deleteItem(item.id);
      } catch (e) {
        debugPrint('Error syncing item ${item.id}: $e');
        await syncRepo.markAsFailed(item.id);
      }
    }
  }

  Future<void> _pullRemoteChanges(String spreadsheetId, GoogleSheetsDataSource sheetsDataSource) async {
    // Investments
    final investmentRows = await sheetsDataSource.readSheet(spreadsheetId, 'Investments!A:G');
    if (investmentRows != null && investmentRows.isNotEmpty) {
      for (final row in investmentRows) {
        if (row.isNotEmpty && row[0] == 'id') continue;
        final investment = _mapRowToInvestment(row);
        if (investment != null) {
          try {
            await _ref.read(investmentRepositoryProvider).createInvestment(investment);
          } catch (e) {
            // Ignore if exists
          }
        }
      }
    }

    // CashFlows
    final cashFlowRows = await sheetsDataSource.readSheet(spreadsheetId, 'CashFlows!A:G');
    if (cashFlowRows != null && cashFlowRows.isNotEmpty) {
      for (final row in cashFlowRows) {
        if (row.isNotEmpty && row[0] == 'id') continue;
        final cashFlow = _mapRowToCashFlow(row);
        if (cashFlow != null) {
          try {
            await _ref.read(investmentRepositoryProvider).addCashFlow(cashFlow);
          } catch (e) {
            // Ignore if exists
          }
        }
      }
    }
  }

  InvestmentEntity? _mapRowToInvestment(List<dynamic> row) {
    try {
      if (row.length < 7) return null;

      // Parse investment type
      InvestmentType investmentType = InvestmentType.other;
      final typeStr = row[2].toString().toLowerCase();
      for (final t in InvestmentType.values) {
        if (t.name.toLowerCase() == typeStr) {
          investmentType = t;
          break;
        }
      }

      // Parse status
      final statusStr = row[3].toString().toLowerCase();
      final status = statusStr == 'closed'
          ? InvestmentStatus.closed
          : InvestmentStatus.open;

      return InvestmentEntity(
        id: row[0].toString(),
        name: row[1].toString(),
        type: investmentType,
        status: status,
        notes: row[4].toString() == 'null' ? null : row[4].toString(),
        createdAt: DateTime.parse(row[5].toString()),
        updatedAt: DateTime.parse(row[6].toString()),
      );
    } catch (e) {
      debugPrint('Error parsing investment row: $e');
      return null;
    }
  }

  CashFlowEntity? _mapRowToCashFlow(List<dynamic> row) {
    try {
      if (row.length < 7) return null;

      // Parse cash flow type
      CashFlowType cashFlowType = CashFlowType.invest;
      final typeStr = row[2].toString().toLowerCase();
      for (final t in CashFlowType.values) {
        if (t.name.toLowerCase() == typeStr) {
          cashFlowType = t;
          break;
        }
      }

      return CashFlowEntity(
        id: row[0].toString(),
        investmentId: row[1].toString(),
        type: cashFlowType,
        date: DateTime.parse(row[3].toString()),
        amount: double.parse(row[4].toString()),
        notes: row[5].toString() == 'null' ? null : row[5].toString(),
        createdAt: DateTime.parse(row[6].toString()),
      );
    } catch (e) {
      debugPrint('Error parsing cash flow row: $e');
      return null;
    }
  }

  String _getSheetName(String entityType) {
    switch (entityType) {
      case 'INVESTMENT':
        return 'Investments';
      case 'CASHFLOW':
        return 'CashFlows';
      default:
        return 'Unknown';
    }
  }

  List<dynamic> _mapPayloadToRow(String entityType, Map<String, dynamic> payload) {
    switch (entityType) {
      case 'INVESTMENT':
        return [
          payload['id'],
          payload['name'],
          payload['type'],
          payload['status'],
          payload['notes'],
          payload['createdAt'],
          payload['updatedAt'],
        ];
      case 'CASHFLOW':
        return [
          payload['id'],
          payload['investmentId'],
          payload['type'],
          payload['date'],
          payload['amount'],
          payload['notes'],
          payload['createdAt'],
        ];
      default:
        return [];
    }
  }
}
