import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';

/// Analytics screen placeholder.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.analytics_outlined, size: 80, color: Colors.grey[400]),
              AppSpacing.gapVerticalXl,
              Text('Analytics Coming Soon', style: Theme.of(context).textTheme.titleLarge),
              AppSpacing.gapVerticalSm,
              Text(
                'XIRR, CAGR, MOIC calculations and charts will be available here',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

