import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_sizes.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';

/// A generic type selector widget that displays selectable chips in a wrap layout.
///
/// Supports haptic feedback, animated transitions, and gradient styling.
/// Now with improved layout options for better UX and accessibility.
///
/// The layout is a wrap (default), a two-column grid ([gridLayout]) or one
/// row that scrolls sideways ([scrollingRow]).
class TypeSelector<T> extends StatelessWidget {
  final String? label;
  final String? subtitle;
  final List<T> values;
  final T selectedValue;
  final ValueChanged<T> onSelected;
  final Color Function(T item) colorBuilder;
  final IconData Function(T item) iconBuilder;
  final String Function(T item) labelBuilder;
  final double spacing;
  final double runSpacing;

  /// If true, uses a more compact chip style (icon only visible when selected)
  final bool compactMode;

  /// If true, chips are sized to fit a 2-column grid layout
  final bool gridLayout;

  /// If true, the chips are one row that scrolls sideways, each at least
  /// [AppSizes.minTouchTarget] wide and high, with [rowPadding] before the
  /// first chip and after the last, so the next chip peeks at the edge. The
  /// selected chip is scrolled into view when it is chosen, and when the row
  /// is built with one that is off screen. Cannot be combined with
  /// [gridLayout].
  final bool scrollingRow;

  /// Space before the first chip and after the last of a [scrollingRow]. The
  /// row itself is as wide as its parent, so it can run to the screen edge.
  final EdgeInsetsGeometry rowPadding;

  /// What a screen reader says about a [scrollingRow] as a group, before its
  /// chips, for example "Investment type, 14 choices. Scroll sideways to see
  /// all."
  final String? rowSemanticsLabel;

  /// A key for the chip of an item, in every layout. Tests and the
  /// integration robot find a chip by it.
  final Key Function(T item)? itemKeyBuilder;

  const TypeSelector({
    super.key,
    this.label,
    this.subtitle,
    required this.values,
    required this.selectedValue,
    required this.onSelected,
    required this.colorBuilder,
    required this.iconBuilder,
    required this.labelBuilder,
    this.spacing = 10,
    this.runSpacing = 10,
    this.compactMode = false,
    this.gridLayout = false,
    this.scrollingRow = false,
    this.rowPadding = EdgeInsets.zero,
    this.rowSemanticsLabel,
    this.itemKeyBuilder,
  }) : assert(
         !(gridLayout && scrollingRow),
         'A grid layout cannot also be a scrolling row',
       );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.neutral900Light,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: AppTypography.caption.copyWith(
                color: isDark
                    ? AppColors.neutral400Dark
                    : AppColors.neutral500Light,
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
        gridLayout
            ? _buildGridLayout(isDark)
            : scrollingRow
            ? _buildScrollingRow(isDark)
            : _buildWrapLayout(isDark),
      ],
    );
  }

  Widget _buildWrapLayout(bool isDark) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: values.map((item) => _buildChip(item, isDark)).toList(),
    );
  }

  Widget _buildScrollingRow(bool isDark) {
    return _ScrollingChipRow<T>(
      values: values,
      selectedValue: selectedValue,
      padding: rowPadding,
      spacing: spacing,
      semanticsLabel: rowSemanticsLabel,
      chipBuilder: (item) => _buildChip(item, isDark, scrolling: true),
    );
  }

  Widget _buildGridLayout(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final chipWidth = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: values.map((item) {
            return SizedBox(
              width: chipWidth,
              child: _buildChip(item, isDark, expanded: true),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildChip(
    T item,
    bool isDark, {
    bool expanded = false,
    bool scrolling = false,
  }) {
    final isSelected = selectedValue == item;
    final color = colorBuilder(item);
    final itemLabel = labelBuilder(item);

    return Semantics(
      key: itemKeyBuilder?.call(item),
      button: true,
      selected: isSelected,
      label: itemLabel,
      excludeSemantics: true,
      onTap: () {
        HapticFeedback.selectionClick();
        onSelected(item);
      },
      child: _AccessibleChip(
        onTap: () {
          HapticFeedback.selectionClick();
          onSelected(item);
        },
        builder: (context, isFocused) => _TypeSelectorChip(
          isSelected: isSelected,
          isFocused: isFocused,
          color: color,
          isDark: isDark,
          expanded: expanded,
          compactMode: compactMode,
          scrolling: scrolling,
          icon: iconBuilder(item),
          label: itemLabel,
        ),
      ),
    );
  }
}

/// The chips of a [TypeSelector.scrollingRow]: one row, scrolled sideways, that
/// brings the selected chip into view.
class _ScrollingChipRow<T> extends StatefulWidget {
  final List<T> values;
  final T selectedValue;
  final EdgeInsetsGeometry padding;
  final double spacing;
  final String? semanticsLabel;
  final Widget Function(T item) chipBuilder;

  const _ScrollingChipRow({
    required this.values,
    required this.selectedValue,
    required this.padding,
    required this.spacing,
    required this.semanticsLabel,
    required this.chipBuilder,
  });

  @override
  State<_ScrollingChipRow<T>> createState() => _ScrollingChipRowState<T>();
}

class _ScrollingChipRowState<T> extends State<_ScrollingChipRow<T>> {
  final _viewportKey = GlobalKey();
  final _chipKeys = <T, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reveal(animate: false),
    );
  }

  @override
  void didUpdateWidget(_ScrollingChipRow<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedValue != widget.selectedValue) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _reveal(animate: true),
      );
    }
  }

  /// Scrolls the selected chip to the middle of the row when it is not wholly
  /// inside it. A chip that is already wholly visible does not move the row
  /// under the finger that chose it.
  void _reveal({required bool animate}) {
    if (!mounted) return;
    final chip = _chipKeys[widget.selectedValue]?.currentContext;
    final viewport = _viewportKey.currentContext?.findRenderObject();
    final chipBox = chip?.findRenderObject();
    if (chip == null ||
        viewport is! RenderBox ||
        chipBox is! RenderBox ||
        !chipBox.attached) {
      return;
    }
    final left = chipBox.localToGlobal(Offset.zero, ancestor: viewport).dx;
    final wholly =
        left >= 0 && left + chipBox.size.width <= viewport.size.width;
    if (wholly) return;
    Scrollable.ensureVisible(
      chip,
      alignment: 0.5,
      duration: animate ? const Duration(milliseconds: 200) : Duration.zero,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: widget.semanticsLabel,
      child: SingleChildScrollView(
        key: _viewportKey,
        scrollDirection: Axis.horizontal,
        // Room above and below for the selected chip's glow, which the
        // scroll view would otherwise cut off.
        padding: widget.padding.add(const EdgeInsets.symmetric(vertical: 8)),
        child: Row(
          spacing: widget.spacing,
          children: [
            for (final item in widget.values)
              KeyedSubtree(
                key: _chipKeys.putIfAbsent(item, GlobalKey.new),
                child: widget.chipBuilder(item),
              ),
          ],
        ),
      ),
    );
  }
}

