import 'dart:convert';
import 'dart:typed_data';
import 'package:any_date/any_date.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

/// Parsed row from CSV import
class ParsedCashFlowRow {
  final int rowNumber;
  final DateTime date;
  final String investmentName;
  final CashFlowType type;
  final double amount;
  final String? notes;
  final String? error;

  const ParsedCashFlowRow({
    required this.rowNumber,
    required this.date,
    required this.investmentName,
    required this.type,
    required this.amount,
    this.notes,
    this.error,
  });

  bool get isValid => error == null;

  ParsedCashFlowRow.withError({
    required this.rowNumber,
    required this.error,
  })  : date = DateTime.now(),
        investmentName = '',
        type = CashFlowType.invest,
        amount = 0,
        notes = null;
}

/// Result of parsing a CSV file
class ParsedCsvResult {
  final List<ParsedCashFlowRow> rows;
  final List<String> errors;
  final int totalRows;
  final int validRows;

  const ParsedCsvResult({
    required this.rows,
    required this.errors,
    required this.totalRows,
    required this.validRows,
  });

  bool get hasErrors => errors.isNotEmpty;
  List<ParsedCashFlowRow> get validRowsOnly => rows.where((r) => r.isValid).toList();
}

/// Simple CSV parser with smart date inference
class SimpleCsvParser {
  /// Common date formats to try (in order of priority)
  static final List<DateFormat> _dateFormats = [
    DateFormat('yyyy-MM-dd'),
    DateFormat('dd-MM-yyyy'),
    DateFormat('MM-dd-yyyy'),
    DateFormat('dd/MM/yyyy'),
    DateFormat('MM/dd/yyyy'),
    DateFormat('yyyy/MM/dd'),
    DateFormat('d-MMM-yyyy'),
    DateFormat('dd-MMM-yyyy'),
    DateFormat('MMM d, yyyy'),
    DateFormat('MMMM d, yyyy'),
    DateFormat('d/M/yyyy'),
    DateFormat('M/d/yyyy'),
    DateFormat('MMM-yy'), // Jan-21 format
    DateFormat('MMMM-yy'), // January-21 format
    DateFormat('MM-yy'), // 01-21 format
    DateFormat('MM/yy'), // 01/21 format
    // Excel serial date handled separately
  ];

  /// Parse CSV bytes into structured data
  static ParsedCsvResult parse(Uint8List bytes) {
    final content = utf8.decode(bytes);
    return parseString(content);
  }

  /// Parse CSV string content
  static ParsedCsvResult parseString(String content) {
    final lines = const LineSplitter().convert(content);
    if (lines.isEmpty) {
      return const ParsedCsvResult(
        rows: [],
        errors: ['Empty file'],
        totalRows: 0,
        validRows: 0,
      );
    }

    // Parse header row
    final headerRow = _parseCSVLine(lines.first);
    final columnMap = _mapColumns(headerRow);

    if (!columnMap.containsKey('date') || !columnMap.containsKey('investment') ||
        !columnMap.containsKey('type') || !columnMap.containsKey('amount')) {
      return ParsedCsvResult(
        rows: [],
        errors: ['Missing required columns. Required: Date, Investment Name, Type, Amount'],
        totalRows: lines.length - 1,
        validRows: 0,
      );
    }

    final rows = <ParsedCashFlowRow>[];
    final errors = <String>[];

    // Parse data rows (skip header)
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final values = _parseCSVLine(line);
      final result = _parseRow(i + 1, values, columnMap);

      if (result.isValid) {
        rows.add(result);
      } else {
        errors.add('Row ${result.rowNumber}: ${result.error}');
      }
    }

