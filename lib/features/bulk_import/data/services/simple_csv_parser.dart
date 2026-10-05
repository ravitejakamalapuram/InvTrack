import 'dart:convert';
import 'dart:typed_data';
import 'package:any_date/any_date.dart';
import 'package:csv/csv.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
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

  /// Optional investment metadata (from enhanced export format)
  final InvestmentType? investmentType;
  final InvestmentStatus? investmentStatus;

  /// Currency code from the CSV, or the user's base currency when the cell
  /// is blank or the column is missing. Null only when the parser was not
  /// given a base currency; callers must then use the base currency.
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

/// How to read a numeric date such as 05/03/2024.
enum CsvDateOrder { dayFirst, monthFirst }

/// Asked when no date in a file shows whether it is day-first or
/// month-first, so the user can choose before anything is imported.
class DateOrderQuestion {
  /// A date cell from the file that can be read both ways.
  final String sample;
  final DateTime dayFirst;
  final DateTime monthFirst;

  const DateOrderQuestion({
    required this.sample,
    required this.dayFirst,
    required this.monthFirst,
  });
}

/// Result of parsing a CSV file
class ParsedCsvResult {
  final List<ParsedCashFlowRow> rows;
  final List<String> errors;
  final int totalRows;
  final int validRows;

  /// Set when every day/month date in the file fits both orders and the
  /// caller did not choose one. The rows were read day-first; parse again
  /// with the user's answer as `dateOrder`.
  final DateOrderQuestion? dateOrderQuestion;

  const ParsedCsvResult({
    required this.rows,
    required this.errors,
    required this.totalRows,
    required this.validRows,
    this.dateOrderQuestion,
  });

  bool get hasErrors => errors.isNotEmpty;

  /// Returns only the valid rows from the result.
  /// Note: While the SimpleCsvParser implementation only adds valid rows to the list,
  /// this getter provides defensive filtering to maintain the public API contract,
  /// as ParsedCsvResult can be instantiated directly (e.g., in tests).
  List<ParsedCashFlowRow> get validRowsOnly =>
      rows.where((r) => r.isValid).toList();
}

/// CSV parser that reads each file one consistent way: one day/month order
/// for its dates and one decimal mark for its amounts.
class SimpleCsvParser {
  /// Parse CSV bytes into structured data.
  ///
  /// A missing or blank Currency becomes [baseCurrency] (the user's base
  /// currency). Without one, [ParsedCashFlowRow.currency] stays null and the
  /// caller must resolve it; it is never assumed to be USD.
  ///
  /// [dateOrder] says how to read dates such as 05/03/2024. When it is null
  /// the file's own dates decide; see [ParsedCsvResult.dateOrderQuestion].
  /// [decimalComma] says whether amounts are written 1.234,56. When it is
  /// null the file's amounts decide, and a dot is the default.
  static ParsedCsvResult parse(
    Uint8List bytes, {
    String? baseCurrency,
    CsvDateOrder? dateOrder,
    bool? decimalComma,
  }) {
    final content = utf8.decode(bytes);
    return parseString(
      content,
      baseCurrency: baseCurrency,
      dateOrder: dateOrder,
      decimalComma: decimalComma,
    );
  }

  /// Parse CSV string content. See [parse] for the options.
  static ParsedCsvResult parseString(
    String content, {
    String? baseCurrency,
    CsvDateOrder? dateOrder,
    bool? decimalComma,
  }) {
    return _CsvParserSession(
      content,
      baseCurrency: baseCurrency,
      dateOrder: dateOrder,
      decimalComma: decimalComma,
    ).parse();
  }
}

/// The records of a CSV file with their spreadsheet row numbers (the header
/// is row 1). A quoted cell may span lines; blank records are dropped but
/// still counted, so row numbers match what a spreadsheet shows.
List<({int rowNumber, List<String> values})> _readCsvRecords(String content) {
  final decoded = Csv(autoDetect: false, skipEmptyLines: false).decode(content);
  return [
    for (var i = 0; i < decoded.length; i++)
      if (decoded[i].any((v) => '$v'.trim().isNotEmpty))
        (rowNumber: i + 1, values: [for (final v in decoded[i]) '$v'.trim()]),
  ];
}

