import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';
import 'package:uuid/uuid.dart';

class ImportResult {
  final int successCount;
  final int failureCount;
  final String message;

  ImportResult(this.successCount, this.failureCount, this.message);
}

class ImportService {
  final InvestmentRepository _investmentRepository;
  final Uuid _uuid = const Uuid();

  ImportService(this._investmentRepository);

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

      // Expected CSV format (matching ExportService):
      // Date, Investment Name, Investment Type, Cash Flow Type, Amount, Notes, Investment Status

      int successCount = 0;
      int failureCount = 0;

      // Cache for lookups
      final investments = await _investmentRepository.getAllInvestments();
      final investmentMap = {for (var i in investments) i.name.toLowerCase(): i};

      // 3. Process Rows (skip header)
      for (int i = 1; i < rows.length; i++) {
        try {
          final row = rows[i];
          if (row.isEmpty) continue;

          if (row.length < 5) {
            failureCount++;
            continue;
          }

          final dateStr = row[0].toString();
          final investmentName = row[1].toString().trim();
          final investmentTypeStr = row[2].toString().trim().toLowerCase();
          final cashFlowTypeStr = row[3].toString().trim().toLowerCase();
          final amount = double.tryParse(row[4].toString()) ?? 0.0;
          final notes = row.length > 5 ? row[5].toString() : null;
          final statusStr = row.length > 6 ? row[6].toString().trim().toLowerCase() : 'open';

          // Parse investment type
          InvestmentType investmentType = InvestmentType.other;
          for (final t in InvestmentType.values) {
            if (t.name.toLowerCase() == investmentTypeStr) {
              investmentType = t;
              break;
            }
          }

          // Parse cash flow type
          CashFlowType cashFlowType = CashFlowType.invest;
          for (final t in CashFlowType.values) {
            if (t.name.toLowerCase() == cashFlowTypeStr) {
              cashFlowType = t;
              break;
            }
          }

          // Parse status
          InvestmentStatus status = statusStr == 'closed'
              ? InvestmentStatus.closed
              : InvestmentStatus.open;

          // Find or Create Investment
          InvestmentEntity? investment = investmentMap[investmentName.toLowerCase()];

          if (investment == null) {
            investment = InvestmentEntity(
              id: _uuid.v4(),
              name: investmentName.isNotEmpty ? investmentName : 'Unknown',
              type: investmentType,
              status: status,
              notes: null,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            await _investmentRepository.createInvestment(investment);
            investmentMap[investmentName.toLowerCase()] = investment;
          }

          // Create Cash Flow
          final cashFlow = CashFlowEntity(
            id: _uuid.v4(),
            investmentId: investment.id,
            type: cashFlowType,
            date: DateTime.tryParse(dateStr) ?? DateTime.now(),
            amount: amount,
            notes: notes?.isNotEmpty == true ? notes : null,
            createdAt: DateTime.now(),
          );

          await _investmentRepository.addCashFlow(cashFlow);
          successCount++;

        } catch (e) {
          debugPrint('Error importing row $i: $e');
          failureCount++;
        }
      }

      return ImportResult(successCount, failureCount, 'Import completed');

    } catch (e) {
      return ImportResult(0, 0, 'Import failed: $e');
    }
  }
}
