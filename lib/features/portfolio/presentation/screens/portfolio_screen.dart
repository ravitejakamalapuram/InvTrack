import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Portfolio', style: AppTypography.h3),
      ),
      body: const Center(
        child: Text('Portfolio Analytics Coming Soon'),
      ),
    );
  }
}
