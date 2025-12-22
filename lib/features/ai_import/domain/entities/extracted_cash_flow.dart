import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

/// Represents a cash flow extracted from a document by AI
class ExtractedCashFlow {
  final String id;
  final DateTime date;
  final double amount;
  final CashFlowType type;
  final double confidence;
  final String? notes;
  final bool isSelected;

  const ExtractedCashFlow({
    required this.id,
    required this.date,
    required this.amount,
    required this.type,
    required this.confidence,
    this.notes,
    this.isSelected = true,
  });

  ExtractedCashFlow copyWith({
    String? id,
    DateTime? date,
    double? amount,
    CashFlowType? type,
    double? confidence,
    String? notes,
    bool? isSelected,
  }) {
    return ExtractedCashFlow(
      id: id ?? this.id,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      confidence: confidence ?? this.confidence,
      notes: notes ?? this.notes,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  /// Get confidence level as a category
  String get confidenceLevel {
    if (confidence >= 0.9) return 'High';
    if (confidence >= 0.7) return 'Medium';
    return 'Low';
  }

  /// Factory to create from AI JSON response
  factory ExtractedCashFlow.fromJson(Map<String, dynamic> json, String id) {
    return ExtractedCashFlow(
      id: id,
      date: _parseDate(json['date'] as String?),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      type: _parseType(json['type'] as String?),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      notes: json['notes'] as String?,
    );
  }

  static DateTime _parseDate(String? dateStr) {
    if (dateStr == null) return DateTime.now();
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return DateTime.now();
    }
  }

  static CashFlowType _parseType(String? typeStr) {
    if (typeStr == null) return CashFlowType.invest;
    switch (typeStr.toUpperCase()) {
      case 'INVEST':
        return CashFlowType.invest;
      case 'RETURN':
        return CashFlowType.returnFlow;
      case 'INCOME':
        return CashFlowType.income;
      case 'FEE':
        return CashFlowType.fee;
      default:
        return CashFlowType.invest;
    }
  }
}

/// Result of AI extraction containing all extracted cash flows
class AIExtractionResult {
  final String? suggestedInvestmentName;
  final List<ExtractedCashFlow> cashFlows;
  final String? errorMessage;
  final String? rawResponse;

  const AIExtractionResult({
    this.suggestedInvestmentName,
    this.cashFlows = const [],
    this.errorMessage,
    this.rawResponse,
  });

  bool get isEmpty => cashFlows.isEmpty;
  bool get hasError => errorMessage != null;

  int get selectedCount => cashFlows.where((cf) => cf.isSelected).length;

  List<ExtractedCashFlow> get selectedCashFlows =>
      cashFlows.where((cf) => cf.isSelected).toList();

  AIExtractionResult copyWith({
    String? suggestedInvestmentName,
    List<ExtractedCashFlow>? cashFlows,
    String? errorMessage,
    String? rawResponse,
  }) {
    return AIExtractionResult(
      suggestedInvestmentName: suggestedInvestmentName ?? this.suggestedInvestmentName,
      cashFlows: cashFlows ?? this.cashFlows,
      errorMessage: errorMessage ?? this.errorMessage,
      rawResponse: rawResponse ?? this.rawResponse,
    );
  }
}

/// State of the AI import process
enum AIImportState {
  initial,
  pickingFile,
  uploading,
  extracting,
  reviewing,
  saving,
  completed,
  error,
}

