import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/presentation/extensions/fire_entity_ui_extensions.dart';

/// Animated progress ring for FIRE progress visualization
class FireProgressRing extends ConsumerWidget {
  final double progress;
  final double fireNumber;
  final double currentValue;
  final String currencySymbol;
  final FireProgressStatus status;
  final double size;
  final double strokeWidth;

  const FireProgressRing({
    super.key,
    required this.progress,
    required this.fireNumber,
    required this.currentValue,
    required this.currencySymbol,
    required this.status,
    this.size = 200,
    this.strokeWidth = 14,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? AppColors.neutral700Dark
        : AppColors.neutral200Light;
    final progressColor = status.color;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring - wrapped in RepaintBoundary to isolate repaints
          RepaintBoundary(
            child: CustomPaint(
              size: Size(size, size),
              painter: _FireRingPainter(
                progress: 100,
                color: bgColor,
                strokeWidth: strokeWidth,
              ),
            ),
          ),
          // Progress ring with gradient - wrapped in RepaintBoundary
          RepaintBoundary(
            child: CustomPaint(
              size: Size(size, size),
              painter: _FireRingPainter(
                progress: progress.clamp(0, 100),
                color: progressColor,
                strokeWidth: strokeWidth,
                useGradient: true,
              ),
            ),
          ),
          // Center content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Fire icon
              Icon(Icons.local_fire_department, size: 32, color: progressColor),
              SizedBox(height: AppSpacing.xxs),
              // Percentage
              Text(
                '${progress.toInt()}%',
                style: AppTypography.displaySmall.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.neutral900Light,
                ),
              ),
              SizedBox(height: AppSpacing.xxs),
              // Current value - privacy aware
              MaskedAmountText(
                text: formatCompactIndian(currentValue, symbol: currencySymbol),
                style: AppTypography.bodyMedium.copyWith(
                  color: progressColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              // Target - privacy aware
              MaskedAmountText(
                text:
                    'of ${formatCompactIndian(fireNumber, symbol: currencySymbol)}',
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

/// Custom painter for the FIRE progress ring
class _FireRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;
  final bool useGradient;

  _FireRingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
    this.useGradient = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final startAngle = -math.pi / 2; // Start from top
    final sweepAngle = 2 * math.pi * (progress / 100);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (useGradient && progress > 0) {
      // Create gradient for progress
      final gradient = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: [
          color.withValues(alpha: 0.6),
          color,
          color.withValues(alpha: 0.8),
        ],
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(startAngle),
      );
      paint.shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      );
    } else {
      paint.color = color;
    }

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _FireRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
