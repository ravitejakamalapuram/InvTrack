import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';

class AssetAllocationChart extends StatelessWidget {
  final Map<String, double> allocation;

  const AssetAllocationChart({
    super.key,
    required this.allocation,
  });

  @override
  Widget build(BuildContext context) {
    if (allocation.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final total = allocation.values.fold(0.0, (sum, val) => sum + val);
    
    // Generate colors
    final colors = [
      AppColors.graphBlue,
      AppColors.graphPurple,
      AppColors.graphPink,
      AppColors.graphAmber,
      AppColors.graphEmerald,
      AppColors.graphCyan,
      AppColors.graphOrange,
    ];

    int colorIndex = 0;
    final sections = allocation.entries.map((entry) {
      final percentage = (entry.value / total) * 100;
      final color = colors[colorIndex % colors.length];
      colorIndex++;

      return PieChartSectionData(
        color: color,
        value: entry.value,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return Row(
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    // Handle touch
                  },
                ),
                borderData: FlBorderData(show: false),
                sectionsSpace: 0,
                centerSpaceRadius: 40,
                sections: sections,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: allocation.entries.map((entry) {
            final index = allocation.keys.toList().indexOf(entry.key);
            final color = colors[index % colors.length];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    entry.key,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
