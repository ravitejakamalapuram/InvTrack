/// Income Guardian background sync service for automatic payment matching.
///
/// This service:
/// - Monitors new cash flow transactions in real-time
/// - Automatically matches actual payments to expected cash flows
/// - Updates status from pending → received
/// - Learns platform delays for better predictions
/// - Tracks variance for confidence scoring
library;

import 'dart:async';

import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/features/income_projection/domain/entities/expected_cash_flow_entity.dart';
import 'package:inv_tracker/features/income_projection/domain/repositories/expected_cash_flow_repository.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';

/// Income Guardian background sync service
class IncomeGuardianSyncService {
  final ExpectedCashFlowRepository _expectedCashFlowRepository;
  final InvestmentRepository _investmentRepository;

  StreamSubscription<List<CashFlowEntity>>? _cashFlowSubscription;
  bool _isSyncing = false;

  // Track processed cash flow IDs to avoid duplicate matching
  final Set<String> _processedCashFlows = {};

  IncomeGuardianSyncService({
    required ExpectedCashFlowRepository expectedCashFlowRepository,
    required InvestmentRepository investmentRepository,
  })  : _expectedCashFlowRepository = expectedCashFlowRepository,
        _investmentRepository = investmentRepository;

  /// Start background sync
  Future<void> startSync() async {
    if (_isSyncing) return;

    LoggerService.info('Income Guardian sync service started');
    _isSyncing = true;

    // Monitor all cash flows (we'll filter for income in the handler)
    _cashFlowSubscription = _investmentRepository
        .watchAllCashFlows()
        .listen(_handleNewCashFlows);
  }

  /// Stop background sync
  void stopSync() {
    if (!_isSyncing) return;

    LoggerService.info('Income Guardian sync service stopped');
    _isSyncing = false;

    _cashFlowSubscription?.cancel();
    _processedCashFlows.clear();
  }

  /// Handle new cash flows and attempt to match with expected cash flows
  Future<void> _handleNewCashFlows(
    List<CashFlowEntity> cashFlows,
  ) async {
    // Filter for income cash flows only
    final incomeCashFlows = cashFlows
        .where((cf) => cf.type == CashFlowType.income)
        .where((cf) => !_processedCashFlows.contains(cf.id))
        .toList();

    if (incomeCashFlows.isEmpty) return;

    LoggerService.info(
      'Processing ${incomeCashFlows.length} new income cash flows',
    );

    for (final cashFlow in incomeCashFlows) {
      await _attemptMatch(cashFlow);
      _processedCashFlows.add(cashFlow.id);
    }
  }

  /// Attempt to match a cash flow with expected cash flows
  Future<void> _attemptMatch(CashFlowEntity cashFlow) async {
    // Get all pending expected cash flows for this investment
    final allExpectedCashFlows = await _expectedCashFlowRepository
        .watchExpectedCashFlowsByInvestment(cashFlow.investmentId)
        .first;

    final pendingCashFlows = allExpectedCashFlows
        .where((cf) => cf.status != ExpectedCashFlowStatus.received)
        .where((cf) => cf.status != ExpectedCashFlowStatus.dismissed)
        .toList();

    if (pendingCashFlows.isEmpty) return;

    // Find best match using fuzzy matching algorithm
    final bestMatch = _findBestMatch(cashFlow, pendingCashFlows);

    if (bestMatch == null) {
      LoggerService.info(
        'No match found for cash flow',
        metadata: {
          'cashFlowId': cashFlow.id,
          'amount': cashFlow.amount,
          'date': cashFlow.date.toString(),
        },
      );
      return;
    }

    // Update expected cash flow with actual data
    await _markAsReceived(
      expectedCashFlow: bestMatch,
      actualCashFlow: cashFlow,
    );
  }

  /// Find best matching expected cash flow for a cash flow
  ExpectedCashFlowEntity? _findBestMatch(
    CashFlowEntity cashFlow,
    List<ExpectedCashFlowEntity> candidates,
  ) {
    if (candidates.isEmpty) return null;

    // Scoring algorithm:
    // 1. Date proximity (closer = higher score)
    // 2. Amount similarity (closer = higher score)
    // 3. Prefer overdue/grace period over upcoming

    ExpectedCashFlowEntity? bestMatch;
    double bestScore = 0.0;

    for (final candidate in candidates) {
      final score = _calculateMatchScore(cashFlow, candidate);

      if (score > bestScore && score > 0.5) {
        // Require at least 50% confidence
        bestScore = score;
        bestMatch = candidate;
      }
    }

    if (bestMatch != null) {
      LoggerService.info(
        'Match found',
        metadata: {
          'cashFlowId': cashFlow.id,
          'expectedCashFlowId': bestMatch.id,
          'score': bestScore,
        },
      );
    }

    return bestMatch;
  }

  /// Calculate match score between cash flow and expected cash flow
  /// Returns 0.0 to 1.0 (higher = better match)
  double _calculateMatchScore(
    CashFlowEntity cashFlow,
    ExpectedCashFlowEntity expectedCashFlow,
  ) {
    // Date proximity score (within 30 days = valid)
    final daysDifference = cashFlow.date.difference(expectedCashFlow.expectedDate).inDays.abs();
    final dateScore = daysDifference <= 30 ? (1.0 - (daysDifference / 30)) : 0.0;

    // Amount similarity score (within 20% = valid)
    final amountDifference = (cashFlow.amount - expectedCashFlow.expectedAmount).abs();
    final amountPercentDiff = amountDifference / expectedCashFlow.expectedAmount;
    final amountScore = amountPercentDiff <= 0.2 ? (1.0 - (amountPercentDiff / 0.2)) : 0.0;

    // Combined score (weighted: 60% date, 40% amount)
    return (dateScore * 0.6) + (amountScore * 0.4);
  }

  /// Mark expected cash flow as received with actual cash flow data
  Future<void> _markAsReceived({
    required ExpectedCashFlowEntity expectedCashFlow,
    required CashFlowEntity actualCashFlow,
  }) async {
    // Calculate platform delay (actual date - expected date)
    final platformDelayDays = actualCashFlow.date
        .difference(expectedCashFlow.expectedDate)
        .inDays;

    // Calculate variance factor (actual amount / expected amount)
    final varianceFactor = actualCashFlow.amount / expectedCashFlow.expectedAmount;

    // Update expected cash flow
    final updatedCashFlow = expectedCashFlow.copyWith(
      status: ExpectedCashFlowStatus.received,
      matchedCashFlowId: actualCashFlow.id,
      actualAmount: actualCashFlow.amount,
      actualDate: actualCashFlow.date,
      platformDelayDays: platformDelayDays,
      varianceFactor: varianceFactor,
    );

    await _expectedCashFlowRepository.updateExpectedCashFlow(updatedCashFlow);

    LoggerService.info(
      'Expected cash flow marked as received',
      metadata: {
        'expectedCashFlowId': expectedCashFlow.id,
        'cashFlowId': actualCashFlow.id,
        'platformDelayDays': platformDelayDays,
        'varianceFactor': varianceFactor.toStringAsFixed(2),
        'expectedAmount': expectedCashFlow.expectedAmount,
        'actualAmount': actualCashFlow.amount,
      },
    );
  }
}
