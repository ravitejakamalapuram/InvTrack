import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

/// Represents a cash flow extracted by AI from a document.
/// Contains confidence score and selection state for user review.
class ExtractedCashFlow {
  final String id;
  final DateTime date;
  final double amount;
  final CashFlowType type;
  final double confidence;
  final String? notes;
  final String? investmentName;
  final bool isSelected;

  const ExtractedCashFlow({
    required this.id,
    required this.date,
    required this.amount,
    required this.type,
    required this.confidence,
    this.notes,
    this.investmentName,
    this.isSelected = true,
  });

  /// Create from JSON response from Gemini
  factory ExtractedCashFlow.fromJson(Map<String, dynamic> json, String id) {
    return ExtractedCashFlow(
      id: id,
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      type: CashFlowType.fromString(json['type']?.toString() ?? 'INVEST'),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      notes: json['notes']?.toString(),
      investmentName: json['investment_name']?.toString(),
      isSelected: true,
    );
  }

  ExtractedCashFlow copyWith({
    String? id,
    DateTime? date,
    double? amount,
    CashFlowType? type,
    double? confidence,
    String? notes,
    String? investmentName,
    bool? isSelected,
  }) {
    return ExtractedCashFlow(
      id: id ?? this.id,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      confidence: confidence ?? this.confidence,
      notes: notes ?? this.notes,
      investmentName: investmentName ?? this.investmentName,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  /// Returns the confidence level as a human-readable string
  String get confidenceLabel {
    if (confidence >= 0.9) return 'High';
    if (confidence >= 0.7) return 'Medium';
    if (confidence >= 0.5) return 'Low';
    return 'Very Low';
  }

  /// Returns true if the confidence is high enough for auto-selection
  bool get isHighConfidence => confidence >= 0.8;
}

/// Result of AI document parsing
class AIExtractionResult {
  final String? suggestedInvestmentName;
  final List<ExtractedCashFlow> cashFlows;
  final String? rawResponse;
  final String? errorMessage;

  const AIExtractionResult({
    this.suggestedInvestmentName,
    this.cashFlows = const [],
    this.rawResponse,
    this.errorMessage,
  });

  bool get hasError => errorMessage != null;
  bool get isEmpty => cashFlows.isEmpty;
  int get count => cashFlows.length;

  /// Get only selected cash flows
  List<ExtractedCashFlow> get selectedCashFlows =>
      cashFlows.where((cf) => cf.isSelected).toList();

  /// Get the count of selected cash flows
  int get selectedCount => selectedCashFlows.length;

  AIExtractionResult copyWith({
    String? suggestedInvestmentName,
    List<ExtractedCashFlow>? cashFlows,
    String? rawResponse,
    String? errorMessage,
  }) {
    return AIExtractionResult(
      suggestedInvestmentName:
          suggestedInvestmentName ?? this.suggestedInvestmentName,
      cashFlows: cashFlows ?? this.cashFlows,
      rawResponse: rawResponse ?? this.rawResponse,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// State of the AI import process
enum AIImportState {
  idle,
  pickingFile,
  uploading,
  extracting,
  reviewing,
  saving,
  completed,
  error,
}

