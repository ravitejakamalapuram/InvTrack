import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/goals/data/repositories/firestore_goal_repository.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/repositories/goal_repository.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:uuid/uuid.dart';

/// Provider for GoalRepository
/// Throws AuthException.notAuthenticated if user is not authenticated
final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final authState = ref.watch(authStateProvider);

  // Get user ID from auth state
  final user = authState.value;
  if (user == null) {
    // Throw a specific exception that UI can catch and handle gracefully
    throw AuthException.notAuthenticated();
  }

  return FirestoreGoalRepository(firestore: firestore, userId: user.id);
});

/// Stream provider for all active goals
/// Returns empty list if user is not authenticated
final activeGoalsProvider = StreamProvider<List<GoalEntity>>((ref) {
  // Check auth first to avoid exception when user signs out
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  if (!isAuthenticated) {
    return Stream.value([]);
  }
  return ref.watch(goalRepositoryProvider).watchActiveGoals();
});

/// Stream provider for all goals (active only with separate collections)
/// Returns empty list if user is not authenticated
/// Note: With separate collections, this is the same as activeGoalsProvider
final allGoalsProvider = StreamProvider<List<GoalEntity>>((ref) {
  // Check auth first to avoid exception when user signs out
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  if (!isAuthenticated) {
    return Stream.value([]);
  }
  return ref.watch(goalRepositoryProvider).watchAllGoals();
});

/// Stream provider for archived goals
/// Returns empty list if user is not authenticated
final archivedGoalsProvider = StreamProvider<List<GoalEntity>>((ref) {
  // Check auth first to avoid exception when user signs out
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  if (!isAuthenticated) {
    return Stream.value([]);
  }
  return ref.watch(goalRepositoryProvider).watchArchivedGoals();
});

/// Provider for goal counts by filter (for filter tabs)
/// Note: Goals only have active/archived filters (no open/closed like investments)
final goalCountsProvider = Provider<({int active, int archived})>((ref) {
  final activeGoals = ref.watch(activeGoalsProvider).value ?? [];
  final archivedGoals = ref.watch(archivedGoalsProvider).value ?? [];
  return (active: activeGoals.length, archived: archivedGoals.length);
});

/// Provider for a single goal by ID (one-time fetch)
/// Returns null if user is not authenticated
final goalByIdProvider = FutureProvider.family<GoalEntity?, String>((
  ref,
  id,
) async {
  // Check auth first to avoid exception when user signs out
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  if (!isAuthenticated) {
    return null;
  }
  return ref.watch(goalRepositoryProvider).getGoalById(id);
});

/// Stream provider for watching a single goal by ID (real-time updates)
/// Returns null if user is not authenticated
final watchGoalByIdProvider = StreamProvider.family<GoalEntity?, String>((
  ref,
  id,
) {
  // Check auth first to avoid exception when user signs out
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  if (!isAuthenticated) {
    return Stream.value(null);
  }
  return ref.watch(goalRepositoryProvider).watchGoalById(id);
});

/// Notifier for goal operations
class GoalNotifier extends Notifier<AsyncValue<void>> {
  final Uuid _uuid = const Uuid();

  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  GoalRepository get _repository => ref.read(goalRepositoryProvider);
  AnalyticsService get _analytics => ref.read(analyticsServiceProvider);

  /// Create a new goal
  Future<String> createGoal({
    required String name,
    required GoalType type,
    required double targetAmount,
    double? targetMonthlyIncome,
    DateTime? targetDate,
    required GoalTrackingMode trackingMode,
    List<String> linkedInvestmentIds = const [],
    List<InvestmentType> linkedTypes = const [],
    String? icon,
    int? colorValue,
  }) async {
    state = const AsyncValue.loading();
    try {
      final id = _uuid.v4();
      final goal = GoalEntity(
        id: id,
        name: name,
        type: type,
        targetAmount: targetAmount,
        targetMonthlyIncome: targetMonthlyIncome,
        targetDate: targetDate,
        trackingMode: trackingMode,
        linkedInvestmentIds: linkedInvestmentIds,
        linkedTypes: linkedTypes,
        icon: icon ?? GoalIcons.defaultIcon,
        colorValue: colorValue ?? GoalColors.defaultColor.toARGB32(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _repository.createGoal(goal);
      _analytics.logGoalCreated(
        goalType: type.name,
        trackingMode: trackingMode.name,
        hasDeadline: targetDate != null,
      );
      state = const AsyncValue.data(null);
      return id;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Update an existing goal
  Future<void> updateGoal(GoalEntity goal) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateGoal(goal.copyWith(updatedAt: DateTime.now()));
      _analytics.logGoalUpdated(goalId: goal.id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Archive a goal
  Future<void> archiveGoal(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repository.archiveGoal(id);
      _analytics.logGoalArchived(goalId: id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Unarchive a goal
  Future<void> unarchiveGoal(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repository.unarchiveGoal(id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Delete a goal permanently
  Future<void> deleteGoal(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteGoal(id);
      _analytics.logGoalDeleted(goalId: id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Bulk delete multiple goals
  Future<int> bulkDelete(List<String> goalIds) async {
    if (goalIds.isEmpty) return 0;

    state = const AsyncValue.loading();
    try {
      var deletedCount = 0;
      for (final id in goalIds) {
        await _repository.deleteGoal(id);
        _analytics.logGoalDeleted(goalId: id);
        deletedCount++;
      }
      state = const AsyncValue.data(null);
      return deletedCount;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

/// Provider for goal operations
final goalNotifierProvider = NotifierProvider<GoalNotifier, AsyncValue<void>>(
  GoalNotifier.new,
);

/// Alias for backward compatibility
final goalsNotifierProvider = goalNotifierProvider;
