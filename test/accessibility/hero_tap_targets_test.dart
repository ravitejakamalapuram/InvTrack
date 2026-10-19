// A49 (#806, UX-20): the privacy toggle and the Realized/All switch on the
// Overview hero are at least 48 x 48dp, and a test now enforces it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/privacy_toggle_button.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/hero_card.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../mocks/mock_analytics_service.dart';

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privacyModeProvider.overrideWith(_PrivacyOff.new),
        currencyCodeProvider.overrideWith((ref) => 'INR'),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the privacy toggle is a 48dp target, with and without its '
      'background', (tester) async {
    final handle = tester.ensureSemantics();
    for (final showBackground in [true, false]) {
      await _pump(
        tester,
        PrivacyToggleButton(iconSize: 18, showBackground: showBackground),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    }
    handle.dispose();
  });

  testWidgets('the hero card, with its Realized/All switch, has no target '
      'under 48dp', (tester) async {
    final handle = tester.ensureSemantics();
    final stats = InvestmentStats.empty();
    await _pump(
      tester,
      HeroCardContent(
        globalStats: stats,
        openStats: stats,
        closedStats: stats,
        currencyFormat: NumberFormat.currency(
          locale: 'en_IN',
          symbol: '₹',
          decimalDigits: 0,
        ),
        showRealizedOnly: false,
      ),
    );
    for (final label in [
      'Hide amounts',
      'Switch to realized investments only',
    ]) {
      final size = tester.getSemantics(find.bySemanticsLabel(label)).rect.size;
      expect(size.width, greaterThanOrEqualTo(48), reason: label);
      expect(size.height, greaterThanOrEqualTo(48), reason: label);
    }
    handle.dispose();
  });
}
