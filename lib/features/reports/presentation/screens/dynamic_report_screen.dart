library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:inv_tracker/features/reports/domain/entities/report_configuration.dart';
import 'package:inv_tracker/features/reports/domain/entities/dynamic_report_data.dart';
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Render section content based on type
            _buildSectionContent(context, section),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionContent(BuildContext context, dynamic section) {
    // Import the section type enum
    final sectionType = section.type.toString();

    // Handle different section types
    if (sectionType.contains('kpiGrid')) {
      return _buildKpiGrid(context, section.data as List);
    } else if (sectionType.contains('kpiCard')) {
      return _buildKpiCard(context, section.data);
    } else if (sectionType.contains('itemList')) {
      return _buildItemList(context, section.data as List);
    } else if (sectionType.contains('textSummary')) {
      return _buildTextSummary(context, section.data as String);
    } else {
      // Fallback for unimplemented types
      return Text(
        'Content type not yet implemented: $sectionType',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Widget _buildKpiGrid(BuildContext context, List kpiDataList) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: kpiDataList.map((kpiData) {
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 80) / 2,
          child: _buildKpiCard(context, kpiData),
        );
      }).toList(),
    );
  }

  Widget _buildKpiCard(BuildContext context, dynamic kpiData) {
    // Cast to proper type
    final kpi = kpiData as KpiData;
    final label = kpi.label;
    final value = kpi.value;
    final trend = kpi.trend;
    final isTrendPositive = kpi.isTrendPositive;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (trend != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  isTrendPositive == true
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                  size: 16,
                  color: isTrendPositive == true
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 4),
                Text(
                  trend,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isTrendPositive == true
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemList(BuildContext context, List items) {
    if (items.isEmpty) {
      return Text(
        'No items to display',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
        ),
      );
    }

    return Column(
      children: items.map((item) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(item.toString()),
          dense: true,
        );
      }).toList(),
    );
  }

  Widget _buildTextSummary(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }

  Widget _buildEmptyState(BuildContext context, String? message) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 80,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 24),
            Text(
              message ?? l10n.noDataForReport,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.startTrackingToSeeReports,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                // Navigate to add investment screen
                context.push('/investments/add');
              },
              icon: const Icon(Icons.add),
              label: Text(l10n.addYourFirstInvestment),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                // Navigate back to reports home
                context.pop();
              },
              child: Text(l10n.viewPastReports),
            ),
          ],
        ),
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
