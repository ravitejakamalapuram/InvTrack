import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Service for generating and sharing CSV import templates
class CsvTemplateService {
  /// CSV headers for the template
  /// Note: Currency, Investment Type and Investment Status are optional columns
  static const List<String> headers = [
    'Date',
    'Investment Name',
    'Type',
    'Amount',
    'Currency',
    'Notes',
    'Investment Type',
    'Investment Status',
  ];

  /// Sample data rows covering all scenarios
  /// Includes optional Currency, Investment Type and Investment Status columns
  static const List<List<String>> sampleRows = [
    // Investment examples with type and status (INR)
    [
      '2024-01-15',
      'Bhive Investment',
      'INVEST',
      '100000',
      'INR',
      'Initial investment',
      'p2p',
      'open',
    ],
    [
      '2024-02-15',
      'Bhive Investment',
      'INCOME',
      '1500',
      'INR',
      'Monthly interest',
      'p2p',
      'open',
    ],
    [
      '2024-03-15',
      'Bhive Investment',
      'INCOME',
      '1500',
      'INR',
      'Monthly interest',
      'p2p',
      'open',
    ],
    // Another investment (INR)
    [
      '2024-01-20',
      'P2P Lending - LenDenClub',
      'INVEST',
      '50000',
      'INR',
      'Started P2P',
      'p2p',
      'open',
    ],
    [
      '2024-02-20',
      'P2P Lending - LenDenClub',
      'INCOME',
      '750',
      'INR',
      'Interest received',
      'p2p',
      'open',
    ],
    [
      '2024-03-20',
      'P2P Lending - LenDenClub',
      'RETURN',
      '10000',
      'INR',
      'Partial withdrawal',
      'p2p',
      'open',
    ],
    // Third investment with fees (INR)
    [
      '2024-02-01',
      'Gold Bonds',
      'INVEST',
      '200000',
      'INR',
      'Sovereign Gold Bonds',
      'bonds',
      'open',
    ],
    [
      '2024-08-01',
      'Gold Bonds',
      'INCOME',
      '2500',
      'INR',
      'Interest payout',
      'bonds',
      'open',
    ],
    // Investment with exit (closed status, INR)
    [
      '2023-06-01',
      'Fixed Deposit - HDFC',
      'INVEST',
      '100000',
      'INR',
      'FD for 1 year',
      'fixedDeposit',
      'closed',
    ],
    [
      '2024-06-01',
      'Fixed Deposit - HDFC',
      'RETURN',
      '107000',
      'INR',
      'Maturity amount',
      'fixedDeposit',
      'closed',
    ],
    // Multi-currency example (USD)
    [
      '2024-01-10',
      'US Stocks - Apple',
      'INVEST',
      '5000',
      'USD',
      'Tech stock investment',
      'stocks',
      'open',
    ],
    [
      '2024-03-10',
      'US Stocks - Apple',
      'INCOME',
      '50',
      'USD',
      'Dividend',
      'stocks',
      'open',
    ],
    // Multi-currency example (EUR)
    [
      '2024-02-01',
      'European Bonds',
      'INVEST',
      '3000',
      'EUR',
      'EU government bonds',
      'bonds',
      'open',
    ],
  ];

  /// Type descriptions for the template
  static const String typeDescription = '''
# Type Column Values (required):
# INVEST  - Money you put INTO the investment (outflow)
# INCOME  - Returns/dividends received while invested (inflow)
# RETURN  - Money withdrawn or returned from investment (inflow)
# FEE     - Fees paid (outflow)
#
# Currency Column Values (optional, defaults to base currency):
# Use ISO 4217 currency codes: INR, USD, EUR, GBP, JPY, CAD, AUD, CHF, CNY, SGD, HKD, AED, SAR, BRL, MXN, ZAR
#
# Investment Type Column Values (optional):
# p2p, fixedDeposit, bonds, mutualFund, stocks, realEstate, gold, crypto, other
#
# Investment Status Column Values (optional):
# open, closed
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
    // Security: Use temp directory to prevent sensitive templates from persisting or syncing to cloud backups
    final directory = await getTemporaryDirectory();
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
