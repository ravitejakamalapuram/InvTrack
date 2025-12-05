import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';
import 'package:inv_tracker/features/portfolio/domain/entities/portfolio_entity.dart';
import 'package:inv_tracker/features/portfolio/domain/repositories/portfolio_repository.dart';
import 'package:uuid/uuid.dart';

class ImportResult {
  final int successCount;
  final int failureCount;
  final String message;

  ImportResult(this.successCount, this.failureCount, this.message);
}

class ImportService {
  final InvestmentRepository _investmentRepository;
  final PortfolioRepository _portfolioRepository;
  final Uuid _uuid = const Uuid();

  ImportService(this._investmentRepository, this._portfolioRepository);

  Future<ImportResult> importFromCsv() async {
    try {
      // 1. Pick File
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.isEmpty) {
        return ImportResult(0, 0, 'No file selected');
      }

      final file = File(result.files.single.path!);
      final input = await file.readAsString();
      final List<List<dynamic>> rows = const CsvToListConverter().convert(input);

      if (rows.isEmpty || rows.length < 2) {
        return ImportResult(0, 0, 'Empty or invalid CSV file');
      }

      // 2. Parse Headers
      final headers = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
      // Expected: date, portfolio, symbol, name, type, quantity, price, fees, total amount, notes
      
      int successCount = 0;
      int failureCount = 0;

      // Cache for lookups to avoid DB calls per row
      final portfolios = await _portfolioRepository.getAllPortfolios();
      final portfolioMap = {for (var p in portfolios) p.name.toLowerCase(): p};

      // 3. Process Rows
      // Skip header
      for (int i = 1; i < rows.length; i++) {
        try {
          final row = rows[i];
          if (row.isEmpty) continue;

          // Extract Data (Assuming fixed order based on ExportService, but ideally should use headers)
          // For simplicity/robustness matching ExportService:
          // 0: Date, 1: Portfolio, 2: Symbol, 3: Name, 4: Type, 5: Qty, 6: Price, 7: Fees, 8: Total, 9: Notes
          
          if (row.length < 9) {
            failureCount++;
            continue;
          }

          final dateStr = row[0].toString();
          final portfolioName = row[1].toString().trim();
          final symbol = row[2].toString().trim();
          final name = row[3].toString().trim();
          final type = row[4].toString().trim().toUpperCase(); // BUY/SELL
          final quantity = double.tryParse(row[5].toString()) ?? 0.0;
          final price = double.tryParse(row[6].toString()) ?? 0.0;
          final fees = double.tryParse(row[7].toString()) ?? 0.0;
          final totalAmount = double.tryParse(row[8].toString()) ?? 0.0;
          final notes = row.length > 9 ? row[9].toString() : null;

          // Find or Create Portfolio
          PortfolioEntity? portfolioNullable = portfolioMap[portfolioName.toLowerCase()];
          PortfolioEntity portfolio;
          
          if (portfolioNullable == null) {
            portfolio = PortfolioEntity(
              id: _uuid.v4(),
              name: portfolioName,
              currency: 'USD', // Default
              createdAt: DateTime.now(),
            );
            await _portfolioRepository.createPortfolio(portfolio);
            portfolioMap[portfolioName.toLowerCase()] = portfolio;
          } else {
            portfolio = portfolioNullable;
          }

          // Find or Create Investment
          // We need to check if investment exists in this portfolio
          final investments = await _investmentRepository.getInvestmentsByPortfolio(portfolio.id);
          InvestmentEntity? investment;
          
          try {
            investment = investments.firstWhere(
              (inv) => (inv.symbol?.toLowerCase() == symbol.toLowerCase() && symbol.isNotEmpty) || 
                       (inv.name.toLowerCase() == name.toLowerCase()),
            );
          } catch (_) {
            // Not found
          }

          if (investment == null) {
            investment = InvestmentEntity(
              id: _uuid.v4(),
              portfolioId: portfolio.id,
              name: name.isNotEmpty ? name : (symbol.isNotEmpty ? symbol : 'Unknown'),
              symbol: symbol.isNotEmpty ? symbol : null,
              type: 'Stock', // Default
              isActive: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            await _investmentRepository.createInvestment(investment);
          }

          // Create Transaction
          final transaction = TransactionEntity(
            id: _uuid.v4(),
            investmentId: investment.id,
            date: DateTime.tryParse(dateStr) ?? DateTime.now(),
            type: type,
            quantity: quantity,
            pricePerUnit: price,
            fees: fees,
            totalAmount: totalAmount,
            notes: notes,
            createdAt: DateTime.now(),
          );

          await _investmentRepository.addTransaction(transaction);
          successCount++;

        } catch (e) {
          print('Error importing row $i: $e');
          failureCount++;
        }
      }

      return ImportResult(successCount, failureCount, 'Import completed');

    } catch (e) {
      return ImportResult(0, 0, 'Import failed: $e');
    }
  }
}
