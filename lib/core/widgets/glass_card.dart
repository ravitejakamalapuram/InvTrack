import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';

/// A premium glassmorphism card widget with blur effect and subtle border.
/// Inspired by CRED's design language.
class GlassCard extends StatefulWidget {
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
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultBgColor = isDark
        ? AppColors.cardDark.withValues(alpha: 0.8)
        : AppColors.cardLight.withValues(alpha: 0.9);

    final defaultBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);

    // Focus state overrides border
    final borderColor =
        _isFocused
            ? (isDark ? AppColors.primaryLightDark : AppColors.primaryLight)
            : defaultBorderColor;
    final borderWidth = _isFocused ? 2.0 : 1.0;

    final decoration = BoxDecoration(
      color: widget.backgroundColor ?? defaultBgColor,
      borderRadius: BorderRadius.circular(widget.borderRadius),
      border:
          (widget.showBorder || _isFocused)
              ? Border.all(color: borderColor, width: borderWidth)
              : null,
      boxShadow:
          (_isFocused && !isDark)
              ? [
                BoxShadow(
                  color: AppColors.primaryLight.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
                ...AppColors.cardShadowLight,
              ]
              : (isDark ? null : AppColors.cardShadowLight),
    );

    // OPTIMIZATION: Skip expensive BackdropFilter if blur is 0.
    // BackdropFilter forces a saveLayer which triggers an offscreen render pass.
    // When blur is not needed (or set to 0 for performance), we can render a simple container.
    Widget cardContent;
    if (widget.blur > 0) {
      cardContent = ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
          child: Container(
            padding: widget.padding,
            // OPTIMIZATION: Remove shadow when blurred because ClipRRect clips it anyway.
            decoration: decoration.copyWith(boxShadow: []),
            child: widget.child,
          ),
        ),
      );
    } else {
      // Use ClipRRect to ensure child content is clipped to the border radius,
      // matching the behavior of the blurred version.
      cardContent = ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Container(
          padding: widget.padding,
          // OPTIMIZATION: Remove shadow when blur is 0 because ClipRRect clips it anyway.
          // This avoids calculating expensive shadows (blur radius 24) that are invisible.
          decoration: decoration.copyWith(boxShadow: []),
          child: widget.child,
        ),
      );
    }

    if (widget.onTap != null || widget.onLongPress != null) {
      final bool hasCustomLabel = widget.semanticLabel != null;
      return Focus(
        onFocusChange: (value) => setState(() => _isFocused = value),
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space)) {
            if (widget.onTap != null) {
              HapticFeedback.lightImpact();
              widget.onTap!();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Semantics(
          button: true,
          label: widget.semanticLabel,
          selected: widget.selected,
          excludeSemantics: hasCustomLabel,
          onTap: hasCustomLabel ? widget.onTap : null,
          onLongPress: hasCustomLabel ? widget.onLongPress : null,
          child: GestureDetector(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            child: cardContent,
          ),
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
