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

/// Represents an investment with its extracted cash flows
class ExtractedInvestment {
  final String id;
  final String suggestedName;
  final String editedName;
  final List<ExtractedCashFlow> cashFlows;
  final bool isSelected;

  const ExtractedInvestment({
    required this.id,
    required this.suggestedName,
    String? editedName,
    this.cashFlows = const [],
    this.isSelected = true,
  }) : editedName = editedName ?? suggestedName;

  /// The name to use (edited or suggested)
  String get name => editedName.isNotEmpty ? editedName : suggestedName;

  int get selectedCashFlowCount => cashFlows.where((cf) => cf.isSelected).length;

  List<ExtractedCashFlow> get selectedCashFlows =>
      cashFlows.where((cf) => cf.isSelected).toList();

  ExtractedInvestment copyWith({
    String? id,
    String? suggestedName,
    String? editedName,
    List<ExtractedCashFlow>? cashFlows,
    bool? isSelected,
  }) {
    return ExtractedInvestment(
      id: id ?? this.id,
      suggestedName: suggestedName ?? this.suggestedName,
      editedName: editedName ?? this.editedName,
      cashFlows: cashFlows ?? this.cashFlows,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  /// Factory to create from AI JSON response
  factory ExtractedInvestment.fromJson(
    Map<String, dynamic> json,
    String id,
    String Function() generateCashFlowId,
  ) {
    final name = json['investment_name'] as String? ?? 'Unknown Investment';
    final cashFlowsList = json['cash_flows'] as List<dynamic>? ?? [];

    final cashFlows = cashFlowsList.map((cfJson) {
      return ExtractedCashFlow.fromJson(
        cfJson as Map<String, dynamic>,
        generateCashFlowId(),
      );
    }).toList();

    return ExtractedInvestment(
      id: id,
      suggestedName: name,
      cashFlows: cashFlows,
    );
  }
}

/// Result of AI extraction containing all extracted investments
class AIExtractionResult {
  final List<ExtractedInvestment> investments;
  final String? errorMessage;
  final String? rawResponse;

  const AIExtractionResult({
    this.investments = const [],
    this.errorMessage,
    this.rawResponse,
  });

  bool get isEmpty => investments.isEmpty || investments.every((inv) => inv.cashFlows.isEmpty);
  bool get hasError => errorMessage != null;

  /// Total selected cash flows across all investments
  int get selectedCount => investments.fold(
    0,
    (sum, inv) => sum + (inv.isSelected ? inv.selectedCashFlowCount : 0),
  );

  /// Total cash flows across all investments
  int get totalCashFlowCount => investments.fold(
    0,
    (sum, inv) => sum + inv.cashFlows.length,
  );

  /// Number of selected investments
  int get selectedInvestmentCount => investments.where((inv) => inv.isSelected).length;

  AIExtractionResult copyWith({
    List<ExtractedInvestment>? investments,
    String? errorMessage,
    String? rawResponse,
  }) {
    return AIExtractionResult(
      investments: investments ?? this.investments,
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

