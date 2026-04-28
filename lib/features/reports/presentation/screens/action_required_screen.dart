/// Action Required Screen
///
/// Shows actionable items requiring user attention
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/features/reports/domain/entities/action_required_report.dart';
import 'package:inv_tracker/features/reports/domain/services/report_export_service.dart';
import 'package:inv_tracker/features/reports/presentation/providers/action_required_provider.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/base_report_screen.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/report_stat_card.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/report_export_button.dart';

class ActionRequiredScreen extends BaseReportScreen<ActionRequiredReport> {
  const ActionRequiredScreen({super.key});

  @override
  String getTitle(BuildContext context) {
    return 'Action Required';
  }

  @override
  FutureProvider<ActionRequiredReport> getDataProvider(WidgetRef ref) {
    return actionRequiredReportProvider;
  }

  @override
  List<Widget> buildActions(BuildContext context, WidgetRef ref, ActionRequiredReport data) {
    return [
      ReportExportButton(
        reportData: data,
        reportType: ReportType.actionRequired,
      ),
    ];
  }

  @override
  Widget buildContent(
    BuildContext context,
    WidgetRef ref,
    ActionRequiredReport report,
  ) {
    if (report.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 64,
              color: Colors.green.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'All Clear!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'No actions required at this time.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Stats
        Row(
          children: [
            Expanded(
              child: ReportStatCard(
                icon: Icons.warning_rounded,
                label: 'Total Actions',
                value: '${report.totalActions}',
                iconColor: report.hasUrgentActions ? Colors.red : Colors.blue,
                isPrivacySensitive: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ReportStatCard(
                icon: Icons.error_rounded,
                label: 'Urgent',
                value:
                    '${report.criticalActions.length + report.highPriorityActions.length}',
                iconColor: Colors.red,
                isPrivacySensitive: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (report.overdueActions > 0)
          ReportStatCard(
            icon: Icons.alarm_rounded,
            label: 'Overdue Actions',
            value: '${report.overdueActions}',
            iconColor: Colors.red.shade700,
            isPrivacySensitive: false,
          ),

        const SizedBox(height: 24),

        // Critical Actions
        if (report.criticalActions.isNotEmpty) ...[
          _buildActionSection(
            context,
            '\u26a0\ufe0f Critical Actions',
            report.criticalActions,
            Colors.red,
          ),
          const SizedBox(height: 24),
        ],

        // High Priority Actions
        if (report.highPriorityActions.isNotEmpty) ...[
          _buildActionSection(
            context,
            '\ud83d\udd34 High Priority',
            report.highPriorityActions,
            Colors.orange,
          ),
          const SizedBox(height: 24),
        ],

        // Medium Priority Actions
        if (report.mediumPriorityActions.isNotEmpty) ...[
          _buildActionSection(
            context,
            '\ud83d\udfe1 Medium Priority',
            report.mediumPriorityActions,
            Colors.amber,
          ),
          const SizedBox(height: 24),
        ],

        // Low Priority Actions
        if (report.lowPriorityActions.isNotEmpty) ...[
          _buildActionSection(
            context,
            '\ud83d\udd35 Low Priority',
            report.lowPriorityActions,
            Colors.blue,
          ),
        ],
      ],
    );
  }

  Widget _buildActionSection(
    BuildContext context,
    String title,
    List<ActionItem> items,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        ...items.map((item) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                _getActionIcon(item.type),
                color: color,
                size: 32,
              ),
              title: Text(item.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.description),
                  if (item.dueDate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Due: ${DateFormat('MMM dd, yyyy').format(item.dueDate!)}${item.isOverdue ? ' (OVERDUE)' : ''}',
                      style: TextStyle(
                        color: item.isOverdue ? Colors.red : color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
              trailing: item.daysUntilDue != null
                  ? Chip(
                      label: Text(
                        item.isOverdue
                            ? '${-item.daysUntilDue!}d ago'
                            : '${item.daysUntilDue}d',
                        style: TextStyle(
                          color: item.isOverdue ? Colors.white : color,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor:
                          item.isOverdue ? Colors.red : color.withValues(alpha: 0.2),
                    )
                  : null,
            ),
          );
        }),
      ],
    );
  }

  IconData _getActionIcon(ActionType type) {
    switch (type) {
      case ActionType.maturity:
        return Icons.event_rounded;
      case ActionType.idle:
        return Icons.access_time_rounded;
      case ActionType.goalAtRisk:
        return Icons.flag_rounded;
      case ActionType.taxDeadline:
        return Icons.receipt_long_rounded;
      case ActionType.underperforming:
        return Icons.trending_down_rounded;
    }
  }
}
