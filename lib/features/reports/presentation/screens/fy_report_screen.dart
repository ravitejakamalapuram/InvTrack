/// Tax-Year (financial year) report screen (#800).
///
/// Shows an [FYReport] for an Apr-Mar year: hero net cash flow, money tiles,
/// the figures needed for a tax return, monthly bars and top performers. Every
/// amount goes through [MaskedAmountText] so privacy mode hides it. An
/// undefined XIRR reads "—" with a hint, never 0%.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/features/reports/presentation/providers/fy_report_provider.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/fy_report_sections.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class FyReportScreen extends ConsumerStatefulWidget {
  const FyReportScreen({super.key, required this.initialFyYear});

  /// Start year of the FY shown first (2025 = 1 Apr 2025 to 31 Mar 2026).
  final int initialFyYear;

  @override
  ConsumerState<FyReportScreen> createState() => _FyReportScreenState();
}

class _FyReportScreenState extends ConsumerState<FyReportScreen> {
  late int _fyYear = widget.initialFyYear;

  /// The current FY and the two before it, plus the one opened from history.
  List<int> get _chipYears {
    final now = DateTime.now();
    final current = now.month >= 4 ? now.year : now.year - 1;
    final latest = math.max(current, widget.initialFyYear);
    return {latest, latest - 1, latest - 2, widget.initialFyYear}.toList()
      ..sort((a, b) => b.compareTo(a));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isPrivate = ref.watch(privacyModeProvider);
    final report = ref.watch(fyReportProvider(_fyYear));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.fyReportScreenTitle),
        actions: [
          IconButton(
            tooltip: isPrivate
                ? l10n.fyReportShowAmounts
                : l10n.fyReportHideAmounts,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: Icon(
              isPrivate
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            onPressed: () => ref.read(privacyModeProvider.notifier).toggle(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenEdge,
          AppSpacing.xs,
          AppSpacing.screenEdge,
          AppSpacing.xl,
        ),
        children: [
          _YearChips(
            years: _chipYears,
            selected: _fyYear,
            onSelected: (y) => setState(() => _fyYear = y),
          ),
          const SizedBox(height: AppSpacing.xl),
          report.when(
            data: (r) => FyReportBody(report: r),
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  Text(l10n.fyReportLoadError),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(fyReportProvider(_fyYear)),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _YearChips extends StatelessWidget {
  const _YearChips({
    required this.years,
    required this.selected,
    required this.onSelected,
  });

  final List<int> years;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return Semantics(
      container: true,
      label: l10n.fyReportYearChipsLabel,
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final y in years)
            Semantics(
              button: true,
              selected: y == selected,
              child: Material(
                color: y == selected ? primary : Colors.transparent,
                shape: StadiumBorder(
                  side: y == selected
                      ? BorderSide.none
                      : BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => onSelected(y),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 48,
                      minWidth: 48,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          l10n.fyLabel('$y', _twoDigits(y + 1)),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: y == selected
                                ? AppColors.onFill(primary)
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _twoDigits(int year) => (year % 100).toString().padLeft(2, '0');