    return ParsedCsvResult(
      rows: rows,
      errors: errors,
      totalRows: lines.length - 1,
      validRows: rows.where((r) => r.isValid).length,
    );
  }

  /// Map column headers to indices
  static Map<String, int> _mapColumns(List<String> headers) {
    final map = <String, int>{};
    for (var i = 0; i < headers.length; i++) {
      final header = headers[i].toLowerCase().trim();
      if (header.contains('date')) {
        map['date'] = i;
      } else if (header.contains('investment') || header.contains('name')) {
        map['investment'] = i;
      } else if (header.contains('type')) {
        map['type'] = i;
      } else if (header.contains('amount')) {
        map['amount'] = i;
      } else if (header.contains('note')) {
        map['notes'] = i;
      }
    }
    return map;
  }

  /// Parse a single CSV line handling quotes
  static List<String> _parseCSVLine(String line) {
    final result = <String>[];
    var current = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString().trim());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString().trim());
    return result;
  }

  /// Parse a single row
  static ParsedCashFlowRow _parseRow(int rowNum, List<String> values, Map<String, int> columnMap) {
    try {
      final dateStr = _getValue(values, columnMap['date']!);
      final investmentName = _getValue(values, columnMap['investment']!);
      final typeStr = _getValue(values, columnMap['type']!);
      final amountStr = _getValue(values, columnMap['amount']!);
      final notes = columnMap.containsKey('notes') ? _getValue(values, columnMap['notes']!) : null;

      // Validate required fields
      if (dateStr.isEmpty) return ParsedCashFlowRow.withError(rowNumber: rowNum, error: 'Missing date');
      if (investmentName.isEmpty) return ParsedCashFlowRow.withError(rowNumber: rowNum, error: 'Missing investment name');
      if (typeStr.isEmpty) return ParsedCashFlowRow.withError(rowNumber: rowNum, error: 'Missing type');
      if (amountStr.isEmpty) return ParsedCashFlowRow.withError(rowNumber: rowNum, error: 'Missing amount');

      // Parse date
      final date = _parseDate(dateStr);
      if (date == null) return ParsedCashFlowRow.withError(rowNumber: rowNum, error: 'Invalid date: $dateStr');

      // Parse type
      final type = _parseType(typeStr);
      if (type == null) return ParsedCashFlowRow.withError(rowNumber: rowNum, error: 'Invalid type: $typeStr');

      // Parse amount
      final amount = _parseAmount(amountStr);
      if (amount == null) return ParsedCashFlowRow.withError(rowNumber: rowNum, error: 'Invalid amount: $amountStr');

      return ParsedCashFlowRow(
        rowNumber: rowNum,
        date: date,
        investmentName: investmentName.trim(),
        type: type,
        amount: amount,
        notes: notes?.isNotEmpty == true ? notes : null,
      );
    } catch (e) {
      return ParsedCashFlowRow.withError(rowNumber: rowNum, error: 'Parse error: $e');
    }
  }

  static String _getValue(List<String> values, int index) {
    return index < values.length ? values[index].trim() : '';
  }

  /// Flexible date parser that handles any format
  static final AnyDate _dateParser = AnyDate(
    info: const DateParserInfo(dayFirst: true), // Prefer day-first for non-US formats
  );

  /// Month name variations for custom month-year parsing
  /// Handles common abbreviations and full names
  static final Map<String, int> _monthNames = {
    // 3-letter abbreviations
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    // 4-letter abbreviations (common variations)
    'sept': 9,
    // Full names
    'january': 1, 'february': 2, 'march': 3, 'april': 4, 'june': 6,
    'july': 7, 'august': 8, 'september': 9, 'october': 10, 'november': 11, 'december': 12,
  };

  /// Parse date with smart format detection
  static DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;

    // Check for Excel serial date (number like 45678)
    final serialNum = double.tryParse(dateStr);
    if (serialNum != null && serialNum > 25000 && serialNum < 60000) {
      return DateTime(1899, 12, 30).add(Duration(days: serialNum.toInt()));
    }

    // Try month-year format first (e.g., Jan-21, Sept-25, Feb/22)
    // This format is common in financial data but not supported by any_date
    final monthYearMatch = RegExp(r'^([A-Za-z]+)[-/\s](\d{2,4})$').firstMatch(dateStr);
    if (monthYearMatch != null) {
      final monthStr = monthYearMatch.group(1)!.toLowerCase();
      final yearStr = monthYearMatch.group(2)!;
      final month = _monthNames[monthStr];
      if (month != null) {
        final year = yearStr.length == 2 ? 2000 + int.parse(yearStr) : int.parse(yearStr);
        return DateTime(year, month, 1);
      }
    }

    // Try any_date library for flexible full-date parsing
    try {
      return _dateParser.parse(dateStr);
    } catch (_) {
      // Fallback: try manual date formats
      for (final format in _dateFormats) {
        try {
          return format.parseStrict(dateStr);
        } catch (_) {}
      }
      return null;
    }
  }

  /// Parse cash flow type
  static CashFlowType? _parseType(String typeStr) {
    final normalized = typeStr.toLowerCase().trim();
    switch (normalized) {
      case 'invest':
      case 'investment':
      case 'invested':
      case 'deposit':
        return CashFlowType.invest;
      case 'income':
      case 'interest':
      case 'dividend':
      case 'payout':
        return CashFlowType.income;
      case 'return':
      case 'withdrawal':
      case 'withdraw':
      case 'maturity':
      case 'exit':
        return CashFlowType.returnFlow;
      case 'fee':
      case 'fees':
      case 'charge':
      case 'expense':
        return CashFlowType.fee;
      default:
        return null;
    }
  }

  /// Parse amount, removing currency symbols and commas
  static double? _parseAmount(String amountStr) {
    if (amountStr.isEmpty) return null;
    final cleaned = amountStr
        .replaceAll(RegExp(r'[₹$€£¥,\s]'), '')
        .replaceAll('(', '-')
        .replaceAll(')', '');
    return double.tryParse(cleaned);
  }
}
