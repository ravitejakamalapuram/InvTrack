import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:inv_tracker/core/theme/app_colors.dart';
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
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

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

    return filtered;
  }

  void _showAddInvestmentSheet() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AddInvestmentScreen()),
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
            expandedHeight: _isSearching ? 80 : 120,
            floating: true,
            pinned: true,
            backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16, right: 60),
              title: _isSearching
                  ? _buildSearchField(isDark)
                  : Text(
                      'Investments',
                      style: AppTypography.h2.copyWith(
                        color: isDark ? Colors.white : AppColors.neutral900Light,
                        fontSize: 24,
                      ),
                    ),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : AppColors.primaryLight).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isSearching ? Icons.close_rounded : Icons.search_rounded,
                    color: isDark ? Colors.white : AppColors.neutral700Light,
                  ),
                ),
                onPressed: _toggleSearch,
              ),
              const SizedBox(width: 8),
            ],
          ),

          // Filter Tabs
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _buildFilterTabs(isDark),
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
                padding: const EdgeInsets.all(16),
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
      floatingActionButton: ScaleTransition(
        scale: _fabScale,
        child: Container(
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryLight.withValues(alpha: 0.4),
                blurRadius: 16,
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
    );
  }

  Widget _buildSearchField(bool isDark) {
    return SizedBox(
      height: 36,
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: AppTypography.body.copyWith(
          color: isDark ? Colors.white : AppColors.neutral900Light,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: 'Search investments...',
          hintStyle: AppTypography.body.copyWith(
            color: isDark ? AppColors.neutral500Dark : AppColors.neutral500Light,
            fontSize: 16,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value);
        },
      ),
    );
  }

  Widget _buildNoResultsState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : AppColors.primaryLight).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 64,
                color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Results Found',
              style: AppTypography.h3.copyWith(
                color: isDark ? Colors.white : AppColors.neutral900Light,
              ),
            ),
            const SizedBox(height: 8),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
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
                size: 64,
                color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Investments Yet',
              style: AppTypography.h3.copyWith(
                color: isDark ? Colors.white : AppColors.neutral900Light,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start building your portfolio by adding your first investment',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryLight.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _showAddInvestmentSheet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.errorLight.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: AppColors.errorLight,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Connection Error',
              style: AppTypography.h3.copyWith(
                color: isDark ? Colors.white : AppColors.neutral900Light,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Unable to load investments.\nPlease check your connection and try again.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
              ),
            ),
            const SizedBox(height: 24),
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

  Widget _buildFilterTabs(bool isDark) {
    return Row(
      children: [
        _buildFilterChip('All', InvestmentFilter.all, isDark),
        const SizedBox(width: 8),
        _buildFilterChip('Open', InvestmentFilter.open, isDark),
        const SizedBox(width: 8),
        _buildFilterChip('Closed', InvestmentFilter.closed, isDark),
      ],
    );
  }

  Widget _buildFilterChip(String label, InvestmentFilter filter, bool isDark) {
    final isSelected = _filter == filter;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _filter = filter);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryLight
              : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: AppTypography.small.copyWith(
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : AppColors.neutral700Light),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
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

    return Semantics(
      label: semanticLabel,
      button: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GlassCard(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => InvestmentDetailScreen(investment: investment),
              ),
            );
          },
          padding: EdgeInsets.zero,
          child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icon with type icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isClosed
                            ? [Colors.grey, Colors.grey.withValues(alpha: 0.7)]
                            : [typeColor, typeColor.withValues(alpha: 0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: (isClosed ? Colors.grey : typeColor).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        investment.type.icon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Name and type
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                investment.name,
                                style: AppTypography.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : AppColors.neutral900Light,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isClosed)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'CLOSED',
                                  style: AppTypography.small.copyWith(
                                    color: Colors.grey,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                      ],
                    ),
                  ),
                  // Stats
                  _buildValueColumn(investment.id, isDark),
                ],
              ),
            ),
            // Bottom info strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
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
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildValueColumn(String investmentId, bool isDark) {
    final statsAsync = ref.watch(investmentStatsProvider(investmentId));
    final currencySymbol = ref.watch(currencySymbolProvider);

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
              '${isPositive ? '+' : ''}$currencySymbol${stats.netCashFlow.toStringAsFixed(0)}',
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: plColor,
              ),
            ),
            const SizedBox(height: 4),
            // XIRR
            if (stats.xirr != 0 && !stats.xirr.isNaN && !stats.xirr.isInfinite)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
      loading: () => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => Icon(
        Icons.chevron_right_rounded,
        color: isDark ? AppColors.neutral400Dark : AppColors.neutral400Light,
      ),
    );
  }
}
