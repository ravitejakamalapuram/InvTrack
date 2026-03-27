/// Privacy toggle button widget for showing/hiding sensitive data.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';

/// A beautiful animated eye icon button for toggling privacy mode.
/// Features smooth animations and haptic feedback.
class PrivacyToggleButton extends ConsumerStatefulWidget {
  /// Size of the icon.
  final double iconSize;

  /// Color of the icon. Defaults to white with opacity.
  final Color? iconColor;

  /// Whether to show a background container.
  final bool showBackground;

  /// Background color when [showBackground] is true.
  final Color? backgroundColor;

  const PrivacyToggleButton({
    super.key,
    this.iconSize = 20,
    this.iconColor,
    this.showBackground = true,
    this.backgroundColor,
  });

  @override
  ConsumerState<PrivacyToggleButton> createState() =>
      _PrivacyToggleButtonState();
}

class _PrivacyToggleButtonState extends ConsumerState<PrivacyToggleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    HapticFeedback.lightImpact();
    await _controller.forward();
    await ref.read(privacyModeProvider.notifier).toggle();
    await _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isPrivacyMode = ref.watch(privacyModeProvider);
    final effectiveIconColor =
        widget.iconColor ?? Colors.white.withValues(alpha: 0.9);

    final iconButton = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value * (isPrivacyMode ? -1 : 1),
            child: child,
          ),
        );
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          return ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: Icon(
          isPrivacyMode
              ? Icons.visibility_off_rounded
              : Icons.visibility_rounded,
          key: ValueKey(isPrivacyMode),
          size: widget.iconSize,
          color: effectiveIconColor,
        ),
      ),
    );

    if (!widget.showBackground) {
      return Semantics(
        button: true,
        label: isPrivacyMode ? 'Show amounts' : 'Hide amounts',
        child: Tooltip(
          message: isPrivacyMode ? 'Show amounts' : 'Hide amounts',
          excludeFromSemantics: true,
          child: GestureDetector(
            onTap: _handleTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(padding: const EdgeInsets.all(8), child: iconButton),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: isPrivacyMode ? 'Show amounts' : 'Hide amounts',
      child: Tooltip(
        message: isPrivacyMode ? 'Show amounts' : 'Hide amounts',
        excludeFromSemantics: true,
        child: GestureDetector(
          onTap: _handleTap,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: isPrivacyMode ? 1.0 : 0.0),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              final bgColor =
                  widget.backgroundColor ??
                  Color.lerp(
                    Colors.white.withValues(alpha: 0.15),
                    Colors.white.withValues(alpha: 0.25),
                    value,
                  )!;
              final shadowOpacity = 0.2 * value;

              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                  boxShadow: value > 0.01
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: shadowOpacity,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: iconButton,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A compact privacy toggle for use in app bars or tight spaces.
class CompactPrivacyToggle extends ConsumerWidget {
  /// Icon size.
  final double size;

  /// Icon color.
  final Color? color;

  const CompactPrivacyToggle({super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPrivacyMode = ref.watch(privacyModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor =
        color ??
        (isDark ? Colors.white.withValues(alpha: 0.8) : Colors.black87);

    return IconButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        ref.read(privacyModeProvider.notifier).toggle();
      },
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          isPrivacyMode
              ? Icons.visibility_off_rounded
              : Icons.visibility_rounded,
          key: ValueKey(isPrivacyMode),
          size: size,
          color: effectiveColor,
        ),
      ),
      tooltip: isPrivacyMode ? 'Show amounts' : 'Hide amounts',
    );
  }
}
