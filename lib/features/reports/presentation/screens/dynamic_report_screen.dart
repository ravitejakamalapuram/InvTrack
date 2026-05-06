library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/reports/domain/entities/report_configuration.dart';
import 'package:inv_tracker/features/reports/presentation/providers/dynamic_report_provider.dart';

class DynamicReportScreen extends ConsumerWidget {
  final ReportConfiguration configuration;

  const DynamicReportScreen({super.key, required this.configuration});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(dynamicReportProvider(configuration));

    return Scaffold(
      appBar: AppBar(title: Text(configuration.reportType.name)),
      body: reportAsync.when(
        data: (report) => Center(child: Text('Report: ${configuration.reportType.id}')),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