/// The ways one date cell can be read.
class _DateCell {
  /// The only reading (ISO, month names, Excel serials, d/m equal).
  final DateTime? fixed;
  final DateTime? dayFirst;
  final DateTime? monthFirst;

  const _DateCell({this.fixed, this.dayFirst, this.monthFirst});

  bool get onlyDayFirst =>
      fixed == null && dayFirst != null && monthFirst == null;
  bool get onlyMonthFirst =>
      fixed == null && monthFirst != null && dayFirst == null;
  bool get eitherOrder =>
      fixed == null && dayFirst != null && monthFirst != null;

  DateTime? read(CsvDateOrder order) =>
      fixed ?? (order == CsvDateOrder.dayFirst ? dayFirst : monthFirst);
}

class _CsvParserSession {
  _CsvParserSession(
    this.content, {
    required this.baseCurrency,
    required this.dateOrder,
    required this.decimalComma,
  });

  final String content;

  /// Currency for rows whose Currency column is missing or blank.
  final String? baseCurrency;

  /// The caller's choice; null lets the file decide.
  final CsvDateOrder? dateOrder;
  final bool? decimalComma;

  /// Dates before this year are typing mistakes, not investments.
  static const int minYear = 1950;

  /// Dates more than this many years ahead are typing mistakes.
  static const int maxYearsAhead = 10;

  final int _maxYear = DateTime.now().year + maxYearsAhead;

  ParsedCsvResult parse() {
    final records = _readCsvRecords(content);
    if (records.isEmpty) {
      return const ParsedCsvResult(
        rows: [],
        errors: ['Empty file'],
        totalRows: 0,
        validRows: 0,
      );
    }

    final columnMap = _mapColumns(records.first.values);
    final data = records.skip(1).toList();

    if (!columnMap.containsKey('date') ||
        !columnMap.containsKey('investment') ||
        !columnMap.containsKey('type') ||
        !columnMap.containsKey('amount')) {
      return ParsedCsvResult(
        rows: [],
        errors: [
          'Missing required columns. Required: Date, Investment Name, Type, Amount',
        ],
        totalRows: data.length,
        validRows: 0,
      );
    }

    // First pass: every date and amount cell decides how the whole file is
    // read, so one odd row cannot change how the rows after it are read.
    final dateCells = [
      for (final r in data)
        _readDateCell(_getValue(r.values, columnMap['date']!)),
    ];
    final (:order, :question) = _chooseDateOrder(data, columnMap, dateCells);
    final commaDecimals =
        decimalComma ??
        _usesDecimalComma(
          data.map((r) => _getValue(r.values, columnMap['amount']!)),
        );

    final rows = <ParsedCashFlowRow>[];
    final errors = <String>[];

    for (var i = 0; i < data.length; i++) {
      final result = _parseRow(
        data[i].rowNumber,
        data[i].values,
        columnMap,
        dateCells[i],
        order,
        commaDecimals,
      );

      if (result.isValid) {
        rows.add(result);
      } else {
        errors.add('Row ${result.rowNumber}: ${result.error}');
      }
    }

    return ParsedCsvResult(
      rows: rows,
      errors: errors,
      totalRows: data.length,
      // Optimization: The rows list only contains valid rows due to the check above,
      // so we can use rows.length directly to avoid an unnecessary O(N) iteration.
      validRows: rows.length,
      dateOrderQuestion: question,
    );
  }

