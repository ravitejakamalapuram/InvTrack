/// Base scaffold for report screens with common structure
///
/// Provides:
/// - Consistent AppBar with title and actions
/// - Loading/Error/Data states via AsyncValue
/// - Scroll view with padding
/// - Export/Share actions (optional)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/widgets/loading_skeletons.dart';

/// Base report screen for code reuse
abstract class BaseReportScreen<T> extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(getDataProvider(ref));

    return Scaffold(
      appBar: AppBar(
        title: Text(getTitle(context)),
        actions: dataAsync.whenOrNull(
          data: (data) => buildActions(context, ref, data),
        ),
      ),
      body: dataAsync.when(
        data: (data) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildContent(context, ref, data),
              const SizedBox(height: AppSpacing.fabBottomPadding),
            ],
          ),
        ),
        loading: () => buildLoadingState(context),
        error: (e, st) => buildErrorState(context, e, st),
      ),
    );
  }
}
