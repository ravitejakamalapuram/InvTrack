import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/loading_skeletons.dart';
import 'package:inv_tracker/features/investment/presentation/providers/multi_currency_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_investment_screen.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_transaction_screen.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/add_document_sheet.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/cash_flow_card_widget.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/document_list_widget.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_detail_fab_widgets.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_detail_segment_control.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_detail_stats_section.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
    final isArchived = widget.investment.isArchived;
    // Use the appropriate providers based on whether investment is archived
    final cashFlowsAsync = isArchived
        ? ref.watch(archivedCashFlowsByInvestmentProvider(widget.investment.id))
        : ref.watch(cashFlowsByInvestmentProvider(widget.investment.id));

    // Use multi-currency stats provider for active investments (Rule 21.3 compliance)
    // Archived investments still use old provider (no currency conversion needed for historical data)
    final statsAsync = isArchived
        ? ref.watch(archivedInvestmentStatsProvider(widget.investment.id))
        : ref.watch(multiCurrencyInvestmentStatsProvider(widget.investment.id));

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
              tooltip: l10n.tooltipBack,
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
                tooltip: l10n.tooltipMoreOptions,
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
                  data: (stats) => InvestmentDetailStatsSection(
                    stats: stats,
                    investment: widget.investment,
                    isDark: isDark,
                    currencyFormat: currencyFormat,
                    isPrivacyMode: isPrivacyMode,
                  ),
                  loading: () => const StatsCardsSkeleton(),
                  error: (e, s) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),

          // Segmented Control for Transactions / Documents
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: InvestmentDetailSegmentControl(
                isDark: isDark,
                selectedSegment: _selectedSegment,
                transactionCount: cashFlowsAsync.value?.length ?? 0,
                documentCount:
                    ref
                        .watch(
                          documentsByInvestmentProvider(widget.investment.id),
                        )
                        .value
                        ?.length ??
                    0,
                onSegmentChanged: (index) =>
                    setState(() => _selectedSegment = index),
              ),
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
                        final cashFlow = sortedFlows[index];
                        return CashFlowCardWidget(
                          cashFlow: cashFlow,
                          isDark: isDark,
                          currencyFormat: currencyFormat,
                          onTap: () => _navigateToEditTransaction(cashFlow),
                          onEdit: () => _navigateToEditTransaction(cashFlow),
                          onConfirmDelete: () =>
                              _confirmDeleteCashFlow(context, isDark),
                          onDeleted: () => _deleteCashFlow(cashFlow.id),
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
          : _selectedSegment == 0
          ? TransactionFab(
              hasTransactions: cashFlowsAsync.value?.isNotEmpty ?? false,
              onTap: () => _navigateToAddTransaction(cashFlowsAsync),
            )
          : DocumentFab(onTap: () => _showAddDocumentSheet(context, isDark)),
    );
  }

  void _navigateToEditTransaction(CashFlowEntity cashFlow) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(
          investmentId: widget.investment.id,
          cashFlowToEdit: cashFlow,
        ),
      ),
    );
  }

  void _navigateToAddTransaction(
    AsyncValue<List<CashFlowEntity>> cashFlowsAsync,
  ) {
    final hasTransactions = cashFlowsAsync.value?.isNotEmpty ?? false;
    final smartDefaultType = TransactionFab.getSmartDefaultType(
      hasTransactions,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(
          investmentId: widget.investment.id,
          initialType: smartDefaultType,
        ),
      ),
    );
  }

  void _deleteCashFlow(String cashFlowId) {
    ref.read(investmentNotifierProvider.notifier).deleteCashFlow(cashFlowId);
    AppFeedback.showSuccess(context, 'Transaction deleted');
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
    final l10n = AppLocalizations.of(context);
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
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmDeleteCashFlow(
    BuildContext context,
    bool isDark,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppFeedback.showConfirmDialog(
      context: context,
      title: l10n.deleteTransaction,
      message: l10n.actionCannotBeUndone,
      confirmText: l10n.delete,
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
    final l10n = AppLocalizations.of(context);

    final confirmed = await AppFeedback.showConfirmDialog(
      context: context,
      title: l10n.deleteInvestment,
      message: l10n.deleteInvestmentMessage,
      confirmText: l10n.delete,
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
                Expanded(child: Text(l10n.investmentDeleted)),
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
                Expanded(child: Text(l10n.failedToDeleteInvestment)),
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
