import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_sizes.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/accessibility_utils.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/utils/date_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/loading_skeletons.dart';
import 'package:inv_tracker/core/widgets/premium_animations.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_provider.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_investment_screen.dart';
import 'package:inv_tracker/features/investment/presentation/screens/investment_detail_screen.dart';

/// Filter state for investment list
enum InvestmentFilter { all, open, closed }

/// Sort options for investment list
enum InvestmentSort {
  lastActivity('Last Activity', Icons.schedule),
  nameAsc('Name (A-Z)', Icons.sort_by_alpha),
  nameDesc('Name (Z-A)', Icons.sort_by_alpha),
  totalInvestedDesc('Total Invested (High)', Icons.payments),
  totalInvestedAsc('Total Invested (Low)', Icons.payments_outlined),
  totalReturnsDesc('Total Returns (High)', Icons.savings),
  totalReturnsAsc('Total Returns (Low)', Icons.savings_outlined),
  returnPercentDesc('Return % (High)', Icons.percent),
  returnPercentAsc('Return % (Low)', Icons.percent),
  xirrDesc('XIRR (High)', Icons.show_chart),
  xirrAsc('XIRR (Low)', Icons.show_chart),
  netPositionDesc('Net Position (High)', Icons.trending_up),
  netPositionAsc('Net Position (Low)', Icons.trending_down),
  createdDesc('Date Created (Newest)', Icons.calendar_today),
  createdAsc('Date Created (Oldest)', Icons.calendar_today);

  final String displayName;
  final IconData icon;
  const InvestmentSort(this.displayName, this.icon);
}

class InvestmentListScreen extends ConsumerStatefulWidget {
  const InvestmentListScreen({super.key});

  @override
  ConsumerState<InvestmentListScreen> createState() => _InvestmentListScreenState();
}