  /// The day/month order for the file: the caller's, else the order more
  /// cells can only be read in (the first such cell breaks a tie), else
  /// day-first with a question for the user when some cells fit both.
  ({CsvDateOrder order, DateOrderQuestion? question}) _chooseDateOrder(
    List<({int rowNumber, List<String> values})> data,
    Map<String, int> columnMap,
    List<_DateCell?> cells,
  ) {
    if (dateOrder != null) return (order: dateOrder!, question: null);

    var dayFirstOnly = 0;
    var monthFirstOnly = 0;
    CsvDateOrder? firstDecided;
    int? firstEither;
    for (var i = 0; i < cells.length; i++) {
      final cell = cells[i];
      if (cell == null) continue;
      if (cell.onlyDayFirst) {
        dayFirstOnly++;
        firstDecided ??= CsvDateOrder.dayFirst;
      } else if (cell.onlyMonthFirst) {
        monthFirstOnly++;
        firstDecided ??= CsvDateOrder.monthFirst;
      } else if (cell.eitherOrder) {
        firstEither ??= i;
      }
    }

    if (dayFirstOnly != monthFirstOnly) {
      return (
        order: dayFirstOnly > monthFirstOnly
            ? CsvDateOrder.dayFirst
            : CsvDateOrder.monthFirst,
        question: null,
      );
    }
    if (firstDecided != null) return (order: firstDecided, question: null);
    if (firstEither == null) {
      return (order: CsvDateOrder.dayFirst, question: null);
    }

    final sample = cells[firstEither]!;
    return (
      order: CsvDateOrder.dayFirst,
      question: DateOrderQuestion(
        sample: _getValue(data[firstEither].values, columnMap['date']!),
        dayFirst: sample.dayFirst!,
        monthFirst: sample.monthFirst!,
      ),
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
      }
    }
    return map;
  }

  /// Parse a single row
  ParsedCashFlowRow _parseRow(
    int rowNum,
    List<String> values,
    Map<String, int> columnMap,
    _DateCell? dateCell,
    CsvDateOrder dateOrder,
    bool commaDecimals,
  ) {
    try {
      final dateStr = _getValue(values, columnMap['date']!);
      final investmentName = _getValue(values, columnMap['investment']!);
      final typeStr = _getValue(values, columnMap['type']!);
      final amountStr = _getValue(values, columnMap['amount']!);
      final notes = columnMap.containsKey('notes')
          ? _getValue(values, columnMap['notes']!)
          : null;

      // Optional investment metadata (from enhanced export format)
      final investmentTypeStr = columnMap.containsKey('investmentType')
          ? _getValue(values, columnMap['investmentType']!)
          : null;
      final investmentStatusStr = columnMap.containsKey('investmentStatus')
          ? _getValue(values, columnMap['investmentStatus']!)
          : null;

      // Optional currency (for multi-currency support). A missing column or
      // blank cell is the user's base currency, never USD (null when the
      // caller resolves it later).
      final currencyRaw = columnMap.containsKey('currency')
          ? _getValue(values, columnMap['currency']!).toUpperCase()
          : '';

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

      // Parse date in the file's day/month order
      final date = dateCell?.read(dateOrder);
      if (date == null) {
        return ParsedCashFlowRow.withError(
          rowNumber: rowNum,
          error: dateCell == null
              ? 'Invalid date: $dateStr'
              : 'Date $dateStr does not match the day/month order of the '
                    'other dates in this file',
        );
      }
      if (date.year < minYear || date.year > _maxYear) {
        return ParsedCashFlowRow.withError(
          rowNumber: rowNum,
          error: 'Date out of range ($minYear to $_maxYear): $dateStr',
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

      // Parse amount with the file's decimal mark
      final amount = _parseAmount(amountStr, decimalComma: commaDecimals);
      if (amount == null) {
        return ParsedCashFlowRow.withError(
          rowNumber: rowNum,
          error: 'Invalid amount: $amountStr',
        );
      }

      // An unknown code would be stored and then fail every FX conversion.
      if (currencyRaw.isNotEmpty &&
          !getValidCurrencyCodes().contains(currencyRaw)) {
        return ParsedCashFlowRow.withError(
          rowNumber: rowNum,
          error: 'Invalid currency code: $currencyRaw',
        );
      }
      final currency = currencyRaw.isEmpty ? baseCurrency : currencyRaw;

      // Parse optional investment metadata
      InvestmentType? investmentType;
      if (investmentTypeStr != null && investmentTypeStr.isNotEmpty) {
        investmentType =
            _investmentTypes[_typeKey(investmentTypeStr)] ??
            InvestmentType.other;
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
        currency: currency,
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

  /// Investment Type cell values, compared without case, spaces or
  /// punctuation: enum names, display names and common short forms.
  static final Map<String, InvestmentType> _investmentTypes = {
    for (final t in InvestmentType.values) ...{
      _typeKey(t.name): t,
      _typeKey(t.displayName): t,
    },
    'p2p': InvestmentType.p2pLending,
    'fd': InvestmentType.fixedDeposit,
    'mutualfund': InvestmentType.mutualFunds,
    'mf': InvestmentType.mutualFunds,
    'bond': InvestmentType.bonds,
    'stock': InvestmentType.stocks,
    'chitfund': InvestmentType.chitFunds,
    'chit': InvestmentType.chitFunds,
    'property': InvestmentType.realEstate,
  };

  static String _typeKey(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Flexible parser for dates written with words, used last
  static final AnyDate _dateParser = AnyDate(
    info: const DateParserInfo(dayFirst: true),
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

  static final _isoDate = RegExp(
    r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?:[T ].*)?$',
  );
  static final _numericDate = RegExp(
    r'^(\d{1,2})([-/.])(\d{1,2})\2(\d{2}|\d{4})$',
  );
  static final _dayMonthNameYear = RegExp(
    r'^(\d{1,2})[-/\s.]+([A-Za-z]+)\.?[-/\s.,]+(\d{2}|\d{4})$',
  );
  static final _monthNameDayYear = RegExp(
    r'^([A-Za-z]+)\.?[-/\s.]+(\d{1,2}),?[-/\s.]+(\d{4})$',
  );
  static final _monthNameYear = RegExp(r'^([A-Za-z]+)[-/\s](\d{2,4})$');
  static final _monthYear = RegExp(r'^(\d{1,2})[-/](\d{2}|\d{4})$');
  static final _excelSerial = RegExp(r'^\d{5}(\.\d+)?$');

  /// A two-digit year is in this century unless that is beyond the latest
  /// accepted year; 24 is 2024 and 99 is 1999.
  int _fullYear(String year) {
    final value = int.parse(year);
    if (year.length != 2) return value;
    return 2000 + value <= _maxYear ? 2000 + value : 1900 + value;
  }

  /// The date, or null when the day does not exist in that month.
  static DateTime? _validDate(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1) return null;
    final date = DateTime(year, month, day);
    return date.month == month && date.day == day ? date : null;
  }

  /// Every way [text] can be read as a date, or null when it is not one.
  _DateCell? _readDateCell(String text) {
    if (text.isEmpty) return null;

    // Excel serial date (days since 1899-12-30), without a time of day
    if (_excelSerial.hasMatch(text)) {
      final serial = double.parse(text).floor();
      if (serial > 25000 && serial < 60000) {
        return _DateCell(fixed: DateTime(1899, 12, 30 + serial));
      }
      return null;
    }

    if (_isoDate.firstMatch(text) case final m?) {
      final date = _validDate(
        int.parse(m[1]!),
        int.parse(m[2]!),
        int.parse(m[3]!),
      );
      return date == null ? null : _DateCell(fixed: date);
    }

    if (_numericDate.firstMatch(text) case final m?) {
      final first = int.parse(m[1]!);
      final second = int.parse(m[3]!);
      final year = _fullYear(m[4]!);
      final dayFirst = _validDate(year, second, first);
      final monthFirst = _validDate(year, first, second);
      if (dayFirst == null && monthFirst == null) return null;
      if (dayFirst != null && dayFirst == monthFirst) {
        return _DateCell(fixed: dayFirst);
      }
      return _DateCell(dayFirst: dayFirst, monthFirst: monthFirst);
    }

    if (_dayMonthNameYear.firstMatch(text) case final m?) {
      final month = _monthNames[m[2]!.toLowerCase()];
      if (month == null) return null;
      final date = _validDate(_fullYear(m[3]!), month, int.parse(m[1]!));
      return date == null ? null : _DateCell(fixed: date);
    }

    if (_monthNameDayYear.firstMatch(text) case final m?) {
      final month = _monthNames[m[1]!.toLowerCase()];
      if (month == null) return null;
      final date = _validDate(int.parse(m[3]!), month, int.parse(m[2]!));
      return date == null ? null : _DateCell(fixed: date);
    }

    // Month and year only (Jan-21, Sept-25, Feb/22): the 1st of the month
    if (_monthNameYear.firstMatch(text) case final m?) {
      final month = _monthNames[m[1]!.toLowerCase()];
      if (month == null) return null;
      return _DateCell(fixed: DateTime(_fullYear(m[2]!), month, 1));
    }
    if (_monthYear.firstMatch(text) case final m?) {
      final date = _validDate(_fullYear(m[2]!), int.parse(m[1]!), 1);
      return date == null ? null : _DateCell(fixed: date);
    }

    // Other dates written with words, e.g. "Monday, 15 January 2024".
    // Digits-only dates never get here, so their order stays the file's.
    if (!RegExp('[A-Za-z]').hasMatch(text)) return null;
    try {
      final date = _dateParser.parse(text);
      return _DateCell(fixed: DateTime(date.year, date.month, date.day));
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

  /// Digits with an optional decimal part, grouped by commas in thousands
  /// (1,234,567) or lakhs (12,34,567), or by dots with a decimal comma.
  static final _decimalPointAmount = RegExp(
    r'^(\d+|\d{1,3}(,\d{2,3})*,\d{3})(\.\d+)?$',
  );
  static final _decimalCommaAmount = RegExp(
    r'^(\d+|\d{1,3}(\.\d{2,3})*\.\d{3})(,\d+)?$',
  );

  /// Parse an amount, ignoring currency symbols and spaces. A leading minus
  /// or surrounding parentheses make it negative.
  static double? _parseAmount(String amountStr, {required bool decimalComma}) {
    var text = amountStr.replaceAll(RegExp(r'[₹$€£¥\s ]'), '');
    var negative = false;
    if (text.startsWith('(') && text.endsWith(')')) {
      negative = true;
      text = text.substring(1, text.length - 1);
    }
    if (text.startsWith('-')) {
      negative = !negative;
      text = text.substring(1);
    } else if (text.startsWith('+')) {
      text = text.substring(1);
    }

    final shape = decimalComma ? _decimalCommaAmount : _decimalPointAmount;
    if (!shape.hasMatch(text)) return null;
    final plain = decimalComma
        ? text.replaceAll('.', '').replaceAll(',', '.')
        : text.replaceAll(',', '');
    final value = double.parse(plain);
    return negative ? -value : value;
  }

  /// Whether more amounts can only be read with a decimal comma (1.234,56,
  /// 12,50) than only with a decimal point (1,234.56, 12.5). Amounts that
  /// read the same either way do not count.
  static bool _usesDecimalComma(Iterable<String> amounts) {
    var pointOnly = 0;
    var commaOnly = 0;
    for (final amount in amounts) {
      final asPoint = _parseAmount(amount, decimalComma: false);
      final asComma = _parseAmount(amount, decimalComma: true);
      if (asPoint != null && asComma == null) pointOnly++;
      if (asComma != null && asPoint == null) commaOnly++;
    }
    return commaOnly > pointOnly;
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

  /// Currency code (Rule 21.2). Null only when the CSV has none and the
  /// parser was not given a base currency; callers then use the base
  /// currency.
  final String? currency;
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
    required this.currency,
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
      colorValue = 0xFF4CAF50,
      currency = null;
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

  /// Returns only the valid rows from the result.
  /// Note: While the GoalsCsvParser implementation only adds valid rows to the list,
  /// this getter provides defensive filtering to maintain the public API contract,
  /// as ParsedGoalsResult can be instantiated directly (e.g., in tests).
  List<ParsedGoalRow> get validRowsOnly =>
      rows.where((r) => r.isValid).toList();
}

/// Parser for Goals CSV files
class GoalsCsvParser {
  /// Parse Goals CSV string content.
  ///
  /// A missing or blank Currency becomes [baseCurrency]; without one,
  /// [ParsedGoalRow.currency] stays null for the caller to resolve.
  static ParsedGoalsResult parseString(String content, {String? baseCurrency}) {
    final records = _readCsvRecords(content);
    if (records.isEmpty) {
      return const ParsedGoalsResult(
        rows: [],
        errors: ['Empty file'],
        totalRows: 0,
        validRows: 0,
      );
    }

    // Parse header row
    final columnMap = _mapColumns(records.first.values);
    final data = records.skip(1).toList();

    if (!columnMap.containsKey('name') ||
        !columnMap.containsKey('type') ||
        !columnMap.containsKey('targetAmount')) {
      return ParsedGoalsResult(
        rows: [],
        errors: [
          'Missing required columns. Required: Name, Type, Target Amount',
        ],
        totalRows: data.length,
        validRows: 0,
      );
    }

    final rows = <ParsedGoalRow>[];
    final errors = <String>[];

    for (final record in data) {
      final result = _parseRow(
        record.rowNumber,
        record.values,
        columnMap,
        baseCurrency,
      );

      if (result.isValid) {
        rows.add(result);
      } else {
        errors.add('Row ${result.rowNumber}: ${result.error}');
      }
    }

    return ParsedGoalsResult(
      rows: rows,
      errors: errors,
      totalRows: data.length,
      // Optimization: The rows list only contains valid rows due to the check above,
      // so we can use rows.length directly to avoid an unnecessary O(N) iteration.
      validRows: rows.length,
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
      } else if (header.contains('currency')) {
        // Multi-currency support (Rule 21.4)
        map['currency'] = i;
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
    String? baseCurrency,
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

      // Currency (Rule 21.4 - backward compatibility with validation)
      final currencyRaw = columnMap.containsKey('currency')
          ? _getValue(values, columnMap['currency']!).trim().toUpperCase()
          : '';

      // Validate currency code (ISO 4217)
      if (currencyRaw.isNotEmpty && !_isValidCurrency(currencyRaw)) {
        return ParsedGoalRow.withError(
          rowNumber: rowNum,
          error: 'Invalid currency code: $currencyRaw',
        );
      }

      // Old exports have no currency column: use the base currency, not USD
      final currency = currencyRaw.isEmpty ? baseCurrency : currencyRaw;

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
        currency: currency,
      );
    } catch (e) {
      return ParsedGoalRow.withError(
        rowNumber: rowNum,
        error: 'Parse error: $e',
      );
    }
  }

  /// Validate currency code against supported ISO 4217 currencies.
  ///
  /// Uses the single source of truth from [getValidCurrencyCodes] in
  /// currency_utils.dart to avoid duplication and drift.
  ///
  /// ## Supported Currencies (40+)
  ///
  /// USD, EUR, GBP, INR, JPY, CAD, AUD, CHF, CNY, SGD, HKD, AED, SAR,
  /// BRL, MXN, ZAR, SEK, NOK, DKK, PLN, CZK, HUF, RON, KRW, TWD, THB,
  /// MYR, IDR, PHP, VND, BDT, PKR, LKR, ILS, TRY, NZD, ARS, CLP, COP,
  /// PEN, NGN, KES, EGP
  ///
  /// ## Returns
  ///
  /// - **true**: Currency code is supported
  /// - **false**: Currency code is not supported or invalid
  static bool _isValidCurrency(String currencyCode) {
    return getValidCurrencyCodes().contains(currencyCode);
  }
}
