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
            expandedHeight: _isSearching ? 100 : 120,
            floating: true,
            pinned: true,
            backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.only(
                left: AppSpacing.lg,
                bottom: AppSpacing.md,
                right: AppSpacing.lg,
              ),
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
            actions: _isSearching
                ? null
                : [
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
                        ),
                      ),
                      onPressed: _toggleSearch,
                    ),
                    SizedBox(width: AppSpacing.xs),
                  ],
          ),

          // Filter Tabs
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
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
      floatingActionButton: ScaleTransition(
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
    );
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

  Widget _buildFilterTabs(bool isDark) {
    return Row(
      children: [
        _buildFilterChip('All', InvestmentFilter.all, isDark),
        SizedBox(width: AppSpacing.xs),
        _buildFilterChip('Open', InvestmentFilter.open, isDark),
        SizedBox(width: AppSpacing.xs),
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
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryLight
              : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
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
        padding: EdgeInsets.only(bottom: AppSpacing.sm),
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
              padding: EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
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
                        Row(
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
                            if (isClosed) ...[
                              SizedBox(width: AppSpacing.xs),
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
            // Bottom info strip
            Container(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(AppSizes.radiusXl),
                  bottomRight: Radius.circular(AppSizes.radiusXl),
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
}
