/// One left/right edge and one foot for the main screens (Overview,
/// Investments, Investment detail, Goals).
///
/// Every piece of content in a screen body gets its horizontal inset from here,
/// never from a literal or from its own margin, so that headings, the hero,
/// cards and notes start on the same line. Every screen with a floating action
/// button ends its scroll with [AppSpacing.fabClearance], so the last item can
/// be scrolled clear of the button. All insets are directional, so they mirror
/// in right-to-left layouts.
///
/// `test/layout/edge_guard_*_test.dart` measures the four screens and
/// `test/repo/fab_clearance_scan_test.dart` checks that no screen with a FAB
/// leaves this out.
library;

import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';

/// Insets a box in a sliver list by [AppSpacing.screenEdge] on both sides.
class ScreenEdge extends StatelessWidget {
  const ScreenEdge({
    super.key,
    required this.child,
    this.top = 0,
    this.bottom = 0,
  });

  final Widget child;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        AppSpacing.screenEdge,
        top,
        AppSpacing.screenEdge,
        bottom,
      ),
      child: child,
    );
  }
}

/// Insets a sliver body by [AppSpacing.screenEdge] on both sides.
///
/// With [clearsFab] the foot is [AppSpacing.fabClearance] (the button, its
/// margin and the bottom inset) instead of [bottom], so the last item can be
/// scrolled fully clear of the button.
class ScreenSliver extends StatelessWidget {
  const ScreenSliver({
    super.key,
    required this.sliver,
    this.top = AppSpacing.md,
    this.bottom = AppSpacing.md,
    this.clearsFab = false,
  });

  final Widget sliver;
  final double top;
  final double bottom;

  /// True on a screen that shows a floating action button.
  final bool clearsFab;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsetsDirectional.fromSTEB(
        AppSpacing.screenEdge,
        top,
        AppSpacing.screenEdge,
        clearsFab ? AppSpacing.fabClearance(context) : bottom,
      ),
      sliver: sliver,
    );
  }
}

/// The foot of a body built from several slivers, as tall as
/// [AppSpacing.fabClearance]. Put it last.
class SliverFabClearance extends StatelessWidget {
  const SliverFabClearance({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(height: AppSpacing.fabClearance(context)),
    );
  }
}

/// A heading inside a screen body, with an optional [trailing] badge.
///
/// It adds no horizontal padding: the parent ([ScreenEdge] or [ScreenSliver])
/// owns the edge. Title and badge share a line while they fit; at large text
/// sizes the badge drops below the title instead of overflowing.
class ScreenSectionHeader extends StatelessWidget {
  const ScreenSectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xxs,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: AppTypography.h4.copyWith(
                color: isDark ? Colors.white : AppColors.neutral900Light,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
