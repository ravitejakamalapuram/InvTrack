import 'dart:io';
import 'package:csv/csv.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';
import 'package:inv_tracker/features/portfolio/domain/repositories/portfolio_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportService {
  final InvestmentRepository _investmentRepository;
  final PortfolioRepository _portfolioRepository;

  ExportService(this._investmentRepository, this._portfolioRepository);

  Future<void> exportToCsv() async {
    // 1. Fetch Data
    final transactions = await _investmentRepository.getAllTransactions();
    final investments = await _investmentRepository.getAllInvestments();
    final portfolios = await _portfolioRepository.getAllPortfolios();

    // Create Lookups
    final investmentMap = {for (var i in investments) i.id: i};
    final portfolioMap = {for (var p in portfolios) p.id: p};

    // 2. Prepare CSV Data
    final List<List<dynamic>> rows = [];

    // Header Row
    rows.add([
      'Date',
      'Portfolio',
      'Symbol',
      'Name',
      'Type',
      'Quantity',
      'Price',
      'Fees',
      'Total Amount',
      'Notes',
    ]);

    // Data Rows
    for (final tx in transactions) {
      final investment = investmentMap[tx.investmentId];
      final portfolio = investment != null ? portfolioMap[investment.portfolioId] : null;

      rows.add([
        tx.date.toIso8601String().split('T').first,
        portfolio?.name ?? 'Unknown',
        investment?.symbol ?? '',
        investment?.name ?? 'Unknown',
        tx.type,
        tx.quantity,
        tx.pricePerUnit,
        tx.fees,
        tx.totalAmount,
        tx.notes ?? '',
      ]);
    }

    // 3. Generate CSV String
    final csvData = const ListToCsvConverter().convert(rows);

    // 4. Save to Temp File
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/invtracker_export_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(path);
    await file.writeAsString(csvData);

    // 5. Share File
    await Share.shareXFiles(
      [XFile(path)],
      text: 'Here is your InvTracker transaction history.',
      subject: 'InvTracker Export',
    );
  }
}
