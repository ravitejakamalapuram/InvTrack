import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';

/// A premium glassmorphism card widget with blur effect and subtle border.
/// Inspired by CRED's design language.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? backgroundColor;
  final double blur;
  final bool showBorder;
  final String? semanticLabel;
  final bool? selected;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
    this.onTap,
    this.onLongPress,
    this.backgroundColor,
    this.blur = 10,
    this.showBorder = true,
    this.semanticLabel,
    this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultBgColor = isDark
        ? AppColors.cardDark.withValues(alpha: 0.8)
        : AppColors.cardLight.withValues(alpha: 0.9);

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);

    final decoration = BoxDecoration(
      color: backgroundColor ?? defaultBgColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: showBorder ? Border.all(color: borderColor, width: 1) : null,
      boxShadow: isDark ? null : AppColors.cardShadowLight,
    );

    // OPTIMIZATION: Skip expensive BackdropFilter if blur is 0.
    // BackdropFilter forces a saveLayer which triggers an offscreen render pass.
    // When blur is not needed (or set to 0 for performance), we can render a simple container.
    Widget cardContent;
    if (blur > 0) {
      cardContent = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            // OPTIMIZATION: Remove shadow when blurred because ClipRRect clips it anyway.
            decoration: decoration.copyWith(boxShadow: []),
            child: child,
          ),
        ),
      );
    } else {
      // Use ClipRRect to ensure child content is clipped to the border radius,
      // matching the behavior of the blurred version.
      cardContent = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          padding: padding,
          // OPTIMIZATION: Remove shadow when blur is 0 because ClipRRect clips it anyway.
          // This avoids calculating expensive shadows (blur radius 24) that are invisible.
          decoration: decoration.copyWith(boxShadow: []),
          child: child,
        ),
      );
    }

    if (onTap != null || onLongPress != null) {
      final bool hasCustomLabel = semanticLabel != null;
      return Semantics(
        button: true,
        label: semanticLabel,
        selected: selected,
        excludeSemantics: hasCustomLabel,
        onTap: hasCustomLabel ? onTap : null,
        onLongPress: hasCustomLabel ? onLongPress : null,
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}

/// A variant of GlassCard with a gradient overlay for hero sections.
class GlassHeroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final LinearGradient? gradient;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool? selected;

  const GlassHeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24,
    this.gradient,
    this.onTap,
    this.semanticLabel,
    this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultGradient = isDark
        ? AppColors.heroGradientDark
        : AppColors.heroGradient;

    Widget cardContent = Container(
      decoration: BoxDecoration(
        gradient: gradient ?? defaultGradient,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryLight.withValues(alpha: isDark ? 0.2 : 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          children: [
            // Subtle pattern overlay
            Positioned.fill(
              child: CustomPaint(painter: _GlowPatternPainter(isDark: isDark)),
            ),
            // Content
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );

    if (onTap != null) {
      final bool hasCustomLabel = semanticLabel != null;
      return Semantics(
        button: true,
        label: semanticLabel,
        selected: selected,
        excludeSemantics: hasCustomLabel,
        onTap: hasCustomLabel ? onTap : null,
        child: GestureDetector(onTap: onTap, child: cardContent),
      );
    }

    return cardContent;
  }
}

class _GlowPatternPainter extends CustomPainter {
  final bool isDark;

  _GlowPatternPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: isDark ? 0.03 : 0.1)
      ..style = PaintingStyle.fill;

    // Top-right glow
    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.1),
      size.width * 0.3,
      paint,
    );

    // Bottom-left subtle glow
    paint.color = Colors.white.withValues(alpha: isDark ? 0.02 : 0.05);
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.9),
      size.width * 0.25,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
