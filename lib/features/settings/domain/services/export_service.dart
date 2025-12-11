import 'dart:io';
import 'package:csv/csv.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportService {
  final InvestmentRepository _investmentRepository;

  ExportService(this._investmentRepository);

  Future<void> exportToCsv() async {
    // 1. Fetch Data
    final investments = await _investmentRepository.getAllInvestments();
    final allCashFlows = <Map<String, dynamic>>[];

    // Collect all cash flows with investment info
    for (final investment in investments) {
      final cashFlows = await _investmentRepository.getCashFlowsByInvestment(investment.id);
      for (final cf in cashFlows) {
        allCashFlows.add({
          'cashFlow': cf,
          'investment': investment,
        });
      }
    }

    // Sort by date
    allCashFlows.sort((a, b) =>
      (a['cashFlow'].date as DateTime).compareTo(b['cashFlow'].date as DateTime));

    // 2. Prepare CSV Data
    final List<List<dynamic>> rows = [];

    // Header Row
    rows.add([
      'Date',
      'Investment Name',
      'Investment Type',
      'Cash Flow Type',
      'Amount',
      'Notes',
      'Investment Status',
    ]);

    // Data Rows
    for (final item in allCashFlows) {
      final cf = item['cashFlow'];
      final investment = item['investment'];

      rows.add([
        cf.date.toIso8601String().split('T').first,
        investment.name,
        investment.type.name,
        cf.type.name,
        cf.amount,
        cf.notes ?? '',
        investment.status.name,
      ]);
    }

    // 3. Generate CSV String
    final csvData = const ListToCsvConverter().convert(rows);

    // 4. Save to Temp File
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/cashflow_export_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(path);
    await file.writeAsString(csvData);

    // 5. Share File
    await Share.shareXFiles(
      [XFile(path)],
      text: 'Here is your Cash Flow Tracker export.',
      subject: 'Cash Flow Tracker Export',
    );
  }
}
