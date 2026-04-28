/// Maturity Calendar Screen
///
/// Shows upcoming investment maturities in timeline view
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/features/reports/domain/entities/maturity_calendar_report.dart';
import 'package:inv_tracker/features/reports/domain/services/report_export_service.dart';
import 'package:inv_tracker/features/reports/presentation/providers/maturity_calendar_provider.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/base_report_screen.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/report_stat_card.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/report_export_button.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class MaturityCalendarScreen extends BaseReportScreen<MaturityCalendarReport> {
  const MaturityCalendarScreen({super.key});

  @override
  String getTitle(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return l10n.maturityCalendarTitle;
  }

  @override
  FutureProvider<MaturityCalendarReport> getDataProvider(WidgetRef ref) {
    return maturityCalendarReportProvider;
  }

  @override
  List<Widget> buildActions(BuildContext context, WidgetRef ref, MaturityCalendarReport data) {
    return [
      ReportExportButton(
        reportData: data,
        reportType: ReportType.maturityCalendar,
      ),
    ];
  }

  @override
  Widget buildContent(
    BuildContext context,
    WidgetRef ref,
    MaturityCalendarReport report,
  ) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(currencyLocaleProvider);
    final symbol = ref.watch(currencySymbolProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Stats
        Text(
          'Maturity Overview',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ReportStatCard(
                icon: Icons.event_rounded,
                label: l10n.totalWithMaturity,
                value: '${report.totalInvestments}',
                iconColor: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PrivacyMask(
                child: ReportStatCard(
                  icon: Icons.schedule_rounded,
                  label: l10n.next30Days,
                  value: formatCompactCurrency(
                    report.totalUpcoming30Days,
                    symbol: symbol,
                    locale: locale,
                  ),
                  iconColor: Colors.orange,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PrivacyMask(
          child: ReportStatCard(
            icon: Icons.calendar_month_rounded,
            label: l10n.next90DaysTotal,
            value: formatCompactCurrency(
              report.totalNext90Days,
              symbol: symbol,
              locale: locale,
            ),
            iconColor: Colors.green,
          ),
        ),

        const SizedBox(height: 24),

        // Upcoming 30 Days
        if (report.upcoming30Days.isNotEmpty) ...[
          _buildMaturitySection(
            context,
            '⏰ Maturing in Next 30 Days',
            report.upcoming30Days,
            symbol,
            locale,
          ),
          const SizedBox(height: 24),
        ],

        // Next 90 Days
        if (report.next90Days.isNotEmpty) ...[
          _buildMaturitySection(
            context,
            '📅 Maturing in 31-90 Days',
            report.next90Days,
            symbol,
            locale,
          ),
          const SizedBox(height: 24),
        ],

        // Beyond 90 Days
        if (report.beyond90Days.isNotEmpty) ...[
          _buildMaturitySection(
            context,
            '🗓️ Maturing Beyond 90 Days',
            report.beyond90Days,
            symbol,
            locale,
          ),
        ],
      ],
    );
  }

  Widget _buildMaturitySection(
    BuildContext context,
    String title,
    List<MaturityItem> items,
    String symbol,
    String locale,
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
          final urgencyColor = _getUrgencyColor(item.urgency);
          final dateFormat = DateFormat('MMM dd, yyyy');

          return Card(
            child: ListTile(
              leading: Icon(
                _getUrgencyIcon(item.urgency),
                color: urgencyColor,
                size: 32,
              ),
              title: Text(item.investment.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${l10n.maturesLabel}: ${dateFormat.format(item.maturityDate)}'),
                  Text(
                    '${item.daysUntilMaturity} days remaining',
                    style: TextStyle(color: urgencyColor),
                  ),
                ],
              ),
              trailing: PrivacyMask(
                child: Text(
                  formatCompactCurrency(
                    item.maturityAmount,
                    symbol: symbol,
                    locale: locale,
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Color _getUrgencyColor(MaturityUrgency urgency) {
    switch (urgency) {
      case MaturityUrgency.critical:
        return Colors.red;
      case MaturityUrgency.warning:
        return Colors.orange;
      case MaturityUrgency.normal:
        return Colors.blue;
      case MaturityUrgency.low:
        return Colors.grey;
    }
  }

  IconData _getUrgencyIcon(MaturityUrgency urgency) {
    switch (urgency) {
      case MaturityUrgency.critical:
        return Icons.error_rounded;
      case MaturityUrgency.warning:
        return Icons.warning_rounded;
      case MaturityUrgency.normal:
        return Icons.info_rounded;
      case MaturityUrgency.low:
        return Icons.schedule_rounded;
    }
  }
}
