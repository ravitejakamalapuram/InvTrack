import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:inv_tracker/features/ai_import/domain/entities/extracted_cash_flow.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:uuid/uuid.dart';

/// Service for AI-powered document parsing using Firebase AI with Gemini
class AIDocumentParsingService {
  final FirebaseStorage _storage;
  final Uuid _uuid = const Uuid();

  static const List<String> supportedExtensions = [
    'csv', 'xlsx', 'xls', 'pdf', 'jpg', 'jpeg', 'png'
  ];
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10MB

  AIDocumentParsingService({required FirebaseStorage storage}) : _storage = storage;

  /// Pick a document using file picker
  Future<PlatformFile?> pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: supportedExtensions,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    if (file.size > maxFileSizeBytes) {
      throw Exception('File size exceeds 10MB limit');
    }

    return file;
  }

  /// Upload file to Firebase Storage
  Future<String> uploadToStorage(PlatformFile file, String userId) async {
    final bytes = file.bytes;
    if (bytes == null) {
      throw Exception('Could not read file bytes');
    }

    final fileName = '${_uuid.v4()}_${file.name}';
    final path = 'temp_imports/$userId/$fileName';
    final ref = _storage.ref(path);

    await ref.putData(bytes, SettableMetadata(
      contentType: _getContentType(file.extension ?? ''),
    ));

    return path;
  }

  /// Delete file from Firebase Storage
  Future<void> deleteFromStorage(String path) async {
    try {
      await _storage.ref(path).delete();
    } catch (e) {
      debugPrint('Error deleting file from storage: $e');
    }
  }

  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'csv':
        return 'text/csv';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }

  /// Extract cash flows from a document using Gemini AI or direct parsing
  Future<AIExtractionResult> extractCashFlows(PlatformFile file) async {
    try {
      final extension = file.extension?.toLowerCase() ?? '';

      // For Excel files, try direct parsing first (more reliable for large structured files)
      if (extension == 'xlsx' || extension == 'xls') {
        final bytes = file.bytes;
        if (bytes != null) {
          final directResult = _parseExcelDirectly(bytes);
          if (directResult.investments.isNotEmpty) {
            debugPrint('Successfully parsed Excel directly: ${directResult.investments.length} investments');
            return directResult;
          }
          debugPrint('Direct Excel parsing found no data, falling back to AI');
        }
      }

      // Fall back to AI for other files or if direct parsing fails
      return await _extractWithAI(file);
    } catch (e) {
      debugPrint('Error extracting cash flows: $e');
      return AIExtractionResult(
        errorMessage: 'Failed to extract data: ${e.toString()}',
      );
    }
  }

  /// Extract cash flows using Gemini AI
  Future<AIExtractionResult> _extractWithAI(PlatformFile file) async {
    final model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-2.0-flash',
      generationConfig: GenerationConfig(
        maxOutputTokens: 8192,
        temperature: 0.1,
      ),
    );

    final prompt = _buildExtractionPrompt();
    final content = await _buildContent(file, prompt);

    final response = await model.generateContent(content);
    final responseText = response.text;

    if (responseText == null || responseText.isEmpty) {
      return const AIExtractionResult(
        errorMessage: 'No response from AI model',
      );
    }

    return _parseResponse(responseText);
  }

  /// Directly parse Excel files with structured investment data
  AIExtractionResult _parseExcelDirectly(Uint8List bytes) {
    try {
      final excel = Excel.decodeBytes(bytes);
      final investments = <ExtractedInvestment>[];

      for (final sheetName in excel.tables.keys) {
        final sheet = excel.tables[sheetName];
        if (sheet == null || sheet.rows.isEmpty) continue;

        // Find header row with dates
        List<DateTime?> dates = [];
        int headerRowIndex = -1;

        for (int i = 0; i < sheet.rows.length && i < 5; i++) {
          final row = sheet.rows[i];
          final dateCount = row.where((cell) {
            if (cell?.value == null) return false;
            return _tryParseDate(cell!.value) != null;
          }).length;

          if (dateCount > 10) {
            headerRowIndex = i;
            dates = row.map((cell) {
              if (cell?.value == null) return null;
              return _tryParseDate(cell!.value);
            }).toList();
            break;
          }
        }

        if (headerRowIndex == -1) continue;

        // Parse each data row
        String? currentSection;
        for (int i = headerRowIndex + 1; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          if (row.isEmpty) continue;

          // Check for section headers
          final sectionCell = row.length > 1 ? row[1]?.value?.toString() : null;
          if (sectionCell != null) {
            if (sectionCell.toLowerCase().contains('cash out') ||
                sectionCell.toLowerCase().contains('expenditure')) {
              currentSection = 'INVEST';
              continue;
            } else if (sectionCell.toLowerCase().contains('cash in') ||
                       sectionCell.toLowerCase().contains('income')) {
              currentSection = 'INCOME';
              continue;
            } else if (sectionCell.toLowerCase().contains('total') ||
                       sectionCell.toLowerCase().contains('net')) {
              continue; // Skip totals
            }
          }

          // Get investment name (usually column 2 or 3)
          String? investmentName;
          int dataStartCol = 0;
          for (int c = 0; c < row.length && c < 5; c++) {
            final cellValue = row[c]?.value?.toString();
            if (cellValue != null && cellValue.isNotEmpty &&
                !cellValue.toLowerCase().contains('total') &&
                _tryParseDate(row[c]?.value) == null &&
                double.tryParse(cellValue.replaceAll(',', '')) == null) {
              investmentName = cellValue.trim();
              dataStartCol = c + 1;
            }
          }

          if (investmentName == null || investmentName.isEmpty) continue;
          if (investmentName.toLowerCase().contains('total')) continue;

          // Extract cash flows for this investment
          final cashFlows = <ExtractedCashFlow>[];
          for (int c = dataStartCol; c < row.length && c < dates.length; c++) {
            final date = dates[c];
            if (date == null) continue;

            final cellValue = row[c]?.value;
            if (cellValue == null) continue;

            double? amount = _extractNumericValue(cellValue);

            if (amount == null || amount == 0) continue;

            final flowType = currentSection == 'INCOME'
                ? CashFlowType.income
                : CashFlowType.invest;

            cashFlows.add(ExtractedCashFlow(
              id: _uuid.v4(),
              date: date,
              amount: amount.abs(),
              type: flowType,
              confidence: 1.0,
            ));
          }

          if (cashFlows.isEmpty) continue;

          // Normalize investment name for comparison
          final normalizedName = _normalizeInvestmentName(investmentName);

          // Check if investment already exists (merge cash flows)
          final existingIndex = investments.indexWhere(
            (inv) => _normalizeInvestmentName(inv.name) == normalizedName
          );

          if (existingIndex >= 0) {
            final existing = investments[existingIndex];
            investments[existingIndex] = ExtractedInvestment(
              id: existing.id,
              suggestedName: existing.suggestedName,
              cashFlows: [...existing.cashFlows, ...cashFlows],
            );
          } else {
            investments.add(ExtractedInvestment(
              id: _uuid.v4(),
              suggestedName: investmentName,
              cashFlows: cashFlows,
            ));
          }
        }
      }

      return AIExtractionResult(investments: investments);
    } catch (e) {
      debugPrint('Direct Excel parsing failed: $e');
      return const AIExtractionResult(investments: []);
    }
  }

  /// Normalize investment name for comparison
  /// Handles variations like spaces, hyphens, underscores, case differences
  String _normalizeInvestmentName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\-_]+'), '') // Remove spaces, hyphens, underscores
        .replaceAll(RegExp(r'[^\w]'), '')    // Remove special characters
        .trim();
  }

  /// Try to parse a cell value as a date
  DateTime? _tryParseDate(dynamic value) {
    if (value == null) return null;

    if (value is DateCellValue) {
      return DateTime(value.year, value.month, value.day);
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      // Try parsing various date formats
      final str = value.trim();

      // Format: YYYY-MM-DD
      final match1 = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(str);
      if (match1 != null) {
        return DateTime(
          int.parse(match1.group(1)!),
          int.parse(match1.group(2)!),
          int.parse(match1.group(3)!),
        );
      }

      // Format: Mon-YY (e.g., Sept-25)
      final months = {
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
        'jul': 7, 'aug': 8, 'sep': 9, 'sept': 9, 'oct': 10, 'nov': 11, 'dec': 12,
      };
      final match2 = RegExp(r'^([a-zA-Z]+)-(\d{2})$').firstMatch(str);
      if (match2 != null) {
        final monthStr = match2.group(1)!.toLowerCase();
        final month = months[monthStr];
        if (month != null) {
          final year = 2000 + int.parse(match2.group(2)!);
          return DateTime(year, month, 1);
        }
      }
    }

    return null;
  }

  /// Extract numeric value from a cell
  double? _extractNumericValue(CellValue? cellValue) {
    if (cellValue == null) return null;

    if (cellValue is IntCellValue) {
      return cellValue.value.toDouble();
    }
    if (cellValue is DoubleCellValue) {
      return cellValue.value;
    }

    // For text and other types, convert to string first
    final str = cellValue.toString().replaceAll(',', '').trim();
    return double.tryParse(str);
  }

  Future<List<Content>> _buildContent(PlatformFile file, String prompt) async {
    final bytes = file.bytes;
    if (bytes == null) {
      throw Exception('Could not read file bytes');
    }

    final extension = file.extension?.toLowerCase() ?? '';

    // For CSV files, send as text
    if (extension == 'csv') {
      final text = utf8.decode(bytes);
      return [Content.text('$prompt\n\nDocument content:\n$text')];
    }

    // For Excel files, convert to text first (Gemini doesn't support XLSX directly)
    if (extension == 'xlsx' || extension == 'xls') {
      final text = _convertExcelToText(bytes);
      return [Content.text('$prompt\n\nDocument content (converted from Excel):\n$text')];
    }

    // For other files (PDF, images), send as inline data
    final mimeType = _getContentType(extension);
    return [
      Content.multi([
        TextPart(prompt),
        InlineDataPart(mimeType, bytes),
      ]),
    ];
  }

  /// Convert Excel file bytes to text format for Gemini
  String _convertExcelToText(Uint8List bytes) {
    try {
      final excel = Excel.decodeBytes(bytes);
      final buffer = StringBuffer();

      for (final sheetName in excel.tables.keys) {
        final sheet = excel.tables[sheetName];
        if (sheet == null) continue;

        buffer.writeln('=== Sheet: $sheetName ===');
        buffer.writeln();

        for (final row in sheet.rows) {
          final cells = row.map((cell) {
            if (cell == null) return '';
            final value = cell.value;
            if (value == null) return '';
            // Handle different cell value types
            if (value is DateCellValue) {
              return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
            }
            return value.toString();
          }).toList();

          // Only add non-empty rows
          if (cells.any((cell) => cell.isNotEmpty)) {
            buffer.writeln(cells.join('\t'));
          }
        }

        buffer.writeln();
      }

      return buffer.toString();
    } catch (e) {
      debugPrint('Error converting Excel to text: $e');
      throw Exception('Failed to read Excel file: ${e.toString()}');
    }
  }

  String _buildExtractionPrompt() {
    return '''
Extract investment cash flows from this document. Group by investment name.

For each transaction extract:
- date: YYYY-MM-DD format
- amount: positive number
- type: INVEST (money in), RETURN (money out), INCOME (dividends/interest), or FEE

Return ONLY valid JSON (no markdown, no extra text):
{"investments":[{"investment_name":"Fund A","cash_flows":[{"date":"2024-01-15","amount":1000,"type":"INVEST"}]}]}

IMPORTANT: Keep response compact. No notes, no confidence scores, no null values.
''';
  }

  AIExtractionResult _parseResponse(String responseText) {
    try {
      // Clean up response - remove markdown code blocks if present
      var cleanedResponse = responseText.trim();
      if (cleanedResponse.startsWith('```json')) {
        cleanedResponse = cleanedResponse.substring(7);
      } else if (cleanedResponse.startsWith('```')) {
        cleanedResponse = cleanedResponse.substring(3);
      }
      if (cleanedResponse.endsWith('```')) {
        cleanedResponse = cleanedResponse.substring(0, cleanedResponse.length - 3);
      }
      cleanedResponse = cleanedResponse.trim();

      final json = jsonDecode(cleanedResponse) as Map<String, dynamic>;

      // Support both new format (investments array) and legacy format (single investment)
      List<ExtractedInvestment> investments = [];

      if (json.containsKey('investments')) {
        // New multi-investment format
        final investmentsList = json['investments'] as List<dynamic>? ?? [];
        investments = investmentsList.map((invJson) {
          return ExtractedInvestment.fromJson(
            invJson as Map<String, dynamic>,
            _uuid.v4(),
            () => _uuid.v4(),
          );
        }).toList();
      } else if (json.containsKey('investment_name') || json.containsKey('cash_flows')) {
        // Legacy single investment format - convert to new format
        investments = [
          ExtractedInvestment.fromJson(json, _uuid.v4(), () => _uuid.v4()),
        ];
      }

      return AIExtractionResult(
        investments: investments,
        rawResponse: responseText,
      );
    } catch (e) {
      debugPrint('Error parsing response: $e');
      debugPrint('Raw response: $responseText');
      return AIExtractionResult(
        errorMessage: 'Failed to parse AI response: ${e.toString()}',
        rawResponse: responseText,
      );
    }
  }
}

