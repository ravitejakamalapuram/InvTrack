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

/// Provider for Firebase Storage instance
final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

/// Provider for AI Document Parsing Service
final aiDocumentParsingServiceProvider =
    Provider<AIDocumentParsingService>((ref) {
  final storage = ref.watch(firebaseStorageProvider);
  final authState = ref.watch(authStateProvider);
  final user = authState.valueOrNull;

  if (user == null || user.isGuest) {
    throw Exception('User must be signed in to use AI import');
  }

  return AIDocumentParsingService(
    storage: storage,
    userId: user.id,
  );
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
    this.state = AIImportState.idle,
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
      extractionResult:
          clearResult ? null : (extractionResult ?? this.extractionResult),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      selectedInvestmentId: selectedInvestmentId ?? this.selectedInvestmentId,
      newInvestmentName: newInvestmentName ?? this.newInvestmentName,
    );
  }
}

/// Provider for AI Import state management
final aiImportProvider =
    StateNotifierProvider<AIImportNotifier, AIImportStateData>((ref) {
  return AIImportNotifier(ref);
});

class AIImportNotifier extends StateNotifier<AIImportStateData> {
  final Ref _ref;
  final Uuid _uuid = const Uuid();

  AIImportNotifier(this._ref) : super(const AIImportStateData());

  /// Reset to initial state
  void reset() {
    state = const AIImportStateData();
  }

  /// Pick a document file
  Future<void> pickDocument() async {
    state = state.copyWith(state: AIImportState.pickingFile, clearError: true);

    try {
      final service = _ref.read(aiDocumentParsingServiceProvider);
      final file = await service.pickDocument();

      if (file == null) {
        state = state.copyWith(state: AIImportState.idle);
        return;
      }

      state = state.copyWith(
        state: AIImportState.extracting,
        selectedFile: file,
      );

      // Immediately start extraction
      await _extractData(file);
    } catch (e) {
      state = state.copyWith(
        state: AIImportState.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Extract data from the selected file
  Future<void> _extractData(PlatformFile file) async {
    try {
      final service = _ref.read(aiDocumentParsingServiceProvider);
      final result = await service.extractCashFlows(file);

      if (result.hasError) {
        state = state.copyWith(
          state: AIImportState.error,
          errorMessage: result.errorMessage,
          extractionResult: result,
        );
      } else if (result.isEmpty) {
        state = state.copyWith(
          state: AIImportState.error,
          errorMessage: 'No investment data found in the document',
          extractionResult: result,
        );
      } else {
        state = state.copyWith(
          state: AIImportState.reviewing,
          extractionResult: result,
          newInvestmentName: result.suggestedInvestmentName,
        );
      }
    } catch (e) {
      state = state.copyWith(
        state: AIImportState.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Toggle selection of a cash flow
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

  /// Select all cash flows
  void selectAll() {
    final result = state.extractionResult;
    if (result == null) return;

    final updatedCashFlows =
        result.cashFlows.map((cf) => cf.copyWith(isSelected: true)).toList();

    state = state.copyWith(
      extractionResult: result.copyWith(cashFlows: updatedCashFlows),
    );
  }

  /// Deselect all cash flows
  void deselectAll() {
    final result = state.extractionResult;
    if (result == null) return;

    final updatedCashFlows =
        result.cashFlows.map((cf) => cf.copyWith(isSelected: false)).toList();

    state = state.copyWith(
      extractionResult: result.copyWith(cashFlows: updatedCashFlows),
    );
  }

  /// Set target investment ID
  void setTargetInvestment(String? investmentId) {
    state = state.copyWith(selectedInvestmentId: investmentId);
  }

  /// Set new investment name
  void setNewInvestmentName(String? name) {
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
      String investmentId;

      // Use existing investment or create new one
      if (state.selectedInvestmentId != null) {
        investmentId = state.selectedInvestmentId!;
      } else {
        // Create new investment
        final investmentName =
            state.newInvestmentName ?? result.suggestedInvestmentName ?? 'Imported Investment';

        final newInvestment = InvestmentEntity(
          id: _uuid.v4(),
          name: investmentName,
          type: InvestmentType.other,
          status: InvestmentStatus.open,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repository.createInvestment(newInvestment);
        investmentId = newInvestment.id;
      }

      // Save each selected cash flow
      int savedCount = 0;
      for (final extracted in selectedCashFlows) {
        final cashFlow = CashFlowEntity(
          id: _uuid.v4(),
          investmentId: investmentId,
          date: extracted.date,
          type: extracted.type,
          amount: extracted.amount,
          notes: extracted.notes,
          createdAt: DateTime.now(),
        );

        await repository.addCashFlow(cashFlow);
        savedCount++;
      }

      // Invalidate investment providers to refresh data
      _ref.invalidate(allInvestmentsProvider);
      _ref.invalidate(allCashFlowsStreamProvider);

      state = state.copyWith(state: AIImportState.completed);
      return savedCount;
    } catch (e) {
      state = state.copyWith(
        state: AIImportState.error,
        errorMessage: 'Failed to save: $e',
      );
      return 0;
    }
  }
}

