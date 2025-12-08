import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';

/// A beautiful gradient card widget with optional glow effect
class GradientCard extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool showGlow;
  final VoidCallback? onTap;

  const GradientCard({
    super.key,
    required this.child,
    this.gradient,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 20,
    this.showGlow = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardGradient = gradient ?? AppColors.heroGradient;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: (cardGradient.colors.first).withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: (cardGradient.colors.last).withValues(alpha: 0.2),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Ink(
            decoration: BoxDecoration(
              gradient: cardGradient,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A glass-morphism style card with frosted effect
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? borderColor;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 16,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: isDark 
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.7),
        border: Border.all(
          color: borderColor ?? 
            (isDark 
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.8)),
          width: 1,
        ),
        boxShadow: isDark ? null : AppColors.cardShadowLight,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

