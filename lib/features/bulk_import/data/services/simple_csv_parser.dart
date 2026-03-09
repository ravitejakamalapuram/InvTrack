import 'dart:convert';
import 'dart:typed_data';
import 'package:any_date/any_date.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

/// Parsed row from CSV import
class ParsedCashFlowRow {
  final int rowNumber;
  final DateTime date;
  final String investmentName;
  final CashFlowType type;
  final double amount;
  final String currency; // Multi-currency support (Rule 21.4)
  final String? notes;
  final String? error;

  /// Optional investment metadata (from enhanced export format)
  final InvestmentType? investmentType;
  final InvestmentStatus? investmentStatus;

  /// Optional currency code (for multi-currency support)
  /// Defaults to base currency if not specified
  final String? currency;

  const ParsedCashFlowRow({
    required this.rowNumber,
    required this.date,
    required this.investmentName,
    required this.type,
    required this.amount,
    this.currency,
    this.notes,
    this.error,
    this.investmentType,
    this.investmentStatus,
  });

  bool get isValid => error == null;

  ParsedCashFlowRow.withError({required this.rowNumber, required this.error})
    : date = DateTime.now(),
      investmentName = '',
      type = CashFlowType.invest,
      amount = 0,
      currency = null,
      notes = null,
      investmentType = null,
      investmentStatus = null;
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
  List<ParsedCashFlowRow> get validRowsOnly =>
      rows.where((r) => r.isValid).toList();
}

/// Simple CSV parser with smart date inference
class SimpleCsvParser {
  /// Common date format patterns to try (in order of priority)
  /// Note: We store patterns as strings and create DateFormat lazily to avoid
  /// initialization errors when the class is loaded before initializeDateFormatting()
  static const List<String> _dateFormatPatterns = [
    'yyyy-MM-dd',
    'dd-MM-yyyy',
    'MM-dd-yyyy',
    'dd/MM/yyyy',
    'MM/dd/yyyy',
    'yyyy/MM/dd',
    'd-MMM-yyyy',
    'dd-MMM-yyyy',
    'MMM d, yyyy',
    'MMMM d, yyyy',
    'd/M/yyyy',
    'M/d/yyyy',
    'MMM-yy', // Jan-21 format
    'MMMM-yy', // January-21 format
    'MM-yy', // 01-21 format
    'MM/yy', // 01/21 format
    // Excel serial date handled separately
  ];

  /// Parse CSV bytes into structured data
  static ParsedCsvResult parse(Uint8List bytes) {
    final content = utf8.decode(bytes);
    return parseString(content);
  }

  /// Parse CSV string content
  static ParsedCsvResult parseString(String content) {
    return _CsvParserSession(content).parse();
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
}

class _CsvParserSession {
  final String content;
  DateFormat? _detectedDateFormat;

  // Cache formatters by locale to avoid expensive re-creation
  static final Map<String, List<DateFormat>> _formattersCache = {};

  List<DateFormat> get _dateFormats {
    final locale = Intl.defaultLocale ?? 'default';
    return _formattersCache.putIfAbsent(locale, () {
      return SimpleCsvParser._dateFormatPatterns
          .map((p) => DateFormat(p, locale == 'default' ? null : locale))
          .toList();
    });
  }

  _CsvParserSession(this.content);

