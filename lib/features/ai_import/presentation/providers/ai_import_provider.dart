import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/ai_import/domain/entities/extracted_cash_flow.dart';
import 'package:inv_tracker/features/ai_import/domain/services/ai_document_parsing_service.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_provider.dart';
import 'package:uuid/uuid.dart';

/// Provider for Firebase Storage
final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

/// Provider for AI Document Parsing Service
final aiDocumentParsingServiceProvider = Provider<AIDocumentParsingService>((ref) {
  return AIDocumentParsingService(storage: ref.watch(firebaseStorageProvider));
});

/// State class for AI Import
class AIImportStateData {
  final AIImportState state;
  final PlatformFile? selectedFile;
  final AIExtractionResult? extractionResult;
  final String? errorMessage;
  final String? selectedInvestmentId;
  final String? newInvestmentName;

  const AIImportStateData({
    this.state = AIImportState.initial,
    this.selectedFile,
    this.extractionResult,
    this.errorMessage,
    this.selectedInvestmentId,
    this.newInvestmentName,
  });

  AIImportStateData copyWith({
    AIImportState? state,
    PlatformFile? selectedFile,
    AIExtractionResult? extractionResult,
    String? errorMessage,
    String? selectedInvestmentId,
    String? newInvestmentName,
    bool clearFile = false,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return AIImportStateData(
      state: state ?? this.state,
      selectedFile: clearFile ? null : (selectedFile ?? this.selectedFile),
      extractionResult: clearResult ? null : (extractionResult ?? this.extractionResult),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      selectedInvestmentId: selectedInvestmentId ?? this.selectedInvestmentId,
      newInvestmentName: newInvestmentName ?? this.newInvestmentName,
    );
  }
}

/// StateNotifier for AI Import
class AIImportNotifier extends StateNotifier<AIImportStateData> {
  final AIDocumentParsingService _service;
  final Ref _ref;
  final Uuid _uuid = const Uuid();

  AIImportNotifier(this._service, this._ref) : super(const AIImportStateData());

  void reset() {
    state = const AIImportStateData();
  }

  Future<void> pickDocument() async {
    state = state.copyWith(state: AIImportState.pickingFile, clearError: true);
    
    try {
      final file = await _service.pickDocument();
      if (file == null) {
        state = state.copyWith(state: AIImportState.initial);
        return;
      }
      
      state = state.copyWith(
        state: AIImportState.extracting,
        selectedFile: file,
      );
      
      // Extract cash flows using Gemini
      final result = await _service.extractCashFlows(file);
      
      if (result.hasError) {
        state = state.copyWith(
          state: AIImportState.error,
          errorMessage: result.errorMessage,
          extractionResult: result,
        );
        return;
      }
      
      state = state.copyWith(
        state: AIImportState.reviewing,
        extractionResult: result,
        newInvestmentName: result.suggestedInvestmentName,
      );
    } catch (e) {
      state = state.copyWith(
        state: AIImportState.error,
        errorMessage: e.toString(),
      );
    }
  }

  void toggleCashFlowSelection(String id) {
    final result = state.extractionResult;
    if (result == null) return;

    final updatedCashFlows = result.cashFlows.map((cf) {
      if (cf.id == id) {
        return cf.copyWith(isSelected: !cf.isSelected);
      }
      return cf;
    }).toList();

    state = state.copyWith(
      extractionResult: result.copyWith(cashFlows: updatedCashFlows),
    );
  }

  void selectAll() {
    final result = state.extractionResult;
    if (result == null) return;

    final updatedCashFlows = result.cashFlows.map((cf) {
      return cf.copyWith(isSelected: true);
    }).toList();

    state = state.copyWith(
      extractionResult: result.copyWith(cashFlows: updatedCashFlows),
    );
  }

  void deselectAll() {
    final result = state.extractionResult;
    if (result == null) return;

    final updatedCashFlows = result.cashFlows.map((cf) {
      return cf.copyWith(isSelected: false);
    }).toList();

    state = state.copyWith(
      extractionResult: result.copyWith(cashFlows: updatedCashFlows),
    );
  }

  void setNewInvestmentName(String name) {
    state = state.copyWith(newInvestmentName: name);
  }

  /// Save selected cash flows to Firestore
  Future<int> saveSelectedCashFlows() async {
    final result = state.extractionResult;
    if (result == null) return 0;

    final selectedCashFlows = result.selectedCashFlows;
    if (selectedCashFlows.isEmpty) return 0;

    state = state.copyWith(state: AIImportState.saving);

    try {
      final repository = _ref.read(investmentRepositoryProvider);
      final user = _ref.read(authStateProvider).value;
      if (user == null) {
        state = state.copyWith(
          state: AIImportState.error,
          errorMessage: 'User not authenticated',
        );
        return 0;
      }

      // Create a new investment
      final investmentName = state.newInvestmentName ?? 'Imported Investment';
      final now = DateTime.now();
      final investment = InvestmentEntity(
        id: _uuid.v4(),
        name: investmentName,
        type: InvestmentType.other,
        status: InvestmentStatus.open,
        createdAt: now,
        updatedAt: now,
      );

      await repository.createInvestment(investment);

      // Add all selected cash flows
      for (final extractedCf in selectedCashFlows) {
        final cashFlow = CashFlowEntity(
          id: _uuid.v4(),
          investmentId: investment.id,
          date: extractedCf.date,
          amount: extractedCf.amount,
          type: extractedCf.type,
          notes: extractedCf.notes,
          createdAt: now,
        );
        await repository.addCashFlow(cashFlow);
      }

      // Invalidate investment providers to refresh data
      _ref.invalidate(allInvestmentsProvider);
      _ref.invalidate(allCashFlowsStreamProvider);

      state = state.copyWith(state: AIImportState.completed);
      return selectedCashFlows.length;
    } catch (e) {
      state = state.copyWith(
        state: AIImportState.error,
        errorMessage: 'Failed to save cash flows: ${e.toString()}',
      );
      return 0;
    }
  }
}

/// Provider for AI Import state
final aiImportProvider = StateNotifierProvider<AIImportNotifier, AIImportStateData>((ref) {
  return AIImportNotifier(
    ref.watch(aiDocumentParsingServiceProvider),
    ref,
  );
});

