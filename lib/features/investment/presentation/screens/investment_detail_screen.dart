import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/utils/date_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/loading_skeletons.dart';
import 'package:inv_tracker/core/widgets/premium_animations.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_investment_screen.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_transaction_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final cashFlowsAsync = ref.watch(cashFlowsByInvestmentProvider(widget.investment.id));
    final statsAsync = ref.watch(investmentStatsProvider(widget.investment.id));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = ref.watch(currencyFormatProvider);
    final isClosed = widget.investment.status == InvestmentStatus.closed;

    final primaryColor = isClosed ? Colors.grey : widget.investment.type.color;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: CustomScrollView(
        slivers: [
          // Hero App Bar with pinned navigation
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: primaryColor,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              widget.investment.name,
              style: AppTypography.body.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 22),
                ),
                onPressed: () => _showOptionsSheet(context, isDark),
              ),
              const SizedBox(width: 4),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: Icon(
                                  widget.investment.type.icon,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.investment.name,
                                    style: AppTypography.h3.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                                      if (isClosed) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.3),
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
                                    ],
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
                  data: (stats) => _buildStatsSection(stats, isDark, currencyFormat),
                  loading: () => _buildStatsLoading(isDark),
                  error: (e, s) => const SizedBox.shrink(),
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
                  hasScrollBody: false,
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
                        child: _buildCashFlowCard(sortedFlows[index], isDark, currencyFormat),
                      );
                    },
                    childCount: sortedFlows.length,
                  ),
                ),
              );
            },
            loading: () => SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: const CashFlowCardSkeleton(),
                  ),
                  childCount: 4,
                ),
              ),
            ),
            error: (err, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: _buildErrorState(isDark, err.toString()),
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
          heroTag: 'investment_detail_add_cashflow_fab',
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

  Widget _buildStatsSection(InvestmentStats stats, bool isDark, NumberFormat currencyFormat) {
    final isPositive = stats.netCashFlow >= 0;
    final xirrPercent = stats.xirr * 100;

    return Column(
      children: [
        // Net Position Hero Card
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isPositive ? AppColors.successLight : AppColors.errorLight).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  size: 28,
                  color: isPositive ? AppColors.successLight : AppColors.errorLight,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Net Position',
                      style: AppTypography.small.copyWith(
                        color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currencyFormat.format(stats.netCashFlow),
                      style: AppTypography.h2.copyWith(
                        color: isDark ? Colors.white : AppColors.neutral900Light,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (isPositive ? AppColors.successLight : AppColors.errorLight).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${stats.absoluteReturn >= 0 ? '+' : ''}${stats.absoluteReturn.toStringAsFixed(1)}%',
                  style: AppTypography.bodyMedium.copyWith(
                    color: isPositive ? AppColors.successLight : AppColors.errorLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Cash Out and Cash In with labeled icons
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Cash Out
              Icon(Icons.arrow_upward_rounded, size: 16, color: AppColors.errorLight),
              const SizedBox(width: 4),
              Text(
                currencyFormat.format(stats.totalInvested),
                style: AppTypography.bodyMedium.copyWith(
                  color: isDark ? Colors.white : AppColors.neutral900Light,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                ' out',
                style: AppTypography.small.copyWith(
                  color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                ),
              ),
              const SizedBox(width: 16),
              // Cash In
              Icon(Icons.arrow_downward_rounded, size: 16, color: AppColors.successLight),
              const SizedBox(width: 4),
              Text(
                currencyFormat.format(stats.totalReturned),
                style: AppTypography.bodyMedium.copyWith(
                  color: isDark ? Colors.white : AppColors.neutral900Light,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                ' in',
                style: AppTypography.small.copyWith(
                  color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                ),
              ),
              const Spacer(),
              Text(
                '${stats.cashFlowCount} txns',
                style: AppTypography.small.copyWith(
                  color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // XIRR and MOIC row
        Row(
          children: [
            Expanded(
              child: _buildMiniStatCard(
                'XIRR',
                '${xirrPercent >= 0 ? '+' : ''}${xirrPercent.toStringAsFixed(1)}%',
                xirrPercent >= 0 ? AppColors.graphCyan : AppColors.errorLight,
                isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMiniStatCard(
                'MOIC',
                '${stats.moic.toStringAsFixed(2)}x',
                AppColors.graphPurple,
                isDark,
                subtitle: stats.durationFormatted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniStatCard(String label, String value, Color color, bool isDark, {String? subtitle}) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        children: [
          Text(
            label,
            style: AppTypography.small.copyWith(
              color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.bodyMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle,
                style: AppTypography.small.copyWith(
                  color: isDark ? AppColors.neutral500Dark : AppColors.neutral400Light,
                  fontSize: 10,
                ),
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
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 40,
              color: widget.investment.type.color,
            ),
            const SizedBox(height: 12),
            Text(
              'No Cash Flows Yet',
              style: AppTypography.body.copyWith(
                color: isDark ? Colors.white : AppColors.neutral900Light,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap + Add to start tracking',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.errorLight.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 40,
                color: AppColors.errorLight,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load data',
              style: AppTypography.body.copyWith(
                color: isDark ? Colors.white : AppColors.neutral900Light,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => ref.invalidate(cashFlowsByInvestmentProvider(widget.investment.id)),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashFlowCard(CashFlowEntity cashFlow, bool isDark, NumberFormat currencyFormat) {
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
        confirmDismiss: (direction) => _confirmDeleteCashFlow(context, isDark),
        onDismissed: (direction) {
          ref.read(investmentNotifierProvider.notifier).deleteCashFlow(cashFlow.id);
          AppFeedback.showSuccess(context, 'Transaction deleted');
        },
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
                      AppDateUtils.formatShort(cashFlow.date),
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
                '${isOutflow ? '-' : '+'}${currencyFormat.format(cashFlow.amount)}',
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

  Future<bool?> _confirmDeleteCashFlow(BuildContext context, bool isDark) async {
    final confirmed = await AppFeedback.showConfirmDialog(
      context: context,
      title: 'Delete Transaction?',
      message: 'This action cannot be undone.',
      confirmText: 'Delete',
    );
    return confirmed;
  }

  Future<void> _confirmDeleteInvestment(BuildContext context, bool isDark) async {
    // Capture navigator and messenger upfront before any async operations
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await AppFeedback.showConfirmDialog(
      context: context,
      title: 'Delete Investment?',
      message: 'This will permanently delete this investment and all its transactions. This action cannot be undone.',
      confirmText: 'Delete',
    );

    if (confirmed && mounted) {
      try {
        await ref.read(investmentNotifierProvider.notifier).deleteInvestment(widget.investment.id);
        HapticFeedback.mediumImpact();
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                const Expanded(child: Text('Investment deleted')),
              ],
            ),
            backgroundColor: isDark ? AppColors.successDark : AppColors.successLight,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
        navigator.pop();
      } catch (e) {
        HapticFeedback.heavyImpact();
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                const Expanded(child: Text('Failed to delete investment')),
              ],
            ),
            backgroundColor: isDark ? AppColors.errorDark : AppColors.errorLight,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _toggleInvestmentStatus(BuildContext context, bool isDark) async {
    final isClosed = widget.investment.status == InvestmentStatus.closed;
    // Capture navigator and messenger upfront before any async operations
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final successMessage = 'Investment ${isClosed ? 'reopened' : 'closed'}';
    final errorMessage = 'Failed to ${isClosed ? 'reopen' : 'close'} investment';

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
      try {
        if (isClosed) {
          await ref.read(investmentNotifierProvider.notifier).reopenInvestment(widget.investment.id);
        } else {
          await ref.read(investmentNotifierProvider.notifier).closeInvestment(widget.investment.id);
        }
        HapticFeedback.mediumImpact();
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(successMessage)),
              ],
            ),
            backgroundColor: isDark ? AppColors.successDark : AppColors.successLight,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
        navigator.pop();
      } catch (e) {
        HapticFeedback.heavyImpact();
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: isDark ? AppColors.errorDark : AppColors.errorLight,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showOptionsSheet(BuildContext context, bool isDark) {
    final isClosed = widget.investment.status == InvestmentStatus.closed;
    // Store a reference to screen's context before entering the builder
    final screenContext = context;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
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
                  Navigator.pop(sheetContext);
                  final navigator = Navigator.of(screenContext);
                  navigator.push(
                    MaterialPageRoute(
                      builder: (_) => AddInvestmentScreen(investmentToEdit: widget.investment),
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
                  Navigator.pop(sheetContext);
                  _toggleInvestmentStatus(screenContext, isDark);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_rounded, color: AppColors.errorLight),
                title: Text(
                  'Delete Investment',
                  style: AppTypography.body.copyWith(color: AppColors.errorLight),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDeleteInvestment(screenContext, isDark);
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
