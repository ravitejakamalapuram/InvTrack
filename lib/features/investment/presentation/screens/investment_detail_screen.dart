import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/premium_animations.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_provider.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_transaction_screen.dart';
import 'package:inv_tracker/features/investment/presentation/screens/edit_investment_screen.dart';

class InvestmentDetailScreen extends ConsumerStatefulWidget {
  final InvestmentEntity investment;

  const InvestmentDetailScreen({super.key, required this.investment});

  @override
  ConsumerState<InvestmentDetailScreen> createState() => _InvestmentDetailScreenState();
}

class _InvestmentDetailScreenState extends ConsumerState<InvestmentDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Color get _typeColor {
    switch (widget.investment.type) {
      case InvestmentType.p2pLending:
        return AppColors.graphBlue;
      case InvestmentType.fixedDeposit:
        return AppColors.graphEmerald;
      case InvestmentType.bonds:
        return AppColors.graphAmber;
      case InvestmentType.realEstate:
        return AppColors.graphPink;
      case InvestmentType.privateEquity:
        return AppColors.graphPurple;
      case InvestmentType.angelInvesting:
        return AppColors.graphCyan;
      case InvestmentType.chitFunds:
        return AppColors.graphOrange;
      case InvestmentType.gold:
        return const Color(0xFFFFD700);
      case InvestmentType.crypto:
        return AppColors.graphPurple;
      case InvestmentType.mutualFunds:
        return AppColors.graphBlue;
      case InvestmentType.stocks:
        return AppColors.graphEmerald;
      case InvestmentType.other:
        return AppColors.neutral500Light;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cashFlowsAsync = ref.watch(cashFlowsByInvestmentProvider(widget.investment.id));
    final statsAsync = ref.watch(investmentStatsProvider(widget.investment.id));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencySymbol = ref.watch(currencySymbolProvider);
    final isClosed = widget.investment.status == InvestmentStatus.closed;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: CustomScrollView(
        slivers: [
          // Hero App Bar
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.more_vert_rounded, color: Colors.white),
                ),
                onPressed: () => _showOptionsSheet(context, isDark),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isClosed
                        ? [Colors.grey, Colors.grey.withValues(alpha: 0.7)]
                        : [_typeColor, _typeColor.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Icon(
                                  widget.investment.type.icon,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          widget.investment.name,
                                          style: AppTypography.h3.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (isClosed)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'CLOSED',
                                            style: AppTypography.small.copyWith(
                                              color: Colors.white,
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
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      widget.investment.type.displayName,
                                      style: AppTypography.small.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Stats Cards
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: statsAsync.when(
                  data: (stats) => _buildStatsSection(stats, isDark, currencySymbol),
                  loading: () => _buildStatsLoading(isDark),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),

          // Cash Flows Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cash Flows',
                    style: AppTypography.h4.copyWith(
                      color: isDark ? Colors.white : AppColors.neutral900Light,
                    ),
                  ),
                  if (!isClosed)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => AddTransactionScreen(investmentId: widget.investment.id),
                          ),
                        );
                      },
                      icon: Icon(Icons.add_rounded, size: 18, color: AppColors.primaryLight),
                      label: Text(
                        'Add',
                        style: AppTypography.body.copyWith(
                          color: AppColors.primaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Cash Flows List
          cashFlowsAsync.when(
            data: (cashFlows) {
              if (cashFlows.isEmpty) {
                return SliverFillRemaining(
                  child: _buildEmptyCashFlows(isDark),
                );
              }
              // Sort by date descending
              final sortedFlows = List<CashFlowEntity>.from(cashFlows)
                ..sort((a, b) => b.date.compareTo(a.date));
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return StaggeredFadeIn(
                        index: index,
                        child: _buildCashFlowCard(sortedFlows[index], isDark, currencySymbol),
                      );
                    },
                    childCount: sortedFlows.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => SliverFillRemaining(
              child: Center(child: Text('Error: $err')),
            ),
          ),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: isClosed ? null : Container(
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
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AddTransactionScreen(investmentId: widget.investment.id),
              ),
            );
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text(
            'Add Cash Flow',
            style: AppTypography.button.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection(InvestmentStats stats, bool isDark, String currencySymbol) {
    final isPositive = stats.netCashFlow >= 0;
    final xirrPercent = stats.xirr * 100;

    return Column(
      children: [
        // First row: Cash Out and Cash In
        Row(
          children: [
            Expanded(
              child: _buildStatCardLarge(
                'Cash Out',
                '$currencySymbol${stats.totalInvested.toStringAsFixed(0)}',
                Icons.arrow_upward_rounded,
                AppColors.errorLight,
                isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCardLarge(
                'Cash In',
                '$currencySymbol${stats.totalReturned.toStringAsFixed(0)}',
                Icons.arrow_downward_rounded,
                AppColors.successLight,
                isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Second row: Net Position with Return %
        Row(
          children: [
            Expanded(
              child: _buildStatCardLarge(
                'Net Position',
                '${isPositive ? '+' : ''}$currencySymbol${stats.netCashFlow.toStringAsFixed(0)}',
                isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                isPositive ? AppColors.successLight : AppColors.errorLight,
                isDark,
                subtitle: '${isPositive ? '+' : ''}${stats.absoluteReturn.toStringAsFixed(1)}% return',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Third row: XIRR and MOIC
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'XIRR',
                '${xirrPercent >= 0 ? '+' : ''}${xirrPercent.toStringAsFixed(1)}%',
                Icons.show_chart_rounded,
                xirrPercent >= 0 ? AppColors.graphCyan : AppColors.errorLight,
                isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'MOIC',
                '${stats.moic.toStringAsFixed(2)}x',
                Icons.multiple_stop_rounded,
                AppColors.graphPurple,
                isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Cash Flows',
                '${stats.cashFlowCount}',
                Icons.receipt_long_rounded,
                AppColors.graphBlue,
                isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCardLarge(String label, String value, IconData icon, Color color, bool isDark, {String? subtitle}) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: AppTypography.small.copyWith(
                  color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTypography.h3.copyWith(
              color: isDark ? Colors.white : AppColors.neutral900Light,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTypography.bodyMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTypography.numberSmall.copyWith(
              color: isDark ? Colors.white : AppColors.neutral900Light,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.small.copyWith(
              color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsLoading(bool isDark) {
    return Row(
      children: List.generate(3, (index) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: index > 0 ? 12 : 0),
            child: GlassCard(
              padding: const EdgeInsets.all(12),
              child: ShimmerEffect(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.neutral700Dark : AppColors.neutral200Light,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 60,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.neutral700Dark : AppColors.neutral200Light,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 40,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.neutral700Dark : AppColors.neutral200Light,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildEmptyCashFlows(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _typeColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                size: 48,
                color: _typeColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Cash Flows Yet',
              style: AppTypography.h4.copyWith(
                color: isDark ? Colors.white : AppColors.neutral900Light,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first cash flow to start tracking',
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

  Widget _buildCashFlowCard(CashFlowEntity cashFlow, bool isDark, String currencySymbol) {
    final isOutflow = cashFlow.type.isOutflow;
    final color = isOutflow ? AppColors.errorLight : AppColors.successLight;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: Key(cashFlow.id),
        direction: DismissDirection.endToStart,
        background: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            gradient: AppColors.dangerGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: const Icon(Icons.delete_rounded, color: Colors.white),
        ),
        confirmDismiss: (direction) => _confirmAndDeleteCashFlow(context, isDark, cashFlow.id),
        child: GlassCard(
          onTap: () {
            // Navigate to edit cash flow
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AddTransactionScreen(
                  investmentId: widget.investment.id,
                  cashFlowToEdit: cashFlow,
                ),
              ),
            );
          },
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isOutflow ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 14),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        cashFlow.type.displayName,
                        style: AppTypography.small.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM d, yyyy').format(cashFlow.date),
                      style: AppTypography.small.copyWith(
                        color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                      ),
                    ),
                    if (cashFlow.notes != null && cashFlow.notes!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        cashFlow.notes!,
                        style: AppTypography.small.copyWith(
                          color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Amount
              Text(
                '${isOutflow ? '-' : '+'}$currencySymbol${cashFlow.amount.toStringAsFixed(0)}',
                style: AppTypography.bodyLarge.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Confirms and deletes a cash flow. Returns true if deleted successfully.
  Future<bool> _confirmAndDeleteCashFlow(BuildContext context, bool isDark, String cashFlowId) async {
    final confirmed = await AppFeedback.showConfirmDialog(
      context: context,
      title: 'Delete Transaction?',
      message: 'This action cannot be undone.',
      confirmText: 'Delete',
    );

    if (!confirmed) return false;

    final success = await ref.read(investmentNotifierProvider.notifier).deleteCashFlow(cashFlowId);

    if (mounted) {
      if (success) {
        AppFeedback.showSuccess(context, 'Transaction deleted');
      } else {
        final errorMessage = ref.read(investmentNotifierProvider).errorMessage ?? 'Failed to delete transaction';
        AppFeedback.showError(context, errorMessage);
      }
    }

    return success;
  }

  Future<void> _confirmDeleteInvestment(BuildContext context, bool isDark) async {
    final confirmed = await AppFeedback.showConfirmDialog(
      context: context,
      title: 'Delete Investment?',
      message: 'This will permanently delete this investment and all its transactions. This action cannot be undone.',
      confirmText: 'Delete',
    );

    if (confirmed && mounted) {
      final navigator = Navigator.of(context);
      final success = await ref.read(investmentNotifierProvider.notifier).deleteInvestment(widget.investment.id);
      if (mounted) {
        if (success) {
          navigator.pop();
          AppFeedback.showSuccess(context, 'Investment deleted');
        } else {
          final errorMessage = ref.read(investmentNotifierProvider).errorMessage ?? 'Failed to delete investment';
          AppFeedback.showError(context, errorMessage);
        }
      }
    }
  }

  void _toggleInvestmentStatus(BuildContext context, bool isDark) async {
    final isClosed = widget.investment.status == InvestmentStatus.closed;

    final confirmed = await AppFeedback.showConfirmDialog(
      context: context,
      title: '${isClosed ? 'Reopen' : 'Close'} Investment?',
      message: isClosed
          ? 'This will reopen the investment and allow adding new transactions.'
          : 'This will mark the investment as closed. You can reopen it later if needed.',
      confirmText: isClosed ? 'Reopen' : 'Close',
      isDestructive: false,
    );

    if (confirmed && mounted) {
      final navigator = Navigator.of(context);
      bool success;
      if (isClosed) {
        success = await ref.read(investmentNotifierProvider.notifier).reopenInvestment(widget.investment.id);
      } else {
        success = await ref.read(investmentNotifierProvider.notifier).closeInvestment(widget.investment.id);
      }
      if (mounted) {
        if (success) {
          navigator.pop();
          AppFeedback.showSuccess(context, 'Investment ${isClosed ? 'reopened' : 'closed'}');
        } else {
          final errorMessage = ref.read(investmentNotifierProvider).errorMessage ?? 'Failed to ${isClosed ? 'reopen' : 'close'} investment';
          AppFeedback.showError(context, errorMessage);
        }
      }
    }
  }

  void _showOptionsSheet(BuildContext context, bool isDark) {
    final isClosed = widget.investment.status == InvestmentStatus.closed;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.neutral600Dark : AppColors.neutral300Light,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.edit_rounded, color: AppColors.primaryLight),
                title: Text(
                  'Edit Investment',
                  style: AppTypography.body.copyWith(
                    color: isDark ? Colors.white : AppColors.neutral900Light,
                  ),
                ),
                onTap: () {
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  navigator.push(
                    MaterialPageRoute(
                      builder: (context) => EditInvestmentScreen(investment: widget.investment),
                    ),
                  ).then((result) {
                    if (result == true && mounted) {
                      navigator.pop();
                    }
                  });
                },
              ),
              ListTile(
                leading: Icon(
                  isClosed ? Icons.lock_open_rounded : Icons.lock_rounded,
                  color: AppColors.graphAmber,
                ),
                title: Text(
                  isClosed ? 'Reopen Investment' : 'Close Investment',
                  style: AppTypography.body.copyWith(
                    color: isDark ? Colors.white : AppColors.neutral900Light,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _toggleInvestmentStatus(context, isDark);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_rounded, color: AppColors.errorLight),
                title: Text(
                  'Delete Investment',
                  style: AppTypography.body.copyWith(color: AppColors.errorLight),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteInvestment(context, isDark);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
