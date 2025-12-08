import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/empty_state_widget.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/premium_animations.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_provider.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_investment_screen.dart';
import 'package:inv_tracker/features/investment/presentation/screens/investment_detail_screen.dart';
import 'package:inv_tracker/features/portfolio/presentation/providers/portfolio_provider.dart';

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
    if (_searchQuery.isEmpty) return investments;
    final query = _searchQuery.toLowerCase();
    return investments.where((inv) {
      return inv.name.toLowerCase().contains(query) ||
          (inv.symbol?.toLowerCase().contains(query) ?? false) ||
          inv.type.toLowerCase().contains(query);
    }).toList();
  }

  void _showAddInvestmentSheet() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AddInvestmentScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final portfoliosAsync = ref.watch(allPortfoliosProvider);
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

          // Content
          portfoliosAsync.when(
            data: (portfolios) {
              if (portfolios.isEmpty) {
                return SliverFillRemaining(
                  child: EmptyStateWidget(
                    title: 'No Portfolios',
                    message: 'Create a portfolio to start tracking your investments.',
                    icon: Icons.pie_chart_outline,
                    actionLabel: 'Create Default Portfolio',
                    onAction: () {
                      ref.read(portfolioProvider.notifier).createDefaultPortfolioIfNone();
                    },
                  ),
                );
              }

              final portfolioId = portfolios.first.id;
              final investmentsAsync = ref.watch(investmentsByPortfolioProvider(portfolioId));

              return investmentsAsync.when(
                data: (investments) {
                  final filteredInvestments = _filterInvestments(investments);

                  if (investments.isEmpty) {
                    return SliverFillRemaining(
                      child: _buildEmptyState(isDark),
                    );
                  }

                  if (filteredInvestments.isEmpty && _searchQuery.isNotEmpty) {
                    return SliverFillRemaining(
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
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, stack) => SliverFillRemaining(
                  child: Center(child: Text('Error: $err')),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, stack) => SliverFillRemaining(
              child: Center(child: Text('Error loading portfolios: $err')),
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

  Widget _buildInvestmentCard(InvestmentEntity investment, bool isDark) {
    // Get a color based on investment type
    final typeColor = _getTypeColor(investment.type);

    return Padding(
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
                  // Icon with gradient background
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [typeColor, typeColor.withValues(alpha: 0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: typeColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        investment.symbol?.substring(0, 1).toUpperCase() ??
                            investment.name.substring(0, 1).toUpperCase(),
                        style: AppTypography.h3.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
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
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                investment.type,
                                style: AppTypography.small.copyWith(
                                  color: typeColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (investment.symbol != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                investment.symbol!,
                                style: AppTypography.small.copyWith(
                                  color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Value and P/L
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
                    'Added ${_formatDate(investment.createdAt)}',
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
    );
  }

  Widget _buildValueColumn(String investmentId, bool isDark) {
    final statsAsync = ref.watch(investmentStatsProvider(investmentId));
    final currencyFormat = ref.watch(currencyFormatProvider);

    return statsAsync.when(
      data: (stats) {
        if (stats == null || stats.quantity <= 0) {
          return Icon(
            Icons.chevron_right_rounded,
            color: isDark ? AppColors.neutral400Dark : AppColors.neutral400Light,
          );
        }

        final isPositive = stats.profitLoss >= 0;
        final plColor = isPositive ? AppColors.graphEmerald : AppColors.errorLight;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              currencyFormat.format(stats.currentValue),
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.neutral900Light,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPositive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  color: plColor,
                  size: 18,
                ),
                Text(
                  '${stats.profitLossPercent.abs().toStringAsFixed(1)}%',
                  style: AppTypography.small.copyWith(
                    color: plColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'stock':
        return AppColors.graphBlue;
      case 'crypto':
        return AppColors.graphPurple;
      case 'mutual fund':
        return AppColors.graphEmerald;
      case 'etf':
        return AppColors.graphCyan;
      case 'bond':
        return AppColors.graphAmber;
      case 'real estate':
        return AppColors.graphPink;
      default:
        return AppColors.graphOrange;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'today';
    } else if (diff.inDays == 1) {
      return 'yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return DateFormat('MMM d, y').format(date);
    }
  }
}
