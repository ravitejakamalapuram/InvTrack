/// Privacy mask widgets for hiding sensitive financial data.
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';

/// A widget that masks its child when privacy mode is enabled.
/// Uses an animated blur effect with a stylish masked pattern.
class PrivacyMask extends ConsumerWidget {
  /// The child widget to potentially mask.
  final Widget child;

  /// Whether to use a simple text replacement instead of blur.
  /// If true, shows masked text (•••••) instead of blur effect.
  final bool useTextMask;

  /// Masked text to show when [useTextMask] is true.
  final String? maskedText;

  /// Style for the masked text.
  final TextStyle? maskedTextStyle;

  /// Width constraint for the mask (useful for text placeholders).
  final double? width;

  const PrivacyMask({
    super.key,
    required this.child,
    this.useTextMask = false,
    this.maskedText,
    this.maskedTextStyle,
    this.width,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPrivacyMode = ref.watch(privacyModeProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: isPrivacyMode
          ? _buildMaskedContent(context)
          : KeyedSubtree(key: const ValueKey('visible'), child: child),
    );
  }

  Widget _buildMaskedContent(BuildContext context) {
    if (useTextMask) {
      return Text(
        maskedText ?? '••••••',
        key: const ValueKey('masked'),
        style: maskedTextStyle,
      );
    }

    return ClipRRect(
      key: const ValueKey('masked'),
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: width,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: child,
        ),
      ),
    );
  }
}

/// A masked amount text widget that integrates with privacy mode.
/// Shows a stylish blur or pattern when privacy is enabled.
class MaskedAmountText extends ConsumerWidget {
  /// The text to display when visible.
  final String text;

  /// Text style.
  final TextStyle? style;

  /// Maximum lines.
  final int? maxLines;

  /// Text overflow behavior.
  final TextOverflow? overflow;

  /// Text alignment.
  final TextAlign? textAlign;

  const MaskedAmountText({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPrivacyMode = ref.watch(privacyModeProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: isPrivacyMode
          ? _MaskedText(
              key: const ValueKey('masked'),
              style: style,
              maxLines: maxLines,
              overflow: overflow,
              textAlign: textAlign,
            )
          : Text(
              text,
              key: const ValueKey('visible'),
              style: style,
              maxLines: maxLines,
              overflow: overflow,
              textAlign: textAlign,
            ),
    );
  }
}

/// Internal widget for displaying masked text pattern.
class _MaskedText extends StatelessWidget {
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const _MaskedText({
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    // Use a stylish asterisk pattern
    final effectiveStyle = style ?? const TextStyle();
    final fontSize = effectiveStyle.fontSize ?? 14;

    // Determine number of dots based on font size
    final dotCount = fontSize > 24 ? 6 : 5;
    final maskedPattern = '•' * dotCount;

    return ShaderMask(
      shaderCallback: (bounds) {
        return const LinearGradient(
          colors: [
            Colors.white,
            Colors.white70,
            Colors.white,
          ],
          stops: [0.0, 0.5, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.srcIn,
      child: Text(
        maskedPattern,
        style: effectiveStyle.copyWith(
          letterSpacing: 2,
        ),
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
      ),
    );
  }
}

