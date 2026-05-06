library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/reports/domain/entities/report_configuration.dart';
import 'package:inv_tracker/features/reports/presentation/providers/dynamic_report_provider.dart';

/// Dynamic Report Screen - Unified view for all report types
///
/// Uses ReportBuilderService to generate reports on-the-fly based on configuration.
/// Handles empty states, errors, and dynamic section rendering.
class DynamicReportScreen extends ConsumerWidget {
  final ReportConfiguration configuration;

  const DynamicReportScreen({super.key, required this.configuration});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(dynamicReportProvider(configuration));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          // Use report.title for localized/customized titles
          reportAsync.maybeWhen(
            data: (report) => report.title,
            orElse: () => configuration.titleOverride ?? 'Report',
          ),
        ),
      ),
      body: reportAsync.when(
        data: (report) => _buildReportBody(context, ref, report),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(context, ref, error),
      ),
    );
  }

  Widget _buildReportBody(BuildContext context, WidgetRef ref, dynamic report) {
    // Check if report has data
    if (!report.hasData) {
      return _buildEmptyState(context, report.emptyStateMessage);
    }

    // Dynamically render sections
    if (report.sections.isEmpty) {
      return _buildEmptyState(
        context,
        report.emptyStateMessage ?? 'No sections to display',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: report.sections.length,
      itemBuilder: (context, index) {
        final section = report.sections[index];
        return _buildSection(context, section);
      },
    );
  }

  Widget _buildSection(BuildContext context, dynamic section) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section title
            Text(
              section.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (section.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                section.subtitle!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            // Section data (placeholder for now)
            Text('Section Type: ${section.type}'),
            Text('Data: ${section.data.toString()}'),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String? message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 64,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 16),
          Text(
            message ?? 'No data available for this report',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting the date range or filters',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load report',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Retry by invalidating the provider
              ref.invalidate(dynamicReportProvider(configuration));
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
