/// Base scaffold for report screens with common structure
///
/// Provides:
/// - Consistent AppBar with title and actions
/// - Loading/Error/Data states via AsyncValue
/// - Scroll view with padding
/// - Export/Share actions (optional)
/// - Automatic analytics tracking
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/widgets/loading_skeletons.dart';

/// Base report screen for code reuse
abstract class BaseReportScreen<T> extends ConsumerStatefulWidget {
  const BaseReportScreen({super.key});

  /// Report title for AppBar
  String getTitle(BuildContext context);

  /// Provider to watch for report data
  /// Returns a FutureProvider that provides AsyncValue of T
  FutureProvider<T> getDataProvider(WidgetRef ref);

  /// Build report content when data is loaded
  Widget buildContent(BuildContext context, WidgetRef ref, T data);

  /// Build AppBar actions (export, share, etc.)
  /// Return empty list if no actions needed
  List<Widget> buildActions(BuildContext context, WidgetRef ref, T data) {
    return [];
  }

  /// Report type for analytics tracking (e.g., "weekly", "monthly", "fy")
  String getReportType();

  /// Whether this is a historical report (default: false)
  bool isHistoricalReport() => false;

  /// Period identifier for historical reports (e.g., "2023", "2024-03")
  String? getPeriodIdentifier() => null;

  /// Whether to show a loading skeleton (true) or spinner (false)
  bool get useLoadingSkeleton => true;

  /// Build loading state widget
  Widget buildLoadingState(BuildContext context) {
    if (useLoadingSkeleton) {
      return const SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            SectionCardSkeleton(height: 200),
            SizedBox(height: AppSpacing.md),
            SectionCardSkeleton(height: 150),
            SizedBox(height: AppSpacing.md),
            SectionCardSkeleton(height: 180),
          ],
        ),
      );
    }
    return const Center(child: CircularProgressIndicator());
  }

  /// Build error state widget
  Widget buildErrorState(
    BuildContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Failed to generate report',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: () {
                // Trigger rebuild to retry
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  ConsumerState<BaseReportScreen<T>> createState() => _BaseReportScreenState<T>();
}

/// State for BaseReportScreen with analytics tracking
class _BaseReportScreenState<T> extends ConsumerState<BaseReportScreen<T>> {
  final _analytics = AnalyticsService();
  bool _analyticsLogged = false;

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(widget.getDataProvider(ref));

    // Log analytics when data loads successfully (only once per screen instance)
    if (!_analyticsLogged && dataAsync.hasValue) {
      _analyticsLogged = true;
      _logReportViewed();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.getTitle(context)),
        actions: dataAsync.whenOrNull(
          data: (data) => widget.buildActions(context, ref, data),
        ),
      ),
      body: dataAsync.when(
        data: (data) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              widget.buildContent(context, ref, data),
              const SizedBox(height: AppSpacing.fabBottomPadding),
            ],
          ),
        ),
        loading: () => widget.buildLoadingState(context),
        error: (e, st) => widget.buildErrorState(context, e, st),
      ),
    );
  }

  /// Log report viewed analytics event
  Future<void> _logReportViewed() async {
    final isHistorical = widget.isHistoricalReport();
    final period = widget.getPeriodIdentifier();

    // Log based on historical status
    if (isHistorical && period != null) {
      // Parse period to calculate periods back
      final periodsBack = _calculatePeriodsBack(period);
      await _analytics.logHistoricalReportAccessed(
        reportType: widget.getReportType(),
        periodsBack: periodsBack,
        period: period,
      );
    }

    // Always log general report viewed event
    await _analytics.logReportViewed(
      reportType: widget.getReportType(),
      isHistorical: isHistorical,
      period: period,
    );
  }

  /// Calculate how many periods back from current
  int _calculatePeriodsBack(String period) {
    final now = DateTime.now();

    // For FY periods (YYYY format)
    if (period.length == 4) {
      final year = int.tryParse(period) ?? 0;
      final currentFYYear = now.month >= 4 ? now.year : now.year - 1;
      return currentFYYear - year;
    }

    // For monthly periods (YYYY-MM format)
    if (period.contains('-') && period.length == 7) {
      final parts = period.split('-');
      final year = int.tryParse(parts[0]) ?? 0;
      final month = int.tryParse(parts[1]) ?? 0;
      final periodDate = DateTime(year, month);
      final monthsDiff = (now.year - periodDate.year) * 12 + (now.month - periodDate.month);
      return monthsDiff;
    }

    return 0;
  }
}
