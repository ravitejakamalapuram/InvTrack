import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/utils/date_utils.dart';
import 'package:inv_tracker/core/utils/number_format_utils.dart';
import 'package:inv_tracker/core/widgets/compact_amount_text.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/loading_skeletons.dart';
import 'package:inv_tracker/core/widgets/premium_animations.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_investment_screen.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_transaction_screen.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/add_document_sheet.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/document_list_widget.dart';

class InvestmentDetailScreen extends ConsumerStatefulWidget {
  final InvestmentEntity investment;

  const InvestmentDetailScreen({super.key, required this.investment});

  @override
  ConsumerState<InvestmentDetailScreen> createState() =>
      _InvestmentDetailScreenState();
}

class _InvestmentDetailScreenState extends ConsumerState<InvestmentDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  /// 0 = Transactions, 1 = Documents
  int _selectedSegment = 0;

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
    final isArchived = widget.investment.isArchived;
    // Use the appropriate providers based on whether investment is archived
    final cashFlowsAsync = isArchived
        ? ref.watch(archivedCashFlowsByInvestmentProvider(widget.investment.id))
        : ref.watch(cashFlowsByInvestmentProvider(widget.investment.id));
    final statsAsync = isArchived
        ? ref.watch(archivedInvestmentStatsProvider(widget.investment.id))
        : ref.watch(investmentStatsProvider(widget.investment.id));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = ref.watch(currencyFormatProvider);
    final isClosed = widget.investment.status == InvestmentStatus.closed;
    final isPrivacyMode = ref.watch(privacyModeProvider);

    final primaryColor = isClosed ? Colors.grey : widget.investment.type.color;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      body: CustomScrollView(
        // Pre-render items 500 pixels before they come into view for smoother fast scrolling
        cacheExtent: 500,
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
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 22,
                ),
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
                  child: const Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
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
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
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
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.3,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
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
                  data: (stats) => _buildStatsSection(
                    stats,
                    isDark,
                    currencyFormat,
                    isPrivacyMode,
                  ),
                  loading: () => _buildStatsLoading(isDark),
                  error: (e, s) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),

          // Segmented Control for Transactions / Documents
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _buildSegmentedControl(isDark, cashFlowsAsync, isClosed),
            ),
          ),

          // Content based on selected segment
          if (_selectedSegment == 0) ...[
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
                        return _buildCashFlowCard(
                          sortedFlows[index],
                          isDark,
                          currencyFormat,
                        );
                      },
                      childCount: sortedFlows.length,
                      addAutomaticKeepAlives: true,
                      addRepaintBoundaries: true,
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
          ] else ...[
            // Documents Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DocumentListWidget(
                  investmentId: widget.investment.id,
                  isReadOnly: isClosed,
                ),
              ),
            ),
          ],

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: isClosed
          ? null
          : Container(
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
                heroTag: 'investment_detail_fab',
                onPressed: () {
                  if (_selectedSegment == 0) {
                    // Add Transaction
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AddTransactionScreen(
                          investmentId: widget.investment.id,
                        ),
                      ),
                    );
                  } else {
                    // Add Document - trigger the document picker from DocumentListWidget
                    // We'll use a callback approach by accessing the widget's add function
                    _showAddDocumentSheet(context, isDark);
                  }
                },
                backgroundColor: Colors.transparent,
                elevation: 0,
                icon: Icon(
                  _selectedSegment == 0
                      ? Icons.add_rounded
                      : Icons.upload_file_rounded,
                  color: Colors.white,
                ),
                label: Text(
                  _selectedSegment == 0 ? 'Add Transaction' : 'Add Document',
                  style: AppTypography.button.copyWith(color: Colors.white),
                ),
              ),
            ),
    );
  }

  Widget _buildStatsSection(
    InvestmentStats stats,
    bool isDark,
    NumberFormat currencyFormat,
    bool isPrivacyMode,
  ) {
    final isPositive = stats.netCashFlow >= 0;
    final xirrFormatted = formatXirr(stats.xirr) ?? '0.0%';
    final xirrIsPositive = stats.xirr >= 0;

    final netPositionStyle = AppTypography.h2.copyWith(
      color: isDark ? Colors.white : AppColors.neutral900Light,
      fontWeight: FontWeight.w700,
    );
    final cashFlowStyle = AppTypography.bodyMedium.copyWith(
      color: isDark ? Colors.white : AppColors.neutral900Light,
      fontWeight: FontWeight.w600,
    );

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
                  color:
                      (isPositive
                              ? AppColors.successLight
                              : AppColors.errorLight)
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isPositive
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  size: 28,
                  color: isPositive
                      ? AppColors.successLight
                      : AppColors.errorLight,
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
                        color: isDark
                            ? AppColors.neutral400Dark
                            : AppColors.neutral500Light,
                      ),
                    ),
                    const SizedBox(height: 4),
                    isPrivacyMode
                        ? MaskedAmountText(
                            text: currencyFormat.formatSmart(stats.netCashFlow),
                            style: netPositionStyle,
                          )
                        : CompactAmountText(
                            amount: stats.netCashFlow,
                            compactText: currencyFormat.formatSmart(
                              stats.netCashFlow,
                            ),
                            currencySymbol: currencyFormat.currencySymbol,
                            style: netPositionStyle,
                          ),
                  ],
                ),
              ),
              // Return percentage - also mask in privacy mode
              isPrivacyMode
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const MaskedAmountText(text: '••••'),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (isPositive
                                    ? AppColors.successLight
                                    : AppColors.errorLight)
                                .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${stats.absoluteReturn >= 0 ? '+' : ''}${stats.absoluteReturn.toStringAsFixed(1)}%',
                        style: AppTypography.bodyMedium.copyWith(
                          color: isPositive
                              ? AppColors.successLight
                              : AppColors.errorLight,
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
              Icon(
                Icons.arrow_upward_rounded,
                size: 16,
                color: AppColors.errorLight,
              ),
              const SizedBox(width: 4),
              isPrivacyMode
                  ? MaskedAmountText(
                      text: currencyFormat.formatCompact(stats.totalInvested),
                      style: cashFlowStyle,
                    )
                  : CompactAmountText(
                      amount: stats.totalInvested,
                      compactText:
                          currencyFormat.formatCompact(stats.totalInvested),
                      currencySymbol: currencyFormat.currencySymbol,
                      style: cashFlowStyle,
                    ),
              Text(
                ' out',
                style: AppTypography.small.copyWith(
                  color: isDark
                      ? AppColors.neutral400Dark
                      : AppColors.neutral500Light,
                ),
              ),
              const SizedBox(width: 16),
              // Cash In
              Icon(
                Icons.arrow_downward_rounded,
                size: 16,
                color: AppColors.successLight,
              ),
              const SizedBox(width: 4),
              isPrivacyMode
                  ? MaskedAmountText(
                      text: currencyFormat.formatCompact(stats.totalReturned),
                      style: cashFlowStyle,
                    )
                  : CompactAmountText(
                      amount: stats.totalReturned,
                      compactText:
                          currencyFormat.formatCompact(stats.totalReturned),
                      currencySymbol: currencyFormat.currencySymbol,
                      style: cashFlowStyle,
                    ),
              Text(
                ' in',
                style: AppTypography.small.copyWith(
                  color: isDark
                      ? AppColors.neutral400Dark
                      : AppColors.neutral500Light,
                ),
              ),
              const Spacer(),
              Text(
                '${stats.cashFlowCount} txns',
                style: AppTypography.small.copyWith(
                  color: isDark
                      ? AppColors.neutral400Dark
                      : AppColors.neutral500Light,
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
                xirrFormatted,
                xirrIsPositive ? AppColors.graphCyan : AppColors.errorLight,
                isDark,
                isPrivacyMode: isPrivacyMode,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMiniStatCard(
                'MOIC',
                formatMultiplier(stats.moic),
                AppColors.graphPurple,
                isDark,
                subtitle: stats.durationFormatted,
                isPrivacyMode: isPrivacyMode,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniStatCard(
    String label,
    String value,
    Color color,
    bool isDark, {
    String? subtitle,
    bool isPrivacyMode = false,
  }) {
    final valueStyle = AppTypography.bodyMedium.copyWith(
      color: color,
      fontWeight: FontWeight.w700,
    );

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        children: [
          Text(
            label,
            style: AppTypography.small.copyWith(
              color: isDark
                  ? AppColors.neutral400Dark
                  : AppColors.neutral500Light,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          isPrivacyMode
              ? MaskedAmountText(text: value, style: valueStyle)
              : Text(value, style: valueStyle),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle,
                style: AppTypography.small.copyWith(
                  color: isDark
                      ? AppColors.neutral500Dark
                      : AppColors.neutral400Light,
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
                        color: isDark
                            ? AppColors.neutral700Dark
                            : AppColors.neutral200Light,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 60,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.neutral700Dark
                            : AppColors.neutral200Light,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 40,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.neutral700Dark
                            : AppColors.neutral200Light,
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

  Widget _buildSegmentedControl(
    bool isDark,
    AsyncValue<List<CashFlowEntity>> cashFlowsAsync,
    bool isClosed,
  ) {
    final transactionCount = cashFlowsAsync.value?.length ?? 0;
    final documentsAsync = ref.watch(
      documentsByInvestmentProvider(widget.investment.id),
    );
    final documentCount = documentsAsync.value?.length ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.neutral800Dark : AppColors.neutral100Light,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          // Transactions Tab
          Expanded(
            child: _buildSegmentTab(
              isDark: isDark,
              isSelected: _selectedSegment == 0,
              icon: Icons.swap_vert_rounded,
              label: 'Transactions',
              count: transactionCount,
              onTap: () => setState(() => _selectedSegment = 0),
            ),
          ),

          // Documents Tab
          Expanded(
            child: _buildSegmentTab(
              isDark: isDark,
              isSelected: _selectedSegment == 1,
              icon: Icons.folder_outlined,
              label: 'Documents',
              count: documentCount,
              onTap: () => setState(() => _selectedSegment = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentTab({
    required bool isDark,
    required bool isSelected,
    required IconData icon,
    required String label,
    required int count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: isSelected ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          final bgColor = Color.lerp(
            Colors.transparent,
            isDark ? AppColors.neutral700Dark : Colors.white,
            value,
          )!;
          final iconTextColor = Color.lerp(
            isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
            isDark ? Colors.white : AppColors.neutral900Light,
            value,
          )!;
          final badgeBgColor = Color.lerp(
            isDark ? AppColors.neutral600Dark : AppColors.neutral200Light,
            AppColors.primaryLight.withValues(alpha: 0.15),
            value,
          )!;
          final badgeTextColor = Color.lerp(
            isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
            AppColors.primaryLight,
            value,
          )!;
          final shadowOpacity = 0.08 * value;

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              boxShadow: value > 0.01
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: shadowOpacity),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: iconTextColor),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTypography.bodyMedium.copyWith(
                    color: iconTextColor,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: AppTypography.small.copyWith(
                        color: badgeTextColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
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
                color: isDark
                    ? AppColors.neutral400Dark
                    : AppColors.neutral500Light,
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
                color: isDark
                    ? AppColors.neutral400Dark
                    : AppColors.neutral500Light,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                if (widget.investment.isArchived) {
                  ref.invalidate(
                    archivedCashFlowsByInvestmentProvider(widget.investment.id),
                  );
                } else {
                  ref.invalidate(
                    cashFlowsByInvestmentProvider(widget.investment.id),
                  );
                }
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashFlowCard(
    CashFlowEntity cashFlow,
    bool isDark,
    NumberFormat currencyFormat,
  ) {
    final isOutflow = cashFlow.type.isOutflow;
    final color = isOutflow ? AppColors.errorLight : AppColors.successLight;

    return RepaintBoundary(
      child: Padding(
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
          confirmDismiss: (direction) =>
              _confirmDeleteCashFlow(context, isDark),
          onDismissed: (direction) {
            ref
                .read(investmentNotifierProvider.notifier)
                .deleteCashFlow(cashFlow.id);
            AppFeedback.showSuccess(context, 'Transaction deleted');
          },
          // Using Material instead of GlassCard - BackdropFilter blur is too expensive for scrolling
          child: Material(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(16),
            elevation: isDark ? 0 : 1,
            shadowColor: Colors.black.withValues(alpha: 0.1),
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AddTransactionScreen(
                      investmentId: widget.investment.id,
                      cashFlowToEdit: cashFlow,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
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
                        isOutflow
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
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
                              color: isDark
                                  ? AppColors.neutral400Dark
                                  : AppColors.neutral500Light,
                            ),
                          ),
                          if (cashFlow.notes != null &&
                              cashFlow.notes!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              cashFlow.notes!,
                              style: AppTypography.small.copyWith(
                                color: isDark
                                    ? AppColors.neutral400Dark
                                    : AppColors.neutral500Light,
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
                      '${isOutflow ? '-' : '+'}${currencyFormat.formatSmart(cashFlow.amount)}',
                      style: AppTypography.bodyLarge.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDeleteCashFlow(
    BuildContext context,
    bool isDark,
  ) async {
    final confirmed = await AppFeedback.showConfirmDialog(
      context: context,
      title: 'Delete Transaction?',
      message: 'This action cannot be undone.',
      confirmText: 'Delete',
    );
    return confirmed;
  }

  Future<void> _confirmDeleteInvestment(
    BuildContext context,
    bool isDark,
  ) async {
    // Capture navigator and messenger upfront before any async operations
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await AppFeedback.showConfirmDialog(
      context: context,
      title: 'Delete Investment?',
      message:
          'This will permanently delete this investment and all its transactions. This action cannot be undone.',
      confirmText: 'Delete',
    );

    if (confirmed && mounted) {
      try {
        final notifier = ref.read(investmentNotifierProvider.notifier);
        if (widget.investment.isArchived) {
          await notifier.deleteArchivedInvestment(widget.investment.id);
        } else {
          await notifier.deleteInvestment(widget.investment.id);
        }
        HapticFeedback.mediumImpact();
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Investment deleted')),
              ],
            ),
            backgroundColor: isDark
                ? AppColors.successDark
                : AppColors.successLight,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
            backgroundColor: isDark
                ? AppColors.errorDark
                : AppColors.errorLight,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
    final errorMessage =
        'Failed to ${isClosed ? 'reopen' : 'close'} investment';

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
          await ref
              .read(investmentNotifierProvider.notifier)
              .reopenInvestment(widget.investment.id);
        } else {
          await ref
              .read(investmentNotifierProvider.notifier)
              .closeInvestment(widget.investment.id);
        }
        HapticFeedback.mediumImpact();
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(successMessage)),
              ],
            ),
            backgroundColor: isDark
                ? AppColors.successDark
                : AppColors.successLight,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
            backgroundColor: isDark
                ? AppColors.errorDark
                : AppColors.errorLight,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showAddDocumentSheet(BuildContext context, bool isDark) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          AddDocumentSheet(investmentId: widget.investment.id),
    );
  }

  void _showOptionsSheet(BuildContext context, bool isDark) {
    final isClosed = widget.investment.status == InvestmentStatus.closed;
    final isArchived = widget.investment.isArchived;
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
                  color: isDark
                      ? AppColors.neutral600Dark
                      : AppColors.neutral300Light,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(
                  Icons.edit_rounded,
                  color: AppColors.primaryLight,
                ),
                title: Text(
                  'Edit Investment',
                  style: AppTypography.body.copyWith(
                    color: isDark ? Colors.white : AppColors.neutral900Light,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  final navigator = Navigator.of(screenContext);
                  navigator
                      .push(
                        MaterialPageRoute(
                          builder: (_) => AddInvestmentScreen(
                            investmentToEdit: widget.investment,
                          ),
                        ),
                      )
                      .then((result) {
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
                leading: Icon(
                  isArchived ? Icons.unarchive_rounded : Icons.archive_rounded,
                  color: AppColors.graphTeal,
                ),
                title: Text(
                  isArchived ? 'Unarchive Investment' : 'Archive Investment',
                  style: AppTypography.body.copyWith(
                    color: isDark ? Colors.white : AppColors.neutral900Light,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _toggleArchiveStatus(screenContext, isDark);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_rounded,
                  color: AppColors.errorLight,
                ),
                title: Text(
                  'Delete Investment',
                  style: AppTypography.body.copyWith(
                    color: AppColors.errorLight,
                  ),
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

  void _toggleArchiveStatus(BuildContext context, bool isDark) async {
    final isArchived = widget.investment.isArchived;
    // Capture navigator and messenger upfront before any async operations
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final successMessage =
        'Investment ${isArchived ? 'unarchived' : 'archived'}';
    final errorMessage =
        'Failed to ${isArchived ? 'unarchive' : 'archive'} investment';

    final confirmed = await AppFeedback.showConfirmDialog(
      context: context,
      title: '${isArchived ? 'Unarchive' : 'Archive'} Investment?',
      message: isArchived
          ? 'This will restore the investment to your active list.'
          : 'This will hide the investment from your active list. You can restore it anytime from the Archived filter.',
      confirmText: isArchived ? 'Unarchive' : 'Archive',
      isDestructive: false,
    );

    if (confirmed && mounted) {
      try {
        if (isArchived) {
          await ref
              .read(investmentNotifierProvider.notifier)
              .unarchiveInvestment(widget.investment.id);
        } else {
          await ref
              .read(investmentNotifierProvider.notifier)
              .archiveInvestment(widget.investment.id);
        }
        HapticFeedback.mediumImpact();
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(successMessage)),
              ],
            ),
            backgroundColor: isDark
                ? AppColors.successDark
                : AppColors.successLight,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        // Navigate back after archiving (but not for unarchive)
        if (!isArchived && mounted) {
          navigator.pop();
        }
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.error_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(errorMessage)),
                ],
              ),
              backgroundColor: isDark
                  ? AppColors.errorDark
                  : AppColors.errorLight,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    }
  }
}