class _InvestmentListScreenState extends ConsumerState<InvestmentListScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fabController;
  late Animation<double> _fabScale;

  bool _isSearching = false;
  String _searchQuery = '';
  InvestmentFilter _filter = InvestmentFilter.all;
  InvestmentSort _sort = InvestmentSort.lastActivity;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  // Multi-select state
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fabScale = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _fabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    HapticFeedback.selectionClick();
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchQuery = '';
        _searchController.clear();
      } else {
        _searchFocusNode.requestFocus();
      }
    });
  }

  List<InvestmentEntity> _filterInvestments(List<InvestmentEntity> investments) {
    var filtered = investments;

    // Apply status filter
    if (_filter == InvestmentFilter.open) {
      filtered = filtered.where((inv) => inv.status == InvestmentStatus.open).toList();
    } else if (_filter == InvestmentFilter.closed) {
      filtered = filtered.where((inv) => inv.status == InvestmentStatus.closed).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((inv) {
        return inv.name.toLowerCase().contains(query) ||
            inv.type.displayName.toLowerCase().contains(query);
      }).toList();
    }

    // Apply sorting based on selected sort option
    filtered.sort((a, b) {
      final statsA = ref.read(investmentStatsProvider(a.id));
      final statsB = ref.read(investmentStatsProvider(b.id));

      int comparison;
      switch (_sort) {
        case InvestmentSort.lastActivity:
          final dateA = statsA.valueOrNull?.lastCashFlowDate ?? a.updatedAt;
          final dateB = statsB.valueOrNull?.lastCashFlowDate ?? b.updatedAt;
          comparison = dateB.compareTo(dateA); // Descending
          if (comparison == 0) {
            comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          }
        case InvestmentSort.nameAsc:
          comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case InvestmentSort.nameDesc:
          comparison = b.name.toLowerCase().compareTo(a.name.toLowerCase());
        case InvestmentSort.totalInvestedDesc:
          final investedA = statsA.valueOrNull?.totalInvested ?? 0;
          final investedB = statsB.valueOrNull?.totalInvested ?? 0;
          comparison = investedB.compareTo(investedA);
          if (comparison == 0) {
            comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          }
        case InvestmentSort.totalInvestedAsc:
          final investedA = statsA.valueOrNull?.totalInvested ?? 0;
          final investedB = statsB.valueOrNull?.totalInvested ?? 0;
          comparison = investedA.compareTo(investedB);
          if (comparison == 0) {
            comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          }
        case InvestmentSort.totalReturnsDesc:
          final returnsA = statsA.valueOrNull?.totalReturned ?? 0;
          final returnsB = statsB.valueOrNull?.totalReturned ?? 0;
          comparison = returnsB.compareTo(returnsA);
          if (comparison == 0) {
            comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          }
        case InvestmentSort.totalReturnsAsc:
          final returnsA = statsA.valueOrNull?.totalReturned ?? 0;
          final returnsB = statsB.valueOrNull?.totalReturned ?? 0;
          comparison = returnsA.compareTo(returnsB);
          if (comparison == 0) {
            comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          }
        case InvestmentSort.returnPercentDesc:
          final returnA = statsA.valueOrNull?.absoluteReturn ?? 0;
          final returnB = statsB.valueOrNull?.absoluteReturn ?? 0;
          comparison = returnB.compareTo(returnA);
          if (comparison == 0) {
            comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          }
        case InvestmentSort.returnPercentAsc:
          final returnA = statsA.valueOrNull?.absoluteReturn ?? 0;
          final returnB = statsB.valueOrNull?.absoluteReturn ?? 0;
          comparison = returnA.compareTo(returnB);
          if (comparison == 0) {
            comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          }
        case InvestmentSort.xirrDesc:
          final xirrA = statsA.valueOrNull?.xirr ?? 0;
          final xirrB = statsB.valueOrNull?.xirr ?? 0;
          comparison = xirrB.compareTo(xirrA);
          if (comparison == 0) {
            comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          }
        case InvestmentSort.xirrAsc:
          final xirrA = statsA.valueOrNull?.xirr ?? 0;
          final xirrB = statsB.valueOrNull?.xirr ?? 0;
          comparison = xirrA.compareTo(xirrB);
          if (comparison == 0) {
            comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          }
        case InvestmentSort.netPositionDesc:
          final netA = statsA.valueOrNull?.netCashFlow ?? 0;
          final netB = statsB.valueOrNull?.netCashFlow ?? 0;
          comparison = netB.compareTo(netA);
          if (comparison == 0) {
            comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          }
        case InvestmentSort.netPositionAsc:
          final netA = statsA.valueOrNull?.netCashFlow ?? 0;
          final netB = statsB.valueOrNull?.netCashFlow ?? 0;
          comparison = netA.compareTo(netB);
          if (comparison == 0) {
            comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          }
        case InvestmentSort.createdDesc:
          comparison = b.createdAt.compareTo(a.createdAt);
          if (comparison == 0) {
            comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          }
        case InvestmentSort.createdAsc:
          comparison = a.createdAt.compareTo(b.createdAt);
          if (comparison == 0) {
            comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          }
      }
      return comparison;
    });

    return filtered;
  }

  void _showAddInvestmentSheet() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AddInvestmentScreen()),
    );
  }

  void _toggleSelectionMode() {
    HapticFeedback.selectionClick();
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedIds.clear();
      }
    });
  }

  void _toggleSelection(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      // Exit selection mode if nothing selected
      if (_selectedIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _selectAll(List<InvestmentEntity> investments) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedIds.addAll(investments.map((i) => i.id));
    });
  }

  void _showSortOptions(bool isDark) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildSortOptionsSheet(isDark),
    );
  }

  Widget _buildSortOptionsSheet(bool isDark) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: AppSpacing.sm),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Icon(
                  Icons.sort_rounded,
                  color: isDark ? Colors.white : AppColors.neutral700Light,
                ),
                SizedBox(width: AppSpacing.sm),
                Text(
                  'Sort By',
                  style: AppTypography.h3.copyWith(
                    color: isDark ? Colors.white : AppColors.neutral900Light,
                  ),
                ),
                const Spacer(),
                if (_sort != InvestmentSort.lastActivity)
                  TextButton(
                    onPressed: () {
                      setState(() => _sort = InvestmentSort.lastActivity);
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Reset',
                      style: AppTypography.small.copyWith(
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1)),
          // Sort options
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: InvestmentSort.values.map((sortOption) {
                  final isSelected = _sort == sortOption;
                  final isDefault = sortOption == InvestmentSort.lastActivity;
                  return ListTile(
                    leading: Icon(
                      sortOption.icon,
                      color: isSelected
                          ? AppColors.primaryLight
                          : (isDark ? Colors.white70 : AppColors.neutral600Light),
                    ),
                    title: Row(
                      children: [
                        Text(
                          sortOption.displayName,
                          style: AppTypography.body.copyWith(
                            color: isSelected
                                ? AppColors.primaryLight
                                : (isDark ? Colors.white : AppColors.neutral800Light),
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        if (isDefault) ...[
                          SizedBox(width: AppSpacing.xs),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : AppColors.primaryLight)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Default',
                              style: AppTypography.caption.copyWith(
                                color: isDark ? Colors.white70 : AppColors.neutral600Light,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_rounded, color: AppColors.primaryLight)
                        : null,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _sort = sortOption);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            ),
          ),
          SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final investmentsAsync = ref.watch(allInvestmentsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: CustomScrollView(
        slivers: [
          // Premium App Bar with Search
          SliverAppBar(
            expandedHeight: _isSearching ? 60 : 56,
            floating: true,
            pinned: true,
            backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            titleSpacing: AppSpacing.md,
            title: _isSearching
                ? _buildSearchField(isDark)
                : Text(
                    'Investments',
                    style: AppTypography.h2.copyWith(
                      color: isDark ? Colors.white : AppColors.neutral900Light,
                      fontSize: 22,
                    ),
                  ),
            actions: _isSearching
                ? null
                : [
                    // Selection mode toggle
                    IconButton(
                      icon: Container(
                        padding: EdgeInsets.all(AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: _isSelectionMode
                              ? AppColors.primaryLight
                              : (isDark ? Colors.white : AppColors.primaryLight).withValues(alpha: 0.1),
                          borderRadius: AppSizes.borderRadiusMd,
                        ),
                        child: Icon(
                          _isSelectionMode ? Icons.close_rounded : Icons.checklist_rounded,
                          color: _isSelectionMode ? Colors.white : (isDark ? Colors.white : AppColors.neutral700Light),
                          size: 20,
                        ),
                      ),
                      onPressed: _toggleSelectionMode,
                    ),
                    // Sort button
                    IconButton(
                      icon: Container(
                        padding: EdgeInsets.all(AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: _sort != InvestmentSort.lastActivity
                              ? AppColors.primaryLight
                              : (isDark ? Colors.white : AppColors.primaryLight).withValues(alpha: 0.1),
                          borderRadius: AppSizes.borderRadiusMd,
                        ),
                        child: Icon(
                          Icons.sort_rounded,
                          color: _sort != InvestmentSort.lastActivity
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
                          color: (isDark ? Colors.white : AppColors.primaryLight)
                              .withValues(alpha: 0.1),
                          borderRadius: AppSizes.borderRadiusMd,
                        ),
                        child: Icon(
                          Icons.search_rounded,
                          color: isDark ? Colors.white : AppColors.neutral700Light,
                          size: 20,
                        ),
                      ),
                      onPressed: _toggleSearch,
                    ),
                    SizedBox(width: AppSpacing.xs),
                  ],
          ),

          // Filter Tabs or Selection Controls
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              child: _isSelectionMode
                  ? _buildSelectionControls(isDark, investmentsAsync.valueOrNull ?? [])
                  : _buildFilterTabs(isDark, investmentsAsync.valueOrNull ?? []),
            ),
          ),

          // Content
          investmentsAsync.when(
            data: (investments) {
              final filteredInvestments = _filterInvestments(investments);

              if (investments.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(isDark),
                );
              }

              if (filteredInvestments.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildNoResultsState(isDark),
                );
              }

              return SliverPadding(
                padding: EdgeInsets.all(AppSpacing.md),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return StaggeredFadeIn(
                        index: index,
                        child: _buildInvestmentCard(filteredInvestments[index], isDark),
                      );
                    },
                    childCount: filteredInvestments.length,
                  ),
                ),
              );
            },
            loading: () => const InvestmentListSkeleton(),
            error: (err, stack) => SliverFillRemaining(
              hasScrollBody: false,
              child: _buildErrorState(isDark, err.toString()),
            ),
          ),
        ],
      ),
      floatingActionButton: _isSelectionMode
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
      bottomNavigationBar: _isSelectionMode ? _buildSelectionActionBar(isDark) : null,
    );
  }

  Widget _buildSelectionActionBar(bool isDark) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Selection count
            Expanded(
              child: Text(
                '${_selectedIds.length} selected',
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.neutral900Light,
                ),
              ),
            ),
            // Merge button
            if (_selectedIds.length >= 2)
              TextButton.icon(
                onPressed: () => _showMergeDialog(),
                icon: const Icon(Icons.merge_rounded),
                label: const Text('Merge'),
              ),
            SizedBox(width: AppSpacing.sm),
            // Delete button
            TextButton.icon(
              onPressed: _selectedIds.isNotEmpty ? () => _showDeleteConfirmation() : null,
              icon: Icon(Icons.delete_rounded, color: AppColors.errorLight),
              label: Text('Delete', style: TextStyle(color: AppColors.errorLight)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Investments'),
        content: Text('Are you sure you want to delete ${_selectedIds.length} investment(s)? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorLight),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteSelectedInvestments();
    }
  }

  Future<void> _deleteSelectedInvestments() async {
    final notifier = ref.read(investmentNotifierProvider.notifier);
    for (final id in _selectedIds) {
      await notifier.deleteInvestment(id);
    }
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Investments deleted')),
      );
    }
  }

  Future<void> _showMergeDialog() async {
    // Get the investments being merged to determine default type
    final allInvestments = ref.read(allInvestmentsProvider).valueOrNull ?? [];
    final toMerge = allInvestments.where((i) => _selectedIds.contains(i.id)).toList();

    // Find the most common type as default
    final typeCount = <InvestmentType, int>{};
    for (final inv in toMerge) {
      typeCount[inv.type] = (typeCount[inv.type] ?? 0) + 1;
    }
    final defaultType = typeCount.isNotEmpty
        ? typeCount.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : InvestmentType.other;

    final result = await showDialog<({String name, InvestmentType type})?>(
      context: context,
      builder: (context) => _MergeInvestmentsDialog(
        selectedCount: _selectedIds.length,
        defaultType: defaultType,
        investmentTypes: toMerge.map((i) => i.type).toSet().toList(),
      ),
    );

    if (result != null && result.name.isNotEmpty) {
      await _mergeSelectedInvestments(result.name, result.type);
    }
  }

  Future<void> _mergeSelectedInvestments(String newName, InvestmentType type) async {
    final notifier = ref.read(investmentNotifierProvider.notifier);
    await notifier.mergeInvestments(_selectedIds.toList(), newName, type: type);
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Investments merged into "$newName"')),
      );
    }
  }

  Widget _buildSearchField(bool isDark) {
    return Row(
      children: [
        // Search icon
        Icon(
          Icons.search_rounded,
          size: 20,
          color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
        ),
        SizedBox(width: AppSpacing.sm),
        // Text field
        Expanded(
          child: Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: const InputDecorationTheme(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              cursorColor: isDark ? Colors.white70 : AppColors.primaryLight,
              style: AppTypography.body.copyWith(
                color: isDark ? Colors.white : AppColors.neutral900Light,
                fontSize: 16,
                height: 1.2,
              ),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: AppTypography.body.copyWith(
                  color: isDark ? AppColors.neutral500Dark : AppColors.neutral500Light,
                  fontSize: 16,
                  height: 1.2,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
        ),
        // Close button
        GestureDetector(
          onTap: _toggleSearch,
          child: Icon(
            Icons.close_rounded,
            size: 20,
            color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
          ),
        ),
      ],
    );
  }

  Widget _buildNoResultsState(bool isDark) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : AppColors.primaryLight).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: AppSizes.iconDisplay,
                color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
              ),
            ),
            SizedBox(height: AppSpacing.xl),
            Text(
              'No Results Found',
              style: AppTypography.h3.copyWith(
                color: isDark ? Colors.white : AppColors.neutral900Light,
              ),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              'Try searching with a different term',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryLight.withValues(alpha: 0.1),
                    AppColors.accentLight.withValues(alpha: 0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.show_chart_rounded,
                size: AppSizes.iconDisplay,
                color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
              ),
            ),
            SizedBox(height: AppSpacing.xl),
            Text(
              'No Investments Yet',
              style: AppTypography.h3.copyWith(
                color: isDark ? Colors.white : AppColors.neutral900Light,
              ),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              'Start building your portfolio by adding your first investment',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
              ),
            ),
            SizedBox(height: AppSpacing.xxl),
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: AppSizes.borderRadiusLg,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryLight.withValues(alpha: 0.3),
                    blurRadius: AppSpacing.md,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _showAddInvestmentSheet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.md),
                ),
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: Text(
                  'Add First Investment',
                  style: AppTypography.button.copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isDark, String error) {
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
            SizedBox(height: AppSpacing.xs),
            Text(
              'Unable to load investments.\nPlease check your connection and try again.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
              ),
            ),
            SizedBox(height: AppSpacing.xl),
            TextButton.icon(
              onPressed: () => ref.invalidate(allInvestmentsProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabs(bool isDark, List<InvestmentEntity> investments) {
    final allCount = investments.length;
    final openCount = investments.where((i) => i.status == InvestmentStatus.open).length;
    final closedCount = investments.where((i) => i.status == InvestmentStatus.closed).length;

    return Row(
      children: [
        _buildFilterChip('All', allCount, InvestmentFilter.all, isDark),
        SizedBox(width: AppSpacing.xs),
        _buildFilterChip('Open', openCount, InvestmentFilter.open, isDark),
        SizedBox(width: AppSpacing.xs),
        _buildFilterChip('Closed', closedCount, InvestmentFilter.closed, isDark),
      ],
    );
  }

  Widget _buildFilterChip(String label, int count, InvestmentFilter filter, bool isDark) {
    final isSelected = _filter == filter;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _filter = filter);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryLight
              : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.small.copyWith(
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : AppColors.neutral700Light),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (count > 0) ...[
              SizedBox(width: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.2)
                      : (isDark ? Colors.white : AppColors.primaryLight).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: AppTypography.small.copyWith(
                    fontSize: 10,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : AppColors.primaryLight),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionControls(bool isDark, List<InvestmentEntity> investments) {
    final filteredInvestments = _filterInvestments(investments);
    final allSelected = filteredInvestments.isNotEmpty &&
        filteredInvestments.every((i) => _selectedIds.contains(i.id));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            if (allSelected) {
              setState(() => _selectedIds.clear());
            } else {
              _selectAll(filteredInvestments);
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: allSelected
                  ? AppColors.primaryLight
                  : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppSizes.radiusXl),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  allSelected ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 18,
                  color: allSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : AppColors.neutral700Light),
                ),
                SizedBox(width: AppSpacing.xs),
                Text(
                  allSelected ? 'Deselect All' : 'Select All',
                  style: AppTypography.small.copyWith(
                    color: allSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : AppColors.neutral700Light),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        Container(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : AppColors.primaryLight).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSizes.radiusXl),
          ),
          child: Text(
            '${_selectedIds.length} of ${filteredInvestments.length}',
            style: AppTypography.small.copyWith(
              color: isDark ? Colors.white70 : AppColors.neutral600Light,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInvestmentCard(InvestmentEntity investment, bool isDark) {
    final typeColor = investment.type.color;
    final isClosed = investment.status == InvestmentStatus.closed;
    final currencySymbol = ref.watch(currencySymbolProvider);
    final statsAsync = ref.watch(investmentStatsProvider(investment.id));

    // Build accessibility label
    final semanticLabel = statsAsync.maybeWhen(
      data: (stats) => AccessibilityUtils.investmentCardLabel(
        name: investment.name,
        type: investment.type.displayName,
        currentValue: stats.netCashFlow,
        returnPercent: stats.hasData ? stats.xirr * 100 : null,
        currencySymbol: currencySymbol,
        isClosed: isClosed,
      ),
      orElse: () => '${isClosed ? "Closed" : "Open"} investment: ${investment.name}, Type: ${investment.type.displayName}',
    );

    final isSelected = _selectedIds.contains(investment.id);

    return Semantics(
      label: semanticLabel,
      button: true,
      child: Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.sm),
        child: GlassCard(
          onTap: _isSelectionMode
              ? () => _toggleSelection(investment.id)
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => InvestmentDetailScreen(investment: investment),
                    ),
                  );
                },
          onLongPress: !_isSelectionMode
              ? () {
                  setState(() => _isSelectionMode = true);
                  _toggleSelection(investment.id);
                }
              : null,
          padding: EdgeInsets.zero,
          child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  // Checkbox in selection mode
                  if (_isSelectionMode) ...[
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleSelection(investment.id),
                      activeColor: AppColors.primaryLight,
                    ),
                    SizedBox(width: AppSpacing.xs),
                  ],
                  // Icon with type icon
                  Container(
                    width: AppSizes.iconXl,
                    height: AppSizes.iconXl,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isClosed
                            ? [Colors.grey, Colors.grey.withValues(alpha: 0.7)]
                            : [typeColor, typeColor.withValues(alpha: 0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd + 2),
                      boxShadow: [
                        BoxShadow(
                          color: (isClosed ? Colors.grey : typeColor).withValues(alpha: 0.3),
                          blurRadius: AppSpacing.xs,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        investment.type.icon,
                        color: Colors.white,
                        size: AppSizes.iconMd,
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  // Name and type
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          investment.name,
                          style: AppTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppColors.neutral900Light,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: AppSpacing.xxs),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                investment.type.displayName,
                                style: AppTypography.small.copyWith(
                                  color: typeColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (isClosed)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'CLOSED',
                                  style: AppTypography.small.copyWith(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  // Stats
                  _buildValueColumn(investment.id, isDark),
                ],
              ),
            ),
            // Bottom info strip with stats
            _buildBottomInfoStrip(investment, isDark),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildValueColumn(String investmentId, bool isDark) {
    final statsAsync = ref.watch(investmentStatsProvider(investmentId));
    final currencyFormat = ref.watch(currencyFormatProvider);

    return statsAsync.when(
      data: (stats) {
        if (!stats.hasData) {
          return Icon(
            Icons.chevron_right_rounded,
            color: isDark ? AppColors.neutral400Dark : AppColors.neutral400Light,
          );
        }

        final isPositive = stats.netCashFlow >= 0;
        final plColor = isPositive ? AppColors.graphEmerald : AppColors.errorLight;
        final xirrColor = stats.xirr >= 0 ? AppColors.graphEmerald : AppColors.errorLight;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Net Position (cash in - cash out)
            Text(
              '${isPositive ? '+' : ''}${currencyFormat.format(stats.netCashFlow.abs())}',
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: plColor,
              ),
            ),
            SizedBox(height: AppSpacing.xxs),
            // XIRR
            if (stats.xirr != 0 && !stats.xirr.isNaN && !stats.xirr.isInfinite)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: xirrColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${stats.xirr >= 0 ? '+' : ''}${(stats.xirr * 100).toStringAsFixed(1)}% IRR',
                  style: AppTypography.small.copyWith(
                    color: xirrColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => SizedBox(
        width: AppSpacing.md,
        height: AppSpacing.md,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => Icon(
        Icons.chevron_right_rounded,
        color: isDark ? AppColors.neutral400Dark : AppColors.neutral400Light,
      ),
    );
  }

  Widget _buildBottomInfoStrip(InvestmentEntity investment, bool isDark) {
    final statsAsync = ref.watch(investmentStatsProvider(investment.id));
    final currencyFormat = ref.watch(currencyFormatProvider);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppSizes.radiusXl),
          bottomRight: Radius.circular(AppSizes.radiusXl),
        ),
      ),
      child: statsAsync.when(
        data: (stats) {
          final lastActivityDate = stats.lastCashFlowDate ?? investment.createdAt;
          final cashFlowCount = stats.cashFlowCount;

          return Row(
            children: [
              // Last activity
              Icon(
                Icons.update_rounded,
                size: 12,
                color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
              ),
              SizedBox(width: 4),
              Text(
                AppDateUtils.formatRelative(lastActivityDate),
                style: AppTypography.small.copyWith(
                  color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                ),
              ),
              SizedBox(width: AppSpacing.md),
              // Cash flow count
              Icon(
                Icons.receipt_long_rounded,
                size: 12,
                color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
              ),
              SizedBox(width: 4),
              Text(
                '$cashFlowCount ${cashFlowCount == 1 ? 'entry' : 'entries'}',
                style: AppTypography.small.copyWith(
                  color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                ),
              ),
              Spacer(),
              // Total invested
              if (stats.totalInvested > 0) ...[
                Text(
                  'Invested: ${currencyFormat.format(stats.totalInvested)}',
                  style: AppTypography.small.copyWith(
                    color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ] else ...[
                Text(
                  'View Details',
                  style: AppTypography.small.copyWith(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          );
        },
        loading: () => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Loading...',
              style: AppTypography.small.copyWith(
                color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
              ),
            ),
          ],
        ),
        error: (_, __) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Added ${AppDateUtils.formatRelative(investment.createdAt)}',
              style: AppTypography.small.copyWith(
                color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
              ),
            ),
            Text(
              'View Details',
              style: AppTypography.small.copyWith(
                color: AppColors.primaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



/// Dialog for merging investments with name and type selection
class _MergeInvestmentsDialog extends StatefulWidget {
  final int selectedCount;
  final InvestmentType defaultType;
  final List<InvestmentType> investmentTypes;

  const _MergeInvestmentsDialog({
    required this.selectedCount,
    required this.defaultType,
    required this.investmentTypes,
  });

  @override
  State<_MergeInvestmentsDialog> createState() => _MergeInvestmentsDialogState();
}

class _MergeInvestmentsDialogState extends State<_MergeInvestmentsDialog> {
  final _nameController = TextEditingController();
  late InvestmentType _selectedType;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.defaultType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasMultipleTypes = widget.investmentTypes.length > 1;

    return AlertDialog(
      title: const Text('Merge Investments'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Merge ${widget.selectedCount} investments into one.'),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'New Investment Name',
                hintText: 'Enter name for merged investment',
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            Text(
              'Investment Type',
              style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
            ),
            if (hasMultipleTypes) ...[
              const SizedBox(height: 4),
              Text(
                'Selected investments have different types',
                style: AppTypography.caption.copyWith(
                  color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: InvestmentType.values.map((type) {
                final isSelected = type == _selectedType;
                final isFromSelection = widget.investmentTypes.contains(type);
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedType = type);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? type.color.withValues(alpha: 0.2)
                          : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? type.color : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          type.icon,
                          size: 16,
                          color: isSelected ? type.color : (isDark ? AppColors.neutral400Dark : AppColors.neutral500Light),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          type.displayName,
                          style: AppTypography.caption.copyWith(
                            color: isSelected ? type.color : (isDark ? AppColors.neutral300Dark : AppColors.neutral600Light),
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        if (isFromSelection) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.check_circle,
                            size: 12,
                            color: type.color.withValues(alpha: 0.7),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text(
              'All cash flows will be combined.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_nameController.text.trim().isNotEmpty) {
              Navigator.of(context).pop((name: _nameController.text.trim(), type: _selectedType));
            }
          },
          child: const Text('Merge'),
        ),
      ],
    );
  }
}