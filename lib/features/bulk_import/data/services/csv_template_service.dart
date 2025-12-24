import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Service for generating and sharing CSV import templates
class CsvTemplateService {
  /// CSV headers for the template
  static const List<String> headers = [
    'Date',
    'Investment Name',
    'Type',
    'Amount',
    'Notes',
  ];

  /// Sample data rows covering all scenarios
  static const List<List<String>> sampleRows = [
    // Investment examples
    ['2024-01-15', 'Bhive Investment', 'INVEST', '100000', 'Initial investment'],
    ['2024-02-15', 'Bhive Investment', 'INCOME', '1500', 'Monthly interest'],
    ['2024-03-15', 'Bhive Investment', 'INCOME', '1500', 'Monthly interest'],
    // Another investment
    ['2024-01-20', 'P2P Lending - LenDenClub', 'INVEST', '50000', 'Started P2P'],
    ['2024-02-20', 'P2P Lending - LenDenClub', 'INCOME', '750', 'Interest received'],
    ['2024-03-20', 'P2P Lending - LenDenClub', 'RETURN', '10000', 'Partial withdrawal'],
    // Third investment with fees
    ['2024-02-01', 'Gold Bonds', 'INVEST', '200000', 'Sovereign Gold Bonds'],
    ['2024-08-01', 'Gold Bonds', 'INCOME', '2500', 'Interest payout'],
    // Investment with exit
    ['2023-06-01', 'Fixed Deposit - HDFC', 'INVEST', '100000', 'FD for 1 year'],
    ['2024-06-01', 'Fixed Deposit - HDFC', 'RETURN', '107000', 'Maturity amount'],
  ];

  /// Type descriptions for the template
  static const String typeDescription = '''
# Type Column Values:
# INVEST  - Money you put INTO the investment (outflow)
# INCOME  - Returns/dividends received while invested (inflow)
# RETURN  - Money withdrawn or returned from investment (inflow)
# FEE     - Fees paid (outflow)
''';

  /// Generates the template CSV content
  static String generateTemplateContent() {
    final buffer = StringBuffer();

    // Add header row
    buffer.writeln(headers.join(','));

    // Add sample data rows
    for (final row in sampleRows) {
      buffer.writeln(row.map(_escapeCSV).join(','));
    }

    return buffer.toString();
  }

  /// Escapes a value for CSV (handles commas, quotes)
  static String _escapeCSV(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Saves template to a file and shares it
  static Future<void> downloadTemplate() async {
    final content = generateTemplateContent();
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/investment_import_template.csv');
    await file.writeAsString(content);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Investment Import Template',
      ),
    );
  }

  /// Returns template as bytes for direct download
  static List<int> getTemplateBytes() {
    return utf8.encode(generateTemplateContent());
  }
}

