import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:inv_tracker/features/ai_import/domain/entities/extracted_cash_flow.dart';
import 'package:uuid/uuid.dart';

/// Service for AI-powered document parsing using Firebase AI (Gemini)
class AIDocumentParsingService {
  final FirebaseStorage _storage;
  final String _userId;
  final Uuid _uuid = const Uuid();

  // Use Gemini 2.0 Flash for cost-effective extraction
  static const String _modelName = 'gemini-2.0-flash';

  AIDocumentParsingService({
    required FirebaseStorage storage,
    required String userId,
  })  : _storage = storage,
        _userId = userId;

  /// Prompt template for extracting investment cash flows
  static const String _extractionPrompt = '''
You are an investment data extraction assistant. Analyze the provided document 
and extract all investment-related cash flows.

For each transaction, determine:
1. DATE: The transaction date (format: YYYY-MM-DD)
2. AMOUNT: The monetary value (always positive number)
3. TYPE: One of:
   - INVEST: Money invested (purchases, deposits, SIPs, contributions)
   - RETURN: Money returned (sales, redemptions, withdrawals, exits)
   - INCOME: Dividends, interest, rent, or other income
   - FEE: Fees, charges, expenses, or commissions
4. CONFIDENCE: Your confidence in this extraction (0.0 to 1.0)
5. NOTES: Any relevant notes about the transaction
6. INVESTMENT_NAME: The name of the investment if identifiable

Return a JSON object with:
{
  "investment_name": "Name of the investment or fund if identifiable",
  "cash_flows": [
    {
      "date": "YYYY-MM-DD",
      "amount": 1000.00,
      "type": "INVEST",
      "confidence": 0.95,
      "notes": "Initial investment",
      "investment_name": "Fund Name"
    }
  ]
}

Important:
- All amounts should be positive numbers
- If you cannot determine a field with confidence, set confidence to 0.5 or lower
- Extract ALL transactions you can find in the document
- If no investment data is found, return {"investment_name": null, "cash_flows": []}
''';

  /// Pick a document file
  Future<PlatformFile?> pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls', 'pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final file = result.files.first;

      // Check file size (max 10MB)
      if (file.size > 10 * 1024 * 1024) {
        throw Exception('File size exceeds 10MB limit');
      }

      return file;
    } catch (e) {
      debugPrint('Error picking document: $e');
      rethrow;
    }
  }

  /// Upload file to Firebase Storage temporarily
  Future<String> uploadToStorage(PlatformFile file) async {
    try {
      final fileName = '${_uuid.v4()}_${file.name}';
      final ref = _storage.ref('temp_imports/$_userId/$fileName');

      Uint8List bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      } else {
        throw Exception('Cannot read file data');
      }

      await ref.putData(bytes);
      return ref.fullPath;
    } catch (e) {
      debugPrint('Error uploading file: $e');
      rethrow;
    }
  }

  /// Delete temporary file from Storage
  Future<void> deleteFromStorage(String path) async {
    try {
      await _storage.ref(path).delete();
    } catch (e) {
      debugPrint('Error deleting temp file: $e');
      // Don't rethrow - cleanup failure shouldn't break the flow
    }
  }

  /// Extract cash flows from document using Gemini
  Future<AIExtractionResult> extractCashFlows(PlatformFile file) async {
    try {
      // Get file bytes
      Uint8List bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      } else {
        throw Exception('Cannot read file data');
      }

      // Determine MIME type
      final mimeType = _getMimeType(file.extension ?? '');

      // Get the Gemini model through Firebase AI
      final model = FirebaseAI.googleAI().generativeModel(model: _modelName);

      // Create content parts based on file type
      List<Part> parts;
      if (_isTextBasedFile(file.extension ?? '')) {
        // For CSV/text files, send as text
        final textContent = utf8.decode(bytes);
        parts = [
          TextPart(_extractionPrompt),
          TextPart('Document content:\n$textContent'),
        ];
      } else {
        // For images/PDFs, send as inline data
        parts = [
          TextPart(_extractionPrompt),
          InlineDataPart(mimeType, bytes),
        ];
      }

      // Generate response
      final response = await model.generateContent([Content.multi(parts)]);
      final responseText = response.text ?? '';

      return _parseResponse(responseText);
    } catch (e) {
      debugPrint('Error extracting cash flows: $e');
      return AIExtractionResult(errorMessage: e.toString());
    }
  }

  /// Parse Gemini response into AIExtractionResult
  AIExtractionResult _parseResponse(String responseText) {
    try {
      // Extract JSON from the response (may be wrapped in markdown)
      String jsonStr = responseText;

      // Remove markdown code blocks if present
      final jsonMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(responseText);
      if (jsonMatch != null) {
        jsonStr = jsonMatch.group(1)?.trim() ?? responseText;
      }

      // Try to find JSON object in the response
      final startIdx = jsonStr.indexOf('{');
      final endIdx = jsonStr.lastIndexOf('}');
      if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
        jsonStr = jsonStr.substring(startIdx, endIdx + 1);
      }

      final Map<String, dynamic> json = jsonDecode(jsonStr);

      final investmentName = json['investment_name']?.toString();
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
        errorMessage: 'Failed to parse AI response: $e',
        rawResponse: responseText,
      );
    }
  }

  /// Get MIME type from file extension
  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'csv':
        return 'text/csv';
      case 'xlsx':
      case 'xls':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
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

  /// Check if file is text-based (can be read as string)
  bool _isTextBasedFile(String extension) {
    return extension.toLowerCase() == 'csv';
  }
}

