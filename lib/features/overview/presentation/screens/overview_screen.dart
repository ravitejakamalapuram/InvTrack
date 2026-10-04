import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/utils/async_value_utils.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/utils/date_utils.dart';
import 'package:inv_tracker/core/widgets/compact_amount_text.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/loading_skeletons.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/features/bulk_import/presentation/screens/bulk_import_screen.dart';
import 'package:inv_tracker/features/fire_number/presentation/widgets/fire_dashboard_card.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goals_dashboard_card.dart';
import 'package:inv_tracker/features/income_projection/presentation/widgets/income_guardian_dashboard_card.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_investment_screen.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/hero_card.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/widgets/portfolio_health_dashboard_card.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/overview_analytics.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/overview_empty_state.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/overview_quick_stats.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/sample_data_banner.dart';
import 'package:inv_tracker/features/settings/presentation/providers/sample_data_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class OverviewScreen extends ConsumerStatefulWidget {
  const OverviewScreen({super.key});

  @override
  ConsumerState<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends ConsumerState<OverviewScreen> {
  /// Whether `empty_state_viewed` was logged by this screen, so rebuilds and
  /// new snapshots do not log it again.
  bool _emptyStateViewLogged = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Use multi-currency stats providers (Rule 21.3 compliance)
    // Convert all amounts to base currency before displaying
    // errorFirst: while Riverpod retries a failed load, show the error and
    // its retry action, not skeletons for as long as the retries last.
    final globalStatsAsync = errorFirst(
      ref.watch(multiCurrencyGlobalStatsProvider),
    );
    final globalStats = globalStatsAsync.when<AsyncValue<InvestmentStats>>(
      data: (stats) => AsyncValue.data(stats),
      loading: () => const AsyncValue.loading(),
      error: (e, st) => AsyncValue.error(e, st),
    );

    final openStatsAsync = ref.watch(multiCurrencyOpenStatsProvider);
    final openStats = openStatsAsync.when<AsyncValue<InvestmentStats>>(
      data: (stats) => AsyncValue.data(stats),
      loading: () => const AsyncValue.loading(),
      error: (e, st) => AsyncValue.error(e, st),
    );

    final closedStatsAsync = ref.watch(multiCurrencyClosedStatsProvider);
    final closedStats = closedStatsAsync.when<AsyncValue<InvestmentStats>>(
      data: (stats) => AsyncValue.data(stats),
      loading: () => const AsyncValue.loading(),
      error: (e, st) => AsyncValue.error(e, st),
    );

    // Only an account with no active and no archived investments is new; one
    // with investments but no cash flows yet, or only archived investments,
    // must not be offered sample data. Archived investments live in their own
    // collection, so both must have loaded.
    final archivedInvestmentsAsync = errorFirst(
      ref.watch(archivedInvestmentsProvider),
    );
    final isNewAccount =
        (ref.watch(activeInvestmentsProvider).value?.isEmpty ?? false) &&
        (archivedInvestmentsAsync.value?.isEmpty ?? false);

    final currencyFormat = ref.watch(currencyFormatProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'overview_add_investment_fab',
        onPressed: () {
          HapticFeedback.mediumImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddInvestmentScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.addInvestment),
        backgroundColor: isDark
            ? AppColors.primaryDark
            : AppColors.primaryLight,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => reloadPortfolio(ref),
          child: CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                floating: true,
                title: const Text(
                  'Investment Tracker',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                centerTitle: false,
              ),

              // Content
              SliverPadding(
                padding: EdgeInsets.all(AppSpacing.md),
                sliver: globalStats.when(
                  // Without archived investments it is not known whether
                  // the account is empty: show the load error, not onboarding.
                  data: (stats) => !stats.hasData &&
                          archivedInvestmentsAsync.hasError
                      ? _buildLoadErrorContent(ref)
                      : stats.hasData
                      ? _buildDataContent(
                          context,
                          ref,
                          globalStats,
                          openStats,
                          closedStats,
                          currencyFormat,
                          isDark,
                          l10n,
                        )
                      : _buildEmptyStateContent(
                          context,
                          ref,
                          globalStats,
                          closedStats,
                          currencyFormat,
                          isDark,
                          isNewAccount: isNewAccount,
                        ),
                  loading: () => _buildLoadingContent(
                    context,
                    ref,
                    globalStats,
                    closedStats,
                    currencyFormat,
                  ),
                  // A load failure is not an empty account: no onboarding,
                  // no sample data, no empty_state_viewed.
                  error: (e, s) => _buildLoadErrorContent(ref),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build content when there is data
  SliverList _buildDataContent(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<InvestmentStats> globalStats,
    AsyncValue<InvestmentStats> openStats,
    AsyncValue<InvestmentStats> closedStats,
    NumberFormat currencyFormat,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return SliverList(
      delegate: SliverChildListDelegate([
        // Sample Data Mode Banner (shows when active)
        const SampleDataBanner(),

        // Hero Card - Global Summary with toggle
        HeroCardWithToggle(
          globalStats: globalStats,
          openStats: openStats,
          closedStats: closedStats,
          currencyFormat: currencyFormat,
          errorBuilder: (error) => OverviewErrorCard(error: error),
        ),

        SizedBox(height: AppSpacing.xl),

        // Portfolio Health Score Card
        const PortfolioHealthDashboardCard(),

        SizedBox(height: AppSpacing.xl),

        // Income Guardian Card (feature flag)
        if (ref.watch(isIncomeGuardianEnabledProvider)) ...[
          const IncomeGuardianDashboardCard(),
          SizedBox(height: AppSpacing.xl),
        ],

        // Goals Summary Card
        const GoalsDashboardCard(),

        SizedBox(height: AppSpacing.xl),

        // FIRE Progress Card
        const FireDashboardCard(),

        SizedBox(height: AppSpacing.xl),

        // Quick Stats Grid
        globalStats.when(
          data: (stats) => OverviewQuickStats(
            stats: stats,
            // Until the open subset is known, assume everything may be open
            // so a missing terminal value is never shown as a loss.
            openStats: openStats.hasValue ? openStats.requireValue : stats,
          ),
          loading: () => const SizedBox.shrink(),
          error: (e, s) => const SizedBox.shrink(),
        ),

        SizedBox(height: AppSpacing.xl),

        // Net Position Breakdown (Open vs Closed)
        _buildNetPositionBreakdown(
          context,
          ref,
          openStats,
          closedStats,
          currencyFormat,
          isDark,
        ),

        SizedBox(height: AppSpacing.xl),

        // Monthly Cash Flow Trend
        MonthlyCashFlowTrend(currencyFormat: currencyFormat),

        SizedBox(height: AppSpacing.xl),

        // Investment Type Distribution
        TypeDistributionChart(currencyFormat: currencyFormat),

        SizedBox(height: AppSpacing.xl),

        // YoY Comparison
        YoYComparisonCard(currencyFormat: currencyFormat),

        SizedBox(height: AppSpacing.xl),

        // Recently Closed
        RecentlyClosedCard(currencyFormat: currencyFormat),

        SizedBox(height: AppSpacing.xl),

        // Investment Period summary
        globalStats.when(
          data: (stats) => _buildSummarySection(context, stats),
          loading: () => const SizedBox.shrink(),
          error: (e, s) => const SizedBox.shrink(),
        ),

        // Bottom padding for FAB
        SizedBox(height: AppSpacing.fabBottomPadding),
      ]),
    );
  }

  /// Build content for when the portfolio failed to load
  SliverList _buildLoadErrorContent(WidgetRef ref) {
    return SliverList(
      delegate: SliverChildListDelegate([
        OverviewLoadErrorState(onRetry: () => reloadPortfolio(ref)),
        // Bottom padding for FAB
        const SizedBox(height: 80),
      ]),
    );
  }

  /// Build content for empty state (no cash flows).
  ///
  /// Sample data and the `empty_state_viewed` event are only for a new
  /// account ([isNewAccount]); sample data would otherwise be mixed into
  /// real investments.
  SliverList _buildEmptyStateContent(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<InvestmentStats> globalStats,
    AsyncValue<InvestmentStats> closedStats,
    NumberFormat currencyFormat,
    bool isDark, {
    required bool isNewAccount,
  }) {
    // Track the empty state view once, not on every rebuild
    if (isNewAccount && !_emptyStateViewLogged) {
      _emptyStateViewLogged = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(analyticsServiceProvider)
            .logEvent(
              name: 'empty_state_viewed',
              parameters: {'screen': 'overview'},
            );
      });
    }

    return SliverList(
      delegate: SliverChildListDelegate([
        // Hero Card - shows zeros
        HeroCardWithToggle(
          globalStats: globalStats,
          // Empty state: there are no cash flows, so nothing is open.
          openStats: globalStats,
          closedStats: closedStats,
          currencyFormat: currencyFormat,
          errorBuilder: (error) => OverviewErrorCard(error: error),
        ),

        const SizedBox(height: 32),

        // Enhanced empty state with callbacks
        OverviewEmptyState(
          onAddManual: () {
            HapticFeedback.mediumImpact();
            ref
                .read(analyticsServiceProvider)
                .logEmptyStateActionTapped(action: 'add_manual');
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddInvestmentScreen()),
            );
          },
          onImportCsv: () {
            HapticFeedback.mediumImpact();
            ref
                .read(analyticsServiceProvider)
                .logEmptyStateActionTapped(action: 'import_csv');
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BulkImportScreen()),
            );
          },
          onTemplateSelected: (template) {
            HapticFeedback.selectionClick();
            ref
                .read(analyticsServiceProvider)
                .logEmptyStateActionTapped(action: 'template_${template.id}');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    AddInvestmentScreen(preselectedTemplate: template),
              ),
            );
          },
          onTrySampleData: !isNewAccount
              ? null
              : () async {
                  HapticFeedback.mediumImpact();

                  // Capture l10n before async operation
                  final localizations = AppLocalizations.of(context);

                  // Activate sample data mode
                  final success = await ref
                      .read(sampleDataModeProvider.notifier)
                      .activateSampleData();

                  if (!context.mounted) return;

                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(localizations.sampleDataLoaded),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(localizations.sampleDataLoadFailed),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
        ),

        // Bottom padding for FAB
        const SizedBox(height: 80),
      ]),
    );
  }

  /// Build loading state content with shimmer skeletons
  SliverList _buildLoadingContent(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<InvestmentStats> globalStats,
    AsyncValue<InvestmentStats> closedStats,
    NumberFormat currencyFormat,
  ) {
    return SliverList(
      delegate: SliverChildListDelegate([
        // Hero Card Skeleton
        Semantics(
          label: AppLocalizations.of(context).overviewLoadingPortfolio,
          child: const HeroCardSkeleton(),
        ),

        const SizedBox(height: 24),

        // Quick Stats Skeleton
        const QuickStatsSkeleton(),

        const SizedBox(height: 24),

        // Net Position Breakdown Skeleton
        const SectionCardSkeleton(height: 120),

        const SizedBox(height: 24),

        // Monthly Trend Skeleton
        const SectionCardSkeleton(height: 180),

        const SizedBox(height: 24),

        // Type Distribution Skeleton
        const SectionCardSkeleton(height: 160),

        // Bottom padding for FAB
        const SizedBox(height: 80),
      ]),
    );
  }

  Widget _buildNetPositionBreakdown(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<InvestmentStats> openStats,
    AsyncValue<InvestmentStats> closedStats,
    NumberFormat currencyFormat,
    bool isDark,
  ) {
    final isPrivacyMode = ref.watch(privacyModeProvider);

    return openStats.when(
      data: (open) => closedStats.when(
        data: (closed) {
          // Only show if we have data
          if (!open.hasData && !closed.hasData) {
            return const SizedBox.shrink();
          }

          return GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Net Position Breakdown',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildBreakdownItem(
                        label: 'Open Investments',
                        value: open.netCashFlow,
                        currencyFormat: currencyFormat,
                        color: AppColors.graphBlue,
                        icon: Icons.hourglass_top,
                        isDark: isDark,
                        isPrivacyMode: isPrivacyMode,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildBreakdownItem(
                        label: 'Closed (Realized)',
                        value: closed.netCashFlow,
                        currencyFormat: currencyFormat,
                        color: closed.netCashFlow >= 0
                            ? AppColors.successLight
                            : AppColors.errorLight,
                        icon: Icons.check_circle,
                        isDark: isDark,
                        isPrivacyMode: isPrivacyMode,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (e, s) => const SizedBox.shrink(),
      ),
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  Widget _buildBreakdownItem({
    required String label,
    required double value,
    required NumberFormat currencyFormat,
    required Color color,
    required IconData icon,
    required bool isDark,
    required bool isPrivacyMode,
  }) {
    final isPositive = value >= 0;
    final valueStyle = TextStyle(
      color: isPositive ? AppColors.successLight : AppColors.errorLight,
      fontWeight: FontWeight.bold,
      fontSize: 16,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey[600],
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          isPrivacyMode
              ? MaskedAmountText(
                  text:
                      '${isPositive ? '+' : '-'}${currencyFormat.formatCompact(value.abs())}',
                  style: valueStyle,
                )
              : CompactAmountText(
                  amount: value,
                  compactText: currencyFormat.formatCompact(value.abs()),
                  prefix: isPositive ? '+' : '-',
                  style: valueStyle,
                ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(BuildContext context, InvestmentStats stats) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Investment Period',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 12),
          if (stats.firstCashFlowDate != null && stats.lastCashFlowDate != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDateInfo('First Cash Flow', stats.firstCashFlowDate!),
                _buildDateInfo('Last Cash Flow', stats.lastCashFlowDate!),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDateInfo(String label, DateTime date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          AppDateUtils.formatShort(date),
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ],
    );
  }
}
