import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_sizes.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/widgets/loading_skeletons.dart';
import 'package:inv_tracker/core/widgets/premium_animations.dart';
import 'package:inv_tracker/core/widgets/swipe_actions.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_investment_screen.dart';
import 'package:inv_tracker/features/investment/presentation/screens/investment_detail_screen.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_card.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_list_action_bar.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_list_enums.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_list_filter_tabs.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_list_search_field.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_list_selection_controls.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_list_states.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/sort_options_sheet.dart';

/// Main investment list screen with search, filter, sort, and multi-select capabilities.
/// State is managed via [investmentListStateProvider] and [filteredInvestmentsProvider].
class InvestmentListScreen extends ConsumerStatefulWidget {
  const InvestmentListScreen({super.key});

  @override
  ConsumerState<InvestmentListScreen> createState() =>
      _InvestmentListScreenState();
}

class _InvestmentListScreenState extends ConsumerState<InvestmentListScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fabController;
  late Animation<double> _fabScale;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fabScale = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _fabController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  void _showAddInvestmentSheet() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AddInvestmentScreen()),
    );
  }

  void _showSortOptions(bool isDark) {
    final currentSort = ref.read(investmentListStateProvider).sort;
    showSortOptionsSheet(
      context: context,
      isDark: isDark,
      currentSort: currentSort,
      onSortChanged: (newSort) {
        ref.read(investmentListStateProvider.notifier).setSort(newSort);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final listState = ref.watch(investmentListStateProvider);
    final filteredAsync = ref.watch(filteredInvestmentsProvider);
    final allInvestmentsAsync = ref.watch(allInvestmentsProvider);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      body: CustomScrollView(
        slivers: [
          // Premium App Bar with Search
          SliverAppBar(
            expandedHeight: listState.isSearching ? 60 : 56,
            floating: true,
            pinned: true,
            backgroundColor: isDark
                ? AppColors.surfaceDark
                : AppColors.surfaceLight,
            titleSpacing: AppSpacing.md,
            title: listState.isSearching
                ? const InvestmentListSearchField()
                : Text(
                    'Investments',
                    style: AppTypography.h2.copyWith(
                      color: isDark ? Colors.white : AppColors.neutral900Light,
                      fontSize: 22,
                    ),
                  ),
            actions: listState.isSearching
                ? null
                : _buildAppBarActions(isDark, listState),
          ),

          // Filter Tabs or Selection Controls
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: listState.isSelectionMode
                  ? const InvestmentListSelectionControls()
                  : const InvestmentListFilterTabs(),
            ),
          ),

          // Content
          _buildContent(isDark, listState, filteredAsync, allInvestmentsAsync),
        ],
      ),
      floatingActionButton: listState.isSelectionMode
          ? null
          : ScaleTransition(
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
                  heroTag: 'investment_list_add_fab',
                  onPressed: _showAddInvestmentSheet,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  label: Text(
                    'Add Investment',
                    style: AppTypography.button.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
      bottomNavigationBar: listState.isSelectionMode
          ? const InvestmentListActionBar()
          : null,
    );
  }

  List<Widget> _buildAppBarActions(bool isDark, InvestmentListState listState) {
    return [
      // Selection mode toggle
      IconButton(
        icon: Container(
          padding: EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: listState.isSelectionMode
                ? AppColors.primaryLight
                : (isDark ? Colors.white : AppColors.primaryLight).withValues(
                    alpha: 0.1,
                  ),
            borderRadius: AppSizes.borderRadiusMd,
          ),
          child: Icon(
            listState.isSelectionMode
                ? Icons.close_rounded
                : Icons.checklist_rounded,
            color: listState.isSelectionMode
                ? Colors.white
                : (isDark ? Colors.white : AppColors.neutral700Light),
            size: 20,
          ),
        ),
        onPressed: () {
          HapticFeedback.selectionClick();
          ref.read(investmentListStateProvider.notifier).toggleSelectionMode();
        },
      ),
      // Sort button
      IconButton(
        icon: Container(
          padding: EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: listState.sort != InvestmentSort.lastActivity
                ? AppColors.primaryLight
                : (isDark ? Colors.white : AppColors.primaryLight).withValues(
                    alpha: 0.1,
                  ),
            borderRadius: AppSizes.borderRadiusMd,
          ),
          child: Icon(
            Icons.sort_rounded,
            color: listState.sort != InvestmentSort.lastActivity
                ? Colors.white
                : (isDark ? Colors.white : AppColors.neutral700Light),
            size: 20,
          ),
        ),
        onPressed: () => _showSortOptions(isDark),
      ),
      IconButton(
        icon: Container(
          padding: EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : AppColors.primaryLight).withValues(
              alpha: 0.1,
            ),
            borderRadius: AppSizes.borderRadiusMd,
          ),
          child: Icon(
            Icons.search_rounded,
            color: isDark ? Colors.white : AppColors.neutral700Light,
            size: 20,
          ),
        ),
        onPressed: () {
          HapticFeedback.selectionClick();
          ref.read(investmentListStateProvider.notifier).toggleSearch();
        },
      ),
      SizedBox(width: AppSpacing.xs),
    ];
  }

  Widget _buildContent(
    bool isDark,
    InvestmentListState listState,
    AsyncValue<List<InvestmentEntity>> filteredAsync,
    AsyncValue<List<InvestmentEntity>> allInvestmentsAsync,
  ) {
    // Get counts to check if there are ANY investments (active or archived)
    final counts = ref.watch(investmentCountsProvider);
    final hasAnyInvestments =
        counts.all > 0 || counts.archived > 0;

    return filteredAsync.when(
      data: (filteredInvestments) {
        // Only show "Add First Investment" empty state if there are NO investments at all
        // (neither active nor archived)
        if (!hasAnyInvestments) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: InvestmentEmptyState(
              isDark: isDark,
              onAddInvestment: _showAddInvestmentSheet,
            ),
          );
        }

        // Show "no results" state when the current filter has no matching investments
        if (filteredInvestments.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: InvestmentNoResultsState(
              isDark: isDark,
              isSearching: listState.searchQuery.isNotEmpty,
              isArchivedFilter: listState.filter == InvestmentFilter.archived,
            ),
          );
        }

        return SliverPadding(
          padding: EdgeInsets.all(AppSpacing.md),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final investment = filteredInvestments[index];
              final isArchived = investment.isArchived;
              return StaggeredFadeIn(
                index: index,
                child: SwipeActions(
                  itemKey: investment.id,
                  enabled: !listState.isSelectionMode,
                  deleteConfig: DeleteActionConfig(
                    confirmTitle: 'Delete Investment?',
                    confirmMessage:
                        'This will permanently delete "${investment.name}" and all its transactions.',
                    successMessage: 'Investment deleted',
                    onDelete: () {
                      if (isArchived) {
                        ref
                            .read(investmentNotifierProvider.notifier)
                            .deleteArchivedInvestment(investment.id);
                      } else {
                        ref
                            .read(investmentNotifierProvider.notifier)
                            .deleteInvestment(investment.id);
                      }
                    },
                  ),
                  archiveConfig: ArchiveActionConfig(
                    confirmTitle: isArchived
                        ? 'Unarchive Investment?'
                        : 'Archive Investment?',
                    confirmMessage: isArchived
                        ? '"${investment.name}" will be restored to your active investments.'
                        : '"${investment.name}" will be hidden from your active investments.',
                    successMessage: isArchived
                        ? 'Investment restored'
                        : 'Investment archived',
                    isArchived: isArchived,
                    onArchive: () {
                      if (isArchived) {
                        ref
                            .read(investmentNotifierProvider.notifier)
                            .unarchiveInvestment(investment.id);
                      } else {
                        ref
                            .read(investmentNotifierProvider.notifier)
                            .archiveInvestment(investment.id);
                      }
                    },
                  ),
                  child: InvestmentCard(
                    investment: investment,
                    isSelectionMode: listState.isSelectionMode,
                    isSelected: listState.selectedIds.contains(investment.id),
                    onTap: listState.isSelectionMode
                        ? () => ref
                              .read(investmentListStateProvider.notifier)
                              .toggleSelection(investment.id)
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => InvestmentDetailScreen(
                                  investment: investment,
                                ),
                              ),
                            );
                          },
                    onLongPress: !listState.isSelectionMode
                        ? () {
                            ref
                                .read(investmentListStateProvider.notifier)
                                .toggleSelectionMode();
                            ref
                                .read(investmentListStateProvider.notifier)
                                .toggleSelection(investment.id);
                          }
                        : null,
                    onCheckboxChanged: (_) => ref
                        .read(investmentListStateProvider.notifier)
                        .toggleSelection(investment.id),
                  ),
                ),
              );
            }, childCount: filteredInvestments.length),
          ),
        );
      },
      loading: () => const InvestmentListSkeleton(),
      error: (err, stack) => SliverFillRemaining(
        hasScrollBody: false,
        child: InvestmentErrorState(
          isDark: isDark,
          onRetry: () => ref.invalidate(allInvestmentsProvider),
        ),
      ),
    );
  }
}