/// A wrapper that handles keyboard focus and interaction for accessible selection.
class _AccessibleChip extends StatefulWidget {
  final VoidCallback onTap;
  final Widget Function(BuildContext context, bool isFocused) builder;

  const _AccessibleChip({required this.onTap, required this.builder});

  @override
  State<_AccessibleChip> createState() => _AccessibleChipState();
}

class _AccessibleChipState extends State<_AccessibleChip> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (value) => setState(() => _isFocused = value),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: widget.builder(context, _isFocused),
      ),
    );
  }
}

/// Stateful chip widget with smooth animations that avoid flickering.
/// Uses TweenAnimationBuilder for controlled, non-rebuilding animations.
class _TypeSelectorChip extends StatelessWidget {
  final bool isSelected;
  final bool isFocused;
  final Color color;
  final bool isDark;
  final bool expanded;
  final bool compactMode;

  /// In a scrolling row: at least [AppSizes.minTouchTarget] wide and high,
  /// and a label that takes the width it needs (the row is unbounded).
  final bool scrolling;
  final IconData icon;
  final String label;

  const _TypeSelectorChip({
    required this.isSelected,
    this.isFocused = false,
    required this.color,
    required this.isDark,
    required this.expanded,
    required this.compactMode,
    this.scrolling = false,
    required this.icon,
    required this.label,
  });

  /// A row that scrolls sideways gives its chips unbounded width, where a
  /// Flexible label cannot be laid out; it shows its whole label instead.
  Widget _labelFor(Text text) => scrolling ? text : Flexible(child: text);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: isSelected ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (context, selectionProgress, child) {
        // Interpolate colors based on selection progress
        final backgroundColor = Color.lerp(
          isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          color,
          selectionProgress,
        )!;

        // Border color logic:
        // 1. If focused, use primary/high contrast color
        // 2. If selected, transparent (handled by background) or subtle
        // 3. Default border
        Color borderColor;
        if (isFocused) {
          borderColor = isDark ? Colors.white : AppColors.primaryLight;
        } else {
          borderColor = Color.lerp(
            isDark ? AppColors.neutral700Dark : AppColors.neutral200Light,
            Colors.transparent,
            selectionProgress,
          )!;
        }

        // Increase border width when focused
        final borderWidth = isFocused ? 2.0 : 1.5;

        final iconBgColor = Color.lerp(
          color.withValues(alpha: 0.12),
          Colors.white.withValues(alpha: 0.2),
          selectionProgress,
        )!;

        final iconColor = Color.lerp(color, Colors.white, selectionProgress)!;

        final textColor = Color.lerp(
          isDark ? AppColors.neutral200Dark : AppColors.neutral700Light,
          Colors.white,
          selectionProgress,
        )!;

        final shadowOpacity = selectionProgress * 0.35;

        return Container(
          constraints: scrolling
              ? const BoxConstraints(
                  minWidth: AppSizes.minTouchTarget,
                  minHeight: AppSizes.minTouchTarget,
                )
              : null,
          alignment: scrolling ? Alignment.center : null,
          padding: EdgeInsets.symmetric(
            horizontal: compactMode ? 12 : 16,
            vertical: compactMode ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: [
              if (selectionProgress > 0.1)
                BoxShadow(
                  color: color.withValues(alpha: shadowOpacity),
                  blurRadius: 16 * selectionProgress,
                  offset: Offset(0, 6 * selectionProgress),
                  spreadRadius: -2,
                ),
              if (isFocused)
                BoxShadow(
                  color: (isDark ? Colors.white : AppColors.primaryLight)
                      .withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Row(
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: expanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              // Icon container
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: compactMode ? 16 : 18,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 10),
              _labelFor(
                Text(
                  label,
                  style: AppTypography.body.copyWith(
                    fontSize: compactMode ? 13 : 14,
                    color: textColor,
                    fontWeight: selectionProgress > 0.5
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