  ParsedCsvResult parse() {
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
    final headerRow = SimpleCsvParser._parseCSVLine(lines.first);
    final columnMap = _mapColumns(headerRow);

    if (!columnMap.containsKey('date') ||
        !columnMap.containsKey('investment') ||
        !columnMap.containsKey('type') ||
        !columnMap.containsKey('amount')) {
      return ParsedCsvResult(
        rows: [],
        errors: [
          'Missing required columns. Required: Date, Investment Name, Type, Amount',
        ],
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

      final values = SimpleCsvParser._parseCSVLine(line);
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
  Map<String, int> _mapColumns(List<String> headers) {
    final map = <String, int>{};
    for (var i = 0; i < headers.length; i++) {
      final header = headers[i].toLowerCase().trim();
      if (header.contains('date')) {
        map['date'] = i;
      } else if (header == 'investment name') {
        map['investment'] = i;
      } else if (header == 'investment type') {
        map['investmentType'] = i;
      } else if (header == 'investment status') {
        map['investmentStatus'] = i;
      } else if (header == 'type') {
        // Cashflow type (INVEST, INCOME, RETURN, FEE)
        map['type'] = i;
      } else if (header.contains('name') && !map.containsKey('investment')) {
        // Fallback for older CSV formats
        map['investment'] = i;
      } else if (header.contains('amount')) {
        map['amount'] = i;
      } else if (header.contains('currency')) {
        // Multi-currency support (Rule 21.4)
        map['currency'] = i;
      } else if (header.contains('note')) {
        map['notes'] = i;
      } else if (header.contains('currency')) {
        map['currency'] = i;
      }
    }
    return map;
  }

  /// Parse a single row
  ParsedCashFlowRow _parseRow(
    int rowNum,
    List<String> values,
    Map<String, int> columnMap,
  ) {
    try {
      final dateStr = _getValue(values, columnMap['date']!);
      final investmentName = _getValue(values, columnMap['investment']!);
      final typeStr = _getValue(values, columnMap['type']!);
      final amountStr = _getValue(values, columnMap['amount']!);
      final notes = columnMap.containsKey('notes')
          ? _getValue(values, columnMap['notes']!)
          : null;

      // Multi-currency support (Rule 21.4)
      // Default to 'USD' if currency column is missing (backward compatibility)
      final currency = columnMap.containsKey('currency')
          ? _getValue(values, columnMap['currency']!)
          : 'USD';

      // Optional investment metadata (from enhanced export format)
      final investmentTypeStr = columnMap.containsKey('investmentType')
          ? _getValue(values, columnMap['investmentType']!)
          : null;
      final investmentStatusStr = columnMap.containsKey('investmentStatus')
          ? _getValue(values, columnMap['investmentStatus']!)
          : null;

      // Optional currency (for multi-currency support)
      final currency = columnMap.containsKey('currency')
          ? _getValue(values, columnMap['currency']!)
          : null;

      // Validate required fields
      if (dateStr.isEmpty) {
        return ParsedCashFlowRow.withError(
          rowNumber: rowNum,
          error: 'Missing date',
        );
      }
      if (investmentName.isEmpty) {
        return ParsedCashFlowRow.withError(
          rowNumber: rowNum,
          error: 'Missing investment name',
        );
      }
      if (typeStr.isEmpty) {
        return ParsedCashFlowRow.withError(
          rowNumber: rowNum,
          error: 'Missing type',
        );
      }
      if (amountStr.isEmpty) {
        return ParsedCashFlowRow.withError(
          rowNumber: rowNum,
          error: 'Missing amount',
        );
      }

      // Parse date
      final date = _parseDate(dateStr);
      if (date == null) {
        return ParsedCashFlowRow.withError(
          rowNumber: rowNum,
          error: 'Invalid date: $dateStr',
        );
      }

      // Parse type
      final type = _parseType(typeStr);
      if (type == null) {
        return ParsedCashFlowRow.withError(
          rowNumber: rowNum,
          error: 'Invalid type: $typeStr',
        );
      }

      // Parse amount
      final amount = _parseAmount(amountStr);
      if (amount == null) {
        return ParsedCashFlowRow.withError(
          rowNumber: rowNum,
          error: 'Invalid amount: $amountStr',
        );
      }

      // Parse optional investment metadata
      InvestmentType? investmentType;
      if (investmentTypeStr != null && investmentTypeStr.isNotEmpty) {
        investmentType = InvestmentType.values.firstWhere(
          (t) => t.name.toLowerCase() == investmentTypeStr.toLowerCase(),
          orElse: () => InvestmentType.other,
        );
      }

      InvestmentStatus? investmentStatus;
      if (investmentStatusStr != null && investmentStatusStr.isNotEmpty) {
        investmentStatus = InvestmentStatus.values.firstWhere(
          (s) => s.name.toLowerCase() == investmentStatusStr.toLowerCase(),
          orElse: () => InvestmentStatus.open,
        );
      }

      return ParsedCashFlowRow(
        rowNumber: rowNum,
        date: date,
        investmentName: investmentName.trim(),
        type: type,
        amount: amount,
        currency: currency?.isNotEmpty == true ? currency?.toUpperCase() : null,
        notes: notes?.isNotEmpty == true ? notes : null,
        investmentType: investmentType,
        investmentStatus: investmentStatus,
      );
    } catch (e) {
      return ParsedCashFlowRow.withError(
        rowNumber: rowNum,
        error: 'Parse error: $e',
      );
    }
  }

  String _getValue(List<String> values, int index) {
    return index < values.length ? values[index].trim() : '';
  }

  /// Flexible date parser that handles any format
  static final AnyDate _dateParser = AnyDate(
    info: const DateParserInfo(
      dayFirst: true,
    ), // Prefer day-first for non-US formats
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
    'july': 7,
    'august': 8,
    'september': 9,
    'october': 10,
    'november': 11,
    'december': 12,
  };

  /// Parse date with smart format detection
  DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;

    // Check for Excel serial date (number like 45678)
    final serialNum = double.tryParse(dateStr);
    if (serialNum != null && serialNum > 25000 && serialNum < 60000) {
      return DateTime(1899, 12, 30).add(Duration(days: serialNum.toInt()));
    }

    // Try month-year format first (e.g., Jan-21, Sept-25, Feb/22)
    // This format is common in financial data but not supported by any_date
    final monthYearMatch = RegExp(
      r'^([A-Za-z]+)[-/\s](\d{2,4})$',
    ).firstMatch(dateStr);
    if (monthYearMatch != null) {
      final monthStr = monthYearMatch.group(1)!.toLowerCase();
      final yearStr = monthYearMatch.group(2)!;
      final month = _monthNames[monthStr];
      if (month != null) {
        final year = yearStr.length == 2
            ? 2000 + int.parse(yearStr)
            : int.parse(yearStr);
        return DateTime(year, month, 1);
      }
    }

    // Optimization: Try detected format first
    if (_detectedDateFormat != null) {
      try {
        return _detectedDateFormat!.parseStrict(dateStr);
      } catch (_) {
        // Failed, continue to fallback
      }
    }

    // Try manual date formats first to detect consistent pattern
    for (final format in _dateFormats) {
      try {
        final date = format.parseStrict(dateStr);
        // If successful, memoize this format for future rows
        _detectedDateFormat = format;
        return date;
      } catch (_) {}
    }

    // Fallback: try any_date library for flexible full-date parsing
    try {
      return _dateParser.parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  /// Parse cash flow type
  CashFlowType? _parseType(String typeStr) {
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
  double? _parseAmount(String amountStr) {
    if (amountStr.isEmpty) return null;
    final cleaned = amountStr
        .replaceAll(RegExp(r'[₹$€£¥,\s]'), '')
        .replaceAll('(', '-')
        .replaceAll(')', '');
    return double.tryParse(cleaned);
  }
}

// ============================================================
// Goals CSV Parser
// ============================================================

/// Parsed row from Goals CSV import
class ParsedGoalRow {
  final int rowNumber;
  final String name;
  final String type;
  final double targetAmount;
  final double? targetMonthlyIncome;
  final DateTime? targetDate;
  final String trackingMode;

  /// Linked investment names (used for remapping to IDs during import)
  final List<String> linkedInvestmentNames;
  final List<String> linkedTypes;
  final String icon;
  final int colorValue;
  final String? error;

  const ParsedGoalRow({
    required this.rowNumber,
    required this.name,
    required this.type,
    required this.targetAmount,
    this.targetMonthlyIncome,
    this.targetDate,
    required this.trackingMode,
    required this.linkedInvestmentNames,
    required this.linkedTypes,
    required this.icon,
    required this.colorValue,
    this.error,
  });

  bool get isValid => error == null;

  ParsedGoalRow.withError({required this.rowNumber, required this.error})
    : name = '',
      type = 'targetAmount',
      targetAmount = 0,
      targetMonthlyIncome = null,
      targetDate = null,
      trackingMode = 'all',
      linkedInvestmentNames = const [],
      linkedTypes = const [],
      icon = '🎯',
      colorValue = 0xFF4CAF50;
}

/// Result of parsing a Goals CSV file
class ParsedGoalsResult {
  final List<ParsedGoalRow> rows;
  final List<String> errors;
  final int totalRows;
  final int validRows;

  const ParsedGoalsResult({
    required this.rows,
    required this.errors,
    required this.totalRows,
    required this.validRows,
  });

  bool get hasErrors => errors.isNotEmpty;
  List<ParsedGoalRow> get validRowsOnly =>
      rows.where((r) => r.isValid).toList();
}

/// Parser for Goals CSV files
class GoalsCsvParser {
  /// Parse Goals CSV string content
  static ParsedGoalsResult parseString(String content) {
    final lines = const LineSplitter().convert(content);
    if (lines.isEmpty) {
      return const ParsedGoalsResult(
        rows: [],
        errors: ['Empty file'],
        totalRows: 0,
        validRows: 0,
      );
    }

    // Parse header row
    final headerRow = SimpleCsvParser._parseCSVLine(lines.first);
    final columnMap = _mapColumns(headerRow);

    if (!columnMap.containsKey('name') ||
        !columnMap.containsKey('type') ||
        !columnMap.containsKey('targetAmount')) {
      return ParsedGoalsResult(
        rows: [],
        errors: [
          'Missing required columns. Required: Name, Type, Target Amount',
        ],
        totalRows: lines.length - 1,
        validRows: 0,
      );
    }

    final rows = <ParsedGoalRow>[];
    final errors = <String>[];

    // Parse data rows (skip header)
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final values = SimpleCsvParser._parseCSVLine(line);
      final result = _parseRow(i + 1, values, columnMap);

      if (result.isValid) {
        rows.add(result);
      } else {
        errors.add('Row ${result.rowNumber}: ${result.error}');
      }
    }

    return ParsedGoalsResult(
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
      if (header == 'name') {
        map['name'] = i;
      } else if (header == 'type') {
        map['type'] = i;
      } else if (header.contains('target amount')) {
        map['targetAmount'] = i;
      } else if (header.contains('monthly income')) {
        map['targetMonthlyIncome'] = i;
      } else if (header.contains('target date')) {
        map['targetDate'] = i;
      } else if (header.contains('tracking')) {
        map['trackingMode'] = i;
      } else if (header.contains('linked investment')) {
        // Handles both "Linked Investment Names" and legacy "Linked Investment IDs"
        map['linkedInvestmentNames'] = i;
      } else if (header.contains('linked types')) {
        map['linkedTypes'] = i;
      } else if (header == 'icon') {
        map['icon'] = i;
      } else if (header == 'color') {
        map['color'] = i;
      }
    }
    return map;
  }

  static String _getValue(List<String> values, int index) {
    return index < values.length ? values[index].trim() : '';
  }

  /// Parse a single row
  static ParsedGoalRow _parseRow(
    int rowNum,
    List<String> values,
    Map<String, int> columnMap,
  ) {
    try {
      final name = _getValue(values, columnMap['name']!);
      final type = _getValue(values, columnMap['type']!);
      final targetAmountStr = _getValue(values, columnMap['targetAmount']!);

      if (name.isEmpty) {
        return ParsedGoalRow.withError(
          rowNumber: rowNum,
          error: 'Missing name',
        );
      }
      if (type.isEmpty) {
        return ParsedGoalRow.withError(
          rowNumber: rowNum,
          error: 'Missing type',
        );
      }
      if (targetAmountStr.isEmpty) {
        return ParsedGoalRow.withError(
          rowNumber: rowNum,
          error: 'Missing target amount',
        );
      }

      final targetAmount = double.tryParse(targetAmountStr);
      if (targetAmount == null) {
        return ParsedGoalRow.withError(
          rowNumber: rowNum,
          error: 'Invalid target amount: $targetAmountStr',
        );
      }

      // Optional fields
      double? targetMonthlyIncome;
      if (columnMap.containsKey('targetMonthlyIncome')) {
        final str = _getValue(values, columnMap['targetMonthlyIncome']!);
        if (str.isNotEmpty) {
          targetMonthlyIncome = double.tryParse(str);
        }
      }

      DateTime? targetDate;
      if (columnMap.containsKey('targetDate')) {
        final str = _getValue(values, columnMap['targetDate']!);
        if (str.isNotEmpty) {
          targetDate = DateTime.tryParse(str);
        }
      }

      final trackingMode = columnMap.containsKey('trackingMode')
          ? _getValue(values, columnMap['trackingMode']!)
          : 'all';

      List<String> linkedInvestmentNames = [];
      if (columnMap.containsKey('linkedInvestmentNames')) {
        final str = _getValue(values, columnMap['linkedInvestmentNames']!);
        if (str.isNotEmpty) {
          linkedInvestmentNames = str
              .split(';')
              .where((s) => s.isNotEmpty)
              .toList();
        }
      }

      List<String> linkedTypes = [];
      if (columnMap.containsKey('linkedTypes')) {
        final str = _getValue(values, columnMap['linkedTypes']!);
        if (str.isNotEmpty) {
          linkedTypes = str.split(';').where((s) => s.isNotEmpty).toList();
        }
      }

      final icon = columnMap.containsKey('icon')
          ? _getValue(values, columnMap['icon']!)
          : '🎯';

      int colorValue = 0xFF4CAF50;
      if (columnMap.containsKey('color')) {
        final colorStr = _getValue(values, columnMap['color']!);
        if (colorStr.isNotEmpty) {
          colorValue = int.tryParse(colorStr) ?? 0xFF4CAF50;
        }
      }

      return ParsedGoalRow(
        rowNumber: rowNum,
        name: name,
        type: type,
        targetAmount: targetAmount,
        targetMonthlyIncome: targetMonthlyIncome,
        targetDate: targetDate,
        trackingMode: trackingMode.isNotEmpty ? trackingMode : 'all',
        linkedInvestmentNames: linkedInvestmentNames,
        linkedTypes: linkedTypes,
        icon: icon.isNotEmpty ? icon : '🎯',
        colorValue: colorValue,
      );
    } catch (e) {
      return ParsedGoalRow.withError(
        rowNumber: rowNum,
        error: 'Parse error: $e',
      );
    }
  }
}
