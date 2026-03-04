/// Hero card widgets for the overview screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/utils/accessibility_utils.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/utils/number_format_utils.dart';
import 'package:inv_tracker/core/widgets/compact_amount_text.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/core/widgets/privacy_toggle_button.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';

/// Notifier for toggling between all and realized-only net position
class ShowRealizedOnlyNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void set(bool value) => state = value;
}

final showRealizedOnlyProvider =
    NotifierProvider<ShowRealizedOnlyNotifier, bool>(
      ShowRealizedOnlyNotifier.new,
    );

/// Hero card with toggle for showing all vs realized-only stats.
class HeroCardWithToggle extends ConsumerWidget {
  final AsyncValue<InvestmentStats> globalStats;
  final AsyncValue<InvestmentStats> closedStats;
  final NumberFormat currencyFormat;
  final Widget Function(String error) errorBuilder;

  const HeroCardWithToggle({
    super.key,
    required this.globalStats,
    required this.closedStats,
    required this.currencyFormat,
    required this.errorBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showRealizedOnly = ref.watch(showRealizedOnlyProvider);

    return globalStats.when(
      loading: () => const LoadingHeroCard(),
      error: (e, _) => errorBuilder(e.toString()),
      data: (global) => closedStats.when(
        loading: () => HeroCardContent(
          globalStats: global,
          closedStats: global,
          currencyFormat: currencyFormat,
          showRealizedOnly: showRealizedOnly,
        ),
        error: (e, s) => HeroCardContent(
          globalStats: global,
          closedStats: global,
          currencyFormat: currencyFormat,
          showRealizedOnly: showRealizedOnly,
        ),
        data: (closed) => HeroCardContent(
          globalStats: global,
          closedStats: closed,
          currencyFormat: currencyFormat,
          showRealizedOnly: showRealizedOnly,
        ),
      ),
    );
  }
}

/// Content of the hero card showing net position and stats.
class HeroCardContent extends ConsumerWidget {
  final InvestmentStats globalStats;
  final InvestmentStats closedStats;
  final NumberFormat currencyFormat;
  final bool showRealizedOnly;

  const HeroCardContent({
    super.key,
    required this.globalStats,
    required this.closedStats,
    required this.currencyFormat,
    required this.showRealizedOnly,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = showRealizedOnly ? closedStats : globalStats;
    final netPosition = stats.netCashFlow;
    final isPositive = netPosition >= 0;

    final semanticLabel = AccessibilityUtils.statCardLabel(
      title: showRealizedOnly
          ? 'Realized Net Position'
          : 'Net Position All Investments',
      value: AccessibilityUtils.formatCurrencyForScreenReader(
        netPosition,
        currencyFormat.currencySymbol,
      ),
      subtitle: stats.hasData
          ? 'Return: ${AccessibilityUtils.formatPercentageForScreenReader(stats.absoluteReturn)}'
          : null,
    );

    return Semantics(
      label: semanticLabel,
      child: GlassHeroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitleRow(context, ref),
            const SizedBox(height: 8),
            _buildValueRow(netPosition, isPositive, stats, ref),
            const SizedBox(height: 16),
            _buildStatsRow(stats, ref),
            const SizedBox(height: 8),
            _buildCurrencyIndicator(ref),
            if (showRealizedOnly) ...[
              const SizedBox(height: 4),
              Text(
                'Showing closed investments only',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTitleRow(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: Text(
            showRealizedOnly ? 'Realized Net Position' : 'Net Position (All)',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
        ),
        // Privacy toggle button
        const PrivacyToggleButton(iconSize: 18),
        const SizedBox(width: 8),
        _buildToggleButton(ref),
      ],
    );
  }

  Widget _buildToggleButton(WidgetRef ref) {
    void onTap() {
      HapticFeedback.lightImpact();
      ref.read(showRealizedOnlyProvider.notifier).toggle();
    }

    return Semantics(
      button: true,
      label: showRealizedOnly
          ? 'Switch to all investments'
          : 'Switch to realized investments only',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                showRealizedOnly ? Icons.check_circle : Icons.all_inclusive,
                color: Colors.white.withValues(alpha: 0.9),
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                showRealizedOnly ? 'Realized' : 'All',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildValueRow(
    double netPosition,
    bool isPositive,
    InvestmentStats stats,
    WidgetRef ref,
  ) {
    final isPrivacyMode = ref.watch(privacyModeProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: PrivacyMask(
            child: CompactAmountText(
              amount: netPosition,
              compactText: currencyFormat.formatSmart(netPosition),
              currencySymbol: currencyFormat.currencySymbol,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (stats.hasData) ...[
          const SizedBox(width: 10),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isPrivacyMode ? 0.0 : 1.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isPositive
                    ? Colors.green.withValues(alpha: 0.3)
                    : Colors.red.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${stats.absoluteReturn >= 0 ? '+' : ''}${stats.absoluteReturn.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: isPositive ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatsRow(InvestmentStats stats, WidgetRef ref) {
    final isPrivacyMode = ref.watch(privacyModeProvider);

    return Row(
      children: [
        // Cash Out with up arrow
        _buildCashFlowStat(
          icon: Icons.arrow_upward_rounded,
          amount: stats.totalInvested,
          value: currencyFormat.formatCompact(stats.totalInvested),
          label: 'out',
          isPrivacyMode: isPrivacyMode,
        ),
        const SizedBox(width: 16),
        // Cash In with down arrow
        _buildCashFlowStat(
          icon: Icons.arrow_downward_rounded,
          amount: stats.totalReturned,
          value: currencyFormat.formatCompact(stats.totalReturned),
          label: 'in',
          isPrivacyMode: isPrivacyMode,
        ),
        const Spacer(),
        // XIRR
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'XIRR',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            MaskedAmountText(
              text: formatXirr(stats.xirr, showSign: false) ?? '0.0%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCurrencyIndicator(WidgetRef ref) {
    final baseCurrency = ref.watch(currencyCodeProvider);
    final currencySymbol = getCurrencySymbol(baseCurrency);

    return Row(
      children: [
        Icon(
          Icons.info_outline,
          size: 12,
          color: Colors.white.withValues(alpha: 0.4),
        ),
        const SizedBox(width: 4),
        Text(
          'All amounts shown in $currencySymbol ($baseCurrency)',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 10,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildCashFlowStat({
    required IconData icon,
    required double amount,
    required String value,
    required String label,
    required bool isPrivacyMode,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 14),
        const SizedBox(width: 4),
        isPrivacyMode
            ? MaskedAmountText(
                text: value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              )
            : CompactAmountText(
                amount: amount,
                compactText: value,
                currencySymbol: currencyFormat.currencySymbol,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// Loading state for the hero card.
class LoadingHeroCard extends StatelessWidget {
  const LoadingHeroCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 100,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 200,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }
}
