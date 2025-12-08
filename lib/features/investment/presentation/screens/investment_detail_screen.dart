import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/calculations/financial_calculator.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
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
    switch (widget.investment.type.toLowerCase()) {
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

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsByInvestmentProvider(widget.investment.id));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = ref.watch(currencyFormatPreciseProvider);

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
                    colors: [_typeColor, _typeColor.withValues(alpha: 0.7)],
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
                                child: Text(
                                  widget.investment.symbol?.substring(0, 1).toUpperCase() ??
                                      widget.investment.name.substring(0, 1).toUpperCase(),
                                  style: AppTypography.h2.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
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
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          widget.investment.type,
                                          style: AppTypography.small.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      if (widget.investment.symbol != null) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          widget.investment.symbol!,
                                          style: AppTypography.body.copyWith(
                                            color: Colors.white.withValues(alpha: 0.8),
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
                child: transactionsAsync.when(
                  data: (transactions) => _buildStatsSection(transactions, isDark, currencyFormat),
                  loading: () => _buildStatsLoading(isDark),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),

          // Transactions Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Transactions',
                    style: AppTypography.h4.copyWith(
                      color: isDark ? Colors.white : AppColors.neutral900Light,
                    ),
                  ),
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

          // Transactions List
          transactionsAsync.when(
            data: (transactions) {
              if (transactions.isEmpty) {
                return SliverFillRemaining(
                  child: _buildEmptyTransactions(isDark),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return StaggeredFadeIn(
                        index: index,
                        child: _buildTransactionCard(transactions[index], isDark, currencyFormat),
                      );
                    },
                    childCount: transactions.length,
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
      floatingActionButton: Container(
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
            'Add Transaction',
            style: AppTypography.button.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection(List<TransactionEntity> transactions, bool isDark, NumberFormat currencyFormat) {
    // Calculate stats from transactions
    double totalInvested = 0;
    double totalUnits = 0;
    double lastPrice = 0;

    // Sort by date to get last price
    final sortedTx = List<TransactionEntity>.from(transactions)
      ..sort((a, b) => a.date.compareTo(b.date));

    for (final t in sortedTx) {
      if (t.type == 'BUY') {
        totalInvested += t.totalAmount;
        totalUnits += t.quantity;
        lastPrice = t.pricePerUnit;
      } else if (t.type == 'SELL') {
        totalInvested -= t.totalAmount;
        totalUnits -= t.quantity;
        lastPrice = t.pricePerUnit;
      } else if (t.type == 'DIVIDEND') {
        if (t.pricePerUnit > 0) lastPrice = t.pricePerUnit;
      }
    }

    final avgPrice = totalUnits > 0 ? totalInvested / totalUnits : 0.0;
    final currentValue = totalUnits * lastPrice;
    final profitLoss = currentValue - totalInvested;
    final profitLossPercent = totalInvested > 0 ? (profitLoss / totalInvested) * 100 : 0.0;
    final xirr = FinancialCalculator.calculateXirr(transactions, currentValue);
    final isPositive = profitLoss >= 0;

    return Column(
      children: [
        // First row: Current Value and P/L
        Row(
          children: [
            Expanded(
              child: _buildStatCardLarge(
                'Current Value',
                currencyFormat.format(currentValue),
                Icons.account_balance_rounded,
                AppColors.primaryLight,
                isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCardLarge(
                'P/L',
                '${isPositive ? '+' : ''}${currencyFormat.format(profitLoss)}',
                isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                isPositive ? AppColors.successLight : AppColors.errorLight,
                isDark,
                subtitle: '${isPositive ? '+' : ''}${profitLossPercent.toStringAsFixed(1)}%',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Second row: Invested, Units, Avg Price
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Invested',
                currencyFormat.format(totalInvested),
                Icons.account_balance_wallet_rounded,
                AppColors.graphBlue,
                isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Units',
                totalUnits.toStringAsFixed(2),
                Icons.inventory_2_rounded,
                AppColors.graphEmerald,
                isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Avg Price',
                currencyFormat.format(avgPrice),
                Icons.price_change_rounded,
                AppColors.graphPurple,
                isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Third row: XIRR
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'XIRR',
                '${xirr >= 0 ? '+' : ''}${(xirr * 100).toStringAsFixed(1)}%',
                Icons.show_chart_rounded,
                xirr >= 0 ? AppColors.graphCyan : AppColors.errorLight,
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

  Widget _buildEmptyTransactions(bool isDark) {
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
              'No Transactions Yet',
              style: AppTypography.h4.copyWith(
                color: isDark ? Colors.white : AppColors.neutral900Light,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first buy or sell transaction to start tracking',
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

  Widget _buildTransactionCard(TransactionEntity transaction, bool isDark, NumberFormat currencyFormat) {
    final isBuy = transaction.type == 'BUY';
    final color = isBuy ? AppColors.successLight : AppColors.errorLight;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: Key(transaction.id),
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
        confirmDismiss: (direction) => _confirmDelete(context, isDark),
        onDismissed: (direction) {
          HapticFeedback.mediumImpact();
          ref.read(investmentProvider.notifier).deleteTransaction(transaction.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Transaction deleted'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        },
        child: GlassCard(
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
                  isBuy ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 14),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            transaction.type,
                            style: AppTypography.small.copyWith(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${transaction.quantity} units',
                          style: AppTypography.body.copyWith(
                            color: isDark ? Colors.white : AppColors.neutral900Light,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM d, yyyy').format(transaction.date),
                      style: AppTypography.small.copyWith(
                        color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                      ),
                    ),
                  ],
                ),
              ),
              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currencyFormat.format(transaction.totalAmount),
                    style: AppTypography.bodyLarge.copyWith(
                      color: isDark ? Colors.white : AppColors.neutral900Light,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '@ ${currencyFormat.format(transaction.pricePerUnit)}',
                    style: AppTypography.small.copyWith(
                      color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, bool isDark) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Transaction?',
          style: AppTypography.h4.copyWith(
            color: isDark ? Colors.white : AppColors.neutral900Light,
          ),
        ),
        content: Text(
          'This action cannot be undone.',
          style: AppTypography.body.copyWith(
            color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.button.copyWith(
                color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style: AppTypography.button.copyWith(color: AppColors.errorLight),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteInvestment(BuildContext context, bool isDark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Investment?',
          style: AppTypography.h4.copyWith(
            color: isDark ? Colors.white : AppColors.neutral900Light,
          ),
        ),
        content: Text(
          'This will permanently delete this investment and all its transactions. This action cannot be undone.',
          style: AppTypography.body.copyWith(
            color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.button.copyWith(
                color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style: AppTypography.button.copyWith(color: AppColors.errorLight),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      HapticFeedback.mediumImpact();
      await ref.read(investmentProvider.notifier).deleteInvestment(widget.investment.id);
      if (mounted) {
        Navigator.of(context).pop(); // Go back to investment list
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Investment deleted'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _showOptionsSheet(BuildContext context, bool isDark) {
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
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => EditInvestmentScreen(investment: widget.investment),
                    ),
                  ).then((result) {
                    if (result == true && mounted) {
                      // Investment was updated, pop this screen to refresh the list
                      Navigator.of(context).pop();
                    }
                  });
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
