import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:inv_tracker/features/ai_import/domain/entities/extracted_cash_flow.dart';
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

  /// Extract cash flows from a document using Gemini AI
  Future<AIExtractionResult> extractCashFlows(PlatformFile file) async {
    try {
      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.0-flash',
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
    } catch (e) {
      debugPrint('Error extracting cash flows: $e');
      return AIExtractionResult(
        errorMessage: 'Failed to extract data: ${e.toString()}',
      );
    }
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

    // For other files, send as inline data
    final mimeType = _getContentType(extension);
    return [
      Content.multi([
        TextPart(prompt),
        InlineDataPart(mimeType, bytes),
      ]),
    ];
  }

  String _buildExtractionPrompt() {
    return '''
You are an investment data extraction assistant. Analyze the provided document
and extract all investment-related cash flows.

For each transaction, determine:
1. DATE: The transaction date (format: YYYY-MM-DD)
2. AMOUNT: The monetary value (positive number)
3. TYPE: One of:
   - INVEST: Money invested (purchases, deposits, SIPs)
   - RETURN: Money returned (sales, redemptions, withdrawals)
   - INCOME: Dividends, interest, or other income
   - FEE: Fees, charges, or expenses
4. CONFIDENCE: Your confidence in this extraction (0.0 to 1.0)
5. NOTES: Any relevant notes about the transaction

Also try to infer the investment name from the document.

Return ONLY valid JSON (no markdown) in this format:
{
  "investment_name": "Name of the investment",
  "cash_flows": [
    {
      "date": "2024-01-15",
      "amount": 1000.00,
      "type": "INVEST",
      "confidence": 0.95,
      "notes": "Initial investment"
    }
  ]
}

If you cannot determine a field with confidence, set confidence to 0.5 or lower.
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
      final investmentName = json['investment_name'] as String?;
      final cashFlowsList = json['cash_flows'] as List<dynamic>? ?? [];

      final cashFlows = cashFlowsList.map((cfJson) {
        return ExtractedCashFlow.fromJson(cfJson as Map<String, dynamic>, _uuid.v4());
      }).toList();

      return AIExtractionResult(
        suggestedInvestmentName: investmentName,
        cashFlows: cashFlows,
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

