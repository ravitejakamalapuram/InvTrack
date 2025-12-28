import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_sizes.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/widgets/premium_animations.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goal_card.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goals_empty_state.dart';

/// Filter options for goals list
enum GoalsFilter { active, archived, all }

/// Main screen displaying all goals
class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen>
    with SingleTickerProviderStateMixin {
  GoalsFilter _filter = GoalsFilter.active;
  late AnimationController _fabController;
  late Animation<double> _fabScale;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fabScale = CurvedAnimation(parent: _fabController, curve: Curves.easeOut);
    _fabController.forward();
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Use separate providers for active and archived goals
    final activeGoalsAsync = ref.watch(activeGoalsProvider);
    final archivedGoalsAsync = ref.watch(archivedGoalsProvider);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      body: CustomScrollView(
        slivers: [
          // App Bar - matching Investment screen style
          SliverAppBar(
            expandedHeight: 56,
            floating: true,
            pinned: true,
            backgroundColor: isDark
                ? AppColors.surfaceDark
                : AppColors.surfaceLight,
            titleSpacing: AppSpacing.md,
            title: Text(
              'Goals',
              style: AppTypography.h2.copyWith(
                color: isDark ? Colors.white : AppColors.neutral900Light,
                fontSize: 22,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_rounded),
                onPressed: () => context.push('/goals/create'),
                tooltip: 'Add Goal',
              ),
              SizedBox(width: AppSpacing.sm),
            ],
          ),

          // Filter Tabs - matching Investment screen style
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: _buildFilterTabs(isDark),
            ),
          ),

          // Content - use appropriate provider based on filter
          _buildGoalsContent(
            isDark: isDark,
            activeGoalsAsync: activeGoalsAsync,
            archivedGoalsAsync: archivedGoalsAsync,
          ),
        ],
      ),
      floatingActionButton: _buildFab(activeGoalsAsync),
    );
  }

  Widget _buildGoalsContent({
    required bool isDark,
    required AsyncValue<List<GoalEntity>> activeGoalsAsync,
    required AsyncValue<List<GoalEntity>> archivedGoalsAsync,
  }) {
    // Select the appropriate data source based on filter
    final AsyncValue<List<GoalEntity>> goalsAsync;
    switch (_filter) {
      case GoalsFilter.active:
        goalsAsync = activeGoalsAsync;
      case GoalsFilter.archived:
        goalsAsync = archivedGoalsAsync;
      case GoalsFilter.all:
        // Combine both lists for "all" filter
        goalsAsync = activeGoalsAsync.when(
          data: (active) => archivedGoalsAsync.when(
            data: (archived) => AsyncValue.data([...active, ...archived]),
            loading: () => AsyncValue.data(active),
            error: (e, st) => AsyncValue.data(active),
          ),
          loading: () => const AsyncValue.loading(),
          error: (e, st) => AsyncValue.error(e, st),
        );
    }

    return goalsAsync.when(
      data: (goals) {
        if (goals.isEmpty) {
          if (_filter == GoalsFilter.archived) {
            return SliverFillRemaining(
              hasScrollBody: false,
              child: _buildNoArchivedState(isDark),
            );
          }
          return SliverFillRemaining(
            hasScrollBody: false,
            child: GoalsEmptyState(
              onCreateGoal: () => context.push('/goals/create'),
            ),
          );
        }

        return SliverPadding(
          padding: EdgeInsets.all(AppSpacing.md),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final goal = goals[index];
              return StaggeredFadeIn(
                index: index,
                child: GoalCard(
                  goal: goal,
                  onTap: () => context.push('/goals/${goal.id}'),
                ),
              );
            }, childCount: goals.length),
          ),
        );
      },
      loading: () => const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => SliverFillRemaining(
        hasScrollBody: false,
        child: _buildErrorState(isDark),
      ),
    );
  }

  Widget _buildFilterTabs(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: GoalsFilter.values.map((filter) {
          final isSelected = _filter == filter;
          final label = switch (filter) {
            GoalsFilter.active => 'Active',
            GoalsFilter.archived => 'Archived',
            GoalsFilter.all => 'All',
          };
          final icon = switch (filter) {
            GoalsFilter.active => Icons.flag_rounded,
            GoalsFilter.archived => Icons.archive_rounded,
            GoalsFilter.all => Icons.list_rounded,
          };

          return Padding(
            padding: EdgeInsets.only(right: AppSpacing.sm),
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected
                        ? Colors.white
                        : (isDark
                              ? AppColors.neutral400Dark
                              : AppColors.neutral600Light),
                  ),
                  SizedBox(width: AppSpacing.xs),
                  Text(label),
                ],
              ),
              selected: isSelected,
              onSelected: (_) => setState(() => _filter = filter),
              selectedColor: AppColors.primaryLight,
              backgroundColor: isDark
                  ? AppColors.surfaceDark
                  : AppColors.surfaceLight,
              labelStyle: AppTypography.small.copyWith(
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : AppColors.neutral700Light),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected
                    ? AppColors.primaryLight
                    : (isDark
                          ? AppColors.neutral700Dark
                          : AppColors.neutral300Light),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNoArchivedState(bool isDark) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : AppColors.primaryLight)
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.archive_outlined,
                size: AppSizes.iconDisplay,
                color: isDark
                    ? AppColors.neutral400Dark
                    : AppColors.neutral500Light,
              ),
            ),
            SizedBox(height: AppSpacing.xl),
            Text(
              'No Archived Goals',
              style: AppTypography.h3.copyWith(
                color: isDark ? Colors.white : AppColors.neutral900Light,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Archived goals will appear here',
              style: AppTypography.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.neutral400Dark
                    : AppColors.neutral500Light,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.lg),
            TextButton(
              onPressed: () => setState(() => _filter = GoalsFilter.active),
              child: const Text('View active goals'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.errorLight.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: AppSizes.iconXl,
                color: AppColors.errorLight,
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              'Connection Error',
              style: AppTypography.h3.copyWith(
                color: isDark ? Colors.white : AppColors.neutral900Light,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Failed to load goals. Please try again.',
              style: AppTypography.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.neutral400Dark
                    : AppColors.neutral500Light,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.lg),
            TextButton(
              onPressed: () => ref.invalidate(allGoalsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildFab(AsyncValue<List<dynamic>> allGoalsAsync) {
    return allGoalsAsync.maybeWhen(
      data: (allGoals) {
        // Apply same filter as the list
        final filteredGoals = allGoals.where((goal) {
          switch (_filter) {
            case GoalsFilter.active:
              return !goal.isArchived;
            case GoalsFilter.archived:
              return goal.isArchived;
            case GoalsFilter.all:
              return true;
          }
        }).toList();

        // Hide FAB when empty state is shown or viewing archived goals
        if (filteredGoals.isEmpty || _filter == GoalsFilter.archived) {
          return null;
        }

        return ScaleTransition(
          scale: _fabScale,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: AppSizes.borderRadiusLg,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryLight.withValues(alpha: 0.4),
                  blurRadius: AppSpacing.md,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: FloatingActionButton.extended(
              heroTag: 'goals_add_fab',
              onPressed: () => context.push('/goals/create'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text(
                'Add Goal',
                style: AppTypography.button.copyWith(color: Colors.white),
              ),
            ),
          ),
        );
      },
      orElse: () => null,
    );
  }
}
