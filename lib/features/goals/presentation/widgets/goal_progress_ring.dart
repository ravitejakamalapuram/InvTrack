import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';

/// Circular progress ring for goal progress visualization
class GoalProgressRing extends StatelessWidget {
  final double progress; // 0-100
  final double size;
  final Color color;
  final double strokeWidth;
  final bool showPercentage;

  const GoalProgressRing({
    super.key,
    required this.progress,
    this.size = 60,
    required this.color,
    this.strokeWidth = 6,
    this.showPercentage = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.08);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: 100,
              color: bgColor,
              strokeWidth: strokeWidth,
            ),
          ),
          // Progress ring
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: progress,
              color: color,
              strokeWidth: strokeWidth,
            ),
          ),
          // Percentage text
          if (showPercentage)
            Text(
              '${progress.toInt()}%',
              style: AppTypography.small.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.neutral900Light,
                fontSize: size * 0.22,
              ),
            ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress; // 0-100
  final Color color;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw arc starting from top (- π/2 radians)
    final sweepAngle = (progress / 100) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start from top
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Large progress ring for goal detail screen
class GoalProgressRingLarge extends StatelessWidget {
  final double progress;
  final Color color;
  final String currentAmount;
  final String targetAmount;

  const GoalProgressRingLarge({
    super.key,
    required this.progress,
    required this.color,
    required this.currentAmount,
    required this.targetAmount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          GoalProgressRing(
            progress: progress,
            size: 180,
            color: color,
            strokeWidth: 12,
            showPercentage: false,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${progress.toInt()}%',
                style: AppTypography.h1.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.neutral900Light,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                currentAmount,
                style: AppTypography.bodyMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'of $targetAmount',
                style: AppTypography.small.copyWith(
                  color: isDark
                      ? AppColors.neutral400Dark
                      : AppColors.neutral500Light,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
