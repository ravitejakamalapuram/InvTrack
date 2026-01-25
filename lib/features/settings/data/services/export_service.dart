import 'dart:io';
import 'package:csv/csv.dart';
import 'package:inv_tracker/core/utils/csv_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportService {
  final InvestmentRepository _investmentRepository;

  ExportService(this._investmentRepository);

  /// Converts CashFlowType to the format expected by import template
  String _typeToExportString(CashFlowType type) {
    switch (type) {
      case CashFlowType.invest:
        return 'INVEST';
      case CashFlowType.income:
        return 'INCOME';
      case CashFlowType.returnFlow:
        return 'RETURN';
      case CashFlowType.fee:
        return 'FEE';
    }
  }

  Future<void> exportToCsv() async {
    // 1. Fetch Data
    final investments = await _investmentRepository.getAllInvestments();
    final allCashFlows = <Map<String, dynamic>>[];

    // Collect all cash flows with investment info
    for (final investment in investments) {
      final cashFlows = await _investmentRepository.getCashFlowsByInvestment(
        investment.id,
      );
      for (final cf in cashFlows) {
        allCashFlows.add({'cashFlow': cf, 'investment': investment});
      }
    }

    // Sort by date
    allCashFlows.sort(
      (a, b) => (a['cashFlow'].date as DateTime).compareTo(
        b['cashFlow'].date as DateTime,
      ),
    );

    // 2. Prepare CSV Data - matching import template format exactly
    // Import template: Date, Investment Name, Type, Amount, Notes
    final List<List<dynamic>> rows = [];

    // Header Row - matches CsvTemplateService.headers exactly
    rows.add(['Date', 'Investment Name', 'Type', 'Amount', 'Notes']);

    // Data Rows
    for (final item in allCashFlows) {
      final cf = item['cashFlow'];
      final investment = item['investment'];

      rows.add([
        CsvUtils.sanitizeField(
          cf.date.toIso8601String().split('T').first,
        ), // yyyy-MM-dd format
        CsvUtils.sanitizeField(investment.name),
        CsvUtils.sanitizeField(
          _typeToExportString(cf.type),
        ), // INVEST, INCOME, RETURN, FEE
        CsvUtils.sanitizeField(cf.amount),
        CsvUtils.sanitizeField(cf.notes ?? ''),
      ]);
    }

    // 3. Generate CSV String
    final csvData = const ListToCsvConverter().convert(rows);

    // 4. Save to Temp File
    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/investments_export_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(path);
    await file.writeAsString(csvData);

    // 5. Share File
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        text:
            'Your InvTrack investments export. This file can be re-imported into the app.',
        subject: 'InvTrack Investments Export',
      ),
    );
  }
}
