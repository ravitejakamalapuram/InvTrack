import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/period_inflows.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/tonal_icon_action.dart';
import 'package:inv_tracker/features/digest/domain/monthly_digest.dart';
import 'package:inv_tracker/features/digest/presentation/providers/monthly_digest_provider.dart';
import 'package:inv_tracker/features/digest/presentation/screens/monthly_recap_screen.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../helpers/inter_font.dart';

class _Privacy extends PrivacyModeNotifier {
  _Privacy(this.on);
  final bool on;
  @override
  bool build() => on;
  @override
  Future<void> toggle() async => state = !state;
}

final _october = DigestMonth.parse('2026-10');

InvestmentEntity _inv(String id, String name, {DateTime? maturityDate}) =>
    InvestmentEntity(
      id: id,
      name: name,
      type: InvestmentType.fixedDeposit,
      status: InvestmentStatus.open,
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
      currency: 'INR',
      maturityDate: maturityDate,
    );

MonthlyDigest _digest({
  double total = 18400,
  double previous = 14200,
  int count = 3,
  bool quiet = false,
}) => MonthlyDigest(
  month: _october,
  baseCurrency: 'INR',
  moneyIn: quiet
      ? PeriodInflows.empty
      : PeriodInflows(total: total, count: count, investmentCount: 2),
  previousMoneyIn: PeriodInflows(total: previous, count: 1, investmentCount: 1),
  maturingNextMonth: quiet
      ? const []
      : [_inv('fd', 'Senior citizen FD', maturityDate: DateTime(2026, 11, 12))],
  needingValue: quiet ? const [] : [_inv('p2p', 'P2P pool')],
);

Future<void> _pump(
  WidgetTester tester,
  MonthlyDigest digest, {
  bool privacy = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currencyCodeProvider.overrideWith((ref) => 'INR'),
        privacyModeProvider.overrideWith(() => _Privacy(privacy)),
        monthlyDigestProvider(_october).overrideWithValue(AsyncData(digest)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MonthlyRecapScreen(month: _october),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadInterFont);

  testWidgets('shows the month, its payouts and the change', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _digest());

    expect(find.text('October Recap'), findsOneWidget);
    expect(find.text('3 payouts from 2 investments'), findsOneWidget);
    expect(find.textContaining('more than September'), findsOneWidget);
    expect(find.byIcon(Icons.trending_up), findsOneWidget);
    expect(find.text('Coming Up In November'), findsOneWidget);
    expect(find.text('MATURES 12 NOV'), findsOneWidget);
    expect(find.text('Needs A Value'), findsOneWidget);
    expect(find.text('P2P pool'), findsOneWidget);
    expect(find.text('Archived investments are not included.'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        RegExp(r'^Money in, October: .*rupees\. 3 payouts'),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'\nUp 4,200 rupees from September$')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('a fall reads as down, with its own icon', (tester) async {
    await _pump(tester, _digest(total: 1000, previous: 2500));

    expect(find.textContaining('less than September'), findsOneWidget);
    expect(find.byIcon(Icons.trending_down), findsOneWidget);
  });

  testWidgets('privacy mode hides the amounts and the direction', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _digest(), privacy: true);

    expect(find.textContaining('more than'), findsNothing);
    expect(find.byIcon(Icons.trending_up), findsNothing);
    expect(find.textContaining('Compared with September'), findsOneWidget);
    expect(find.textContaining('18,400'), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp(r'^Money in, October: Hidden amount\.')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('a quiet month shows the empty states', (tester) async {
    await _pump(tester, _digest(quiet: true));

    expect(find.text('No payouts recorded in October'), findsOneWidget);
    expect(find.text('Add a Payout'), findsOneWidget);
    expect(find.text('Nothing matures in November'), findsOneWidget);
    expect(find.text('Needs A Value'), findsNothing);
  });

  testWidgets('the app bar uses the tonal chips and the privacy chip toggles', (
    tester,
  ) async {
    await _pump(tester, _digest());

    expect(find.byType(TonalIconAction), findsNWidgets(2));
    expect(find.byTooltip('Hide amounts'), findsOneWidget);
    expect(find.textContaining('18,400'), findsOneWidget);

    await tester.tap(find.byTooltip('Hide amounts'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Show amounts'), findsOneWidget);
    expect(find.textContaining('18,400'), findsNothing);
  });

  for (final privacy in [false, true]) {
    testWidgets('does not overflow at 320dp and 1.8x text '
        '(privacy: $privacy)', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currencyCodeProvider.overrideWith((ref) => 'INR'),
            privacyModeProvider.overrideWith(() => _Privacy(privacy)),
            monthlyDigestProvider(
              _october,
            ).overrideWithValue(AsyncData(_digest())),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.8)),
              child: child!,
            ),
            home: MonthlyRecapScreen(month: _october),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  }
}
