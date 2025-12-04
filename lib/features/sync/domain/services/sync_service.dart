import 'dart:convert';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/portfolio/domain/entities/portfolio_entity.dart';
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
      await sheetsDataSource.createSheetIfNotExists(spreadsheetId, 'Portfolios');
      await sheetsDataSource.createSheetIfNotExists(spreadsheetId, 'Investments');
      await sheetsDataSource.createSheetIfNotExists(spreadsheetId, 'Transactions');

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
    // Portfolios
    final portfolioRows = await sheetsDataSource.readSheet(spreadsheetId, 'Portfolios!A:D');
    if (portfolioRows != null && portfolioRows.isNotEmpty) {
      for (final row in portfolioRows) {
        // Skip header if present (simple check, assuming header is first row and has "id")
        if (row.isNotEmpty && row[0] == 'id') continue;
        
        final portfolio = _mapRowToPortfolio(row);
        if (portfolio != null) {
          // Check if exists locally
          // For MVP, we just overwrite or create if missing. 
          // Real conflict resolution would compare updated_at.
          // Since we don't have easy access to "getById" without repository, we rely on repository "create" handling conflict (e.g. replace)
          // But our repositories currently might throw or ignore.
          // Let's assume "create" is actually "upsert" or we check first.
          // For now, let's just try to create and catch exception if it exists (or ignore).
          // Better: Check if exists.
          
          // TODO: Implement robust upsert. For now, we skip if exists to avoid unique constraint error, 
          // or we need repository to support upsert.
          // Let's assume we just want to bring in NEW items for now to avoid complexity.
          try {
             await _ref.read(portfolioRepositoryProvider).createPortfolio(portfolio);
          } catch (e) {
            // Likely exists. In a real sync, we'd check timestamps and update if remote is newer.
          }
        }
      }
    }

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

    // Transactions
    final transactionRows = await sheetsDataSource.readSheet(spreadsheetId, 'Transactions!A:J');
    if (transactionRows != null && transactionRows.isNotEmpty) {
      for (final row in transactionRows) {
        if (row.isNotEmpty && row[0] == 'id') continue;
        final transaction = _mapRowToTransaction(row);
        if (transaction != null) {
          try {
            await _ref.read(investmentRepositoryProvider).addTransaction(transaction);
          } catch (e) {
            // Ignore if exists
          }
        }
      }
    }
  }

  PortfolioEntity? _mapRowToPortfolio(List<dynamic> row) {
    try {
      if (row.length < 4) return null;
      return PortfolioEntity(
        id: row[0].toString(),
        name: row[1].toString(),
        currency: row[2].toString(),
        createdAt: DateTime.parse(row[3].toString()),
      );
    } catch (e) {
      debugPrint('Error parsing portfolio row: $e');
      return null;
    }
  }

  InvestmentEntity? _mapRowToInvestment(List<dynamic> row) {
    try {
      if (row.length < 7) return null;
      return InvestmentEntity(
        id: row[0].toString(),
        portfolioId: row[1].toString(),
        name: row[2].toString(),
        symbol: row[3].toString() == 'null' ? null : row[3].toString(),
        type: row[4].toString(),
        isActive: row[5].toString().toLowerCase() == 'true',
        createdAt: DateTime.parse(row[6].toString()),
        updatedAt: DateTime.now(), // Sheet might not have updated_at for all, or we use created_at
      );
    } catch (e) {
      debugPrint('Error parsing investment row: $e');
      return null;
    }
  }

  TransactionEntity? _mapRowToTransaction(List<dynamic> row) {
    try {
      if (row.length < 10) return null;
      return TransactionEntity(
        id: row[0].toString(),
        investmentId: row[1].toString(),
        date: DateTime.parse(row[2].toString()),
        type: row[3].toString(),
        quantity: double.parse(row[4].toString()),
        pricePerUnit: double.parse(row[5].toString()),
        fees: double.parse(row[6].toString()),
        totalAmount: double.parse(row[7].toString()),
        notes: row[8].toString() == 'null' ? null : row[8].toString(),
        createdAt: DateTime.parse(row[9].toString()),
      );
    } catch (e) {
      debugPrint('Error parsing transaction row: $e');
      return null;
    }
  }

  String _getSheetName(String entityType) {
    switch (entityType) {
      case 'PORTFOLIO':
        return 'Portfolios';
      case 'INVESTMENT':
        return 'Investments';
      case 'TRANSACTION':
        return 'Transactions';
      default:
        return 'Unknown';
    }
  }

  List<dynamic> _mapPayloadToRow(String entityType, Map<String, dynamic> payload) {
    // Simple mapping based on JSON keys order or specific fields
    // Ideally, we should have a defined schema order
    switch (entityType) {
      case 'PORTFOLIO':
        return [payload['id'], payload['name'], payload['currency'], payload['createdAt']];
      case 'INVESTMENT':
        return [payload['id'], payload['portfolioId'], payload['name'], payload['symbol'], payload['type'], payload['isActive'], payload['createdAt']];
      case 'TRANSACTION':
        return [payload['id'], payload['investmentId'], payload['date'], payload['type'], payload['quantity'], payload['pricePerUnit'], payload['fees'], payload['totalAmount'], payload['notes'], payload['createdAt']];
      default:
        return [];
    }
  }
}
