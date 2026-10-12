// The detail screen's header is painted in the investment's type colour, and
// everything on it (the name, the type and CLOSED labels, the type icon, the
// notes and the two app bar buttons) takes one foreground, white or ink,
// whichever reads better on that colour. It used to be white for all but the
// notes, with the notes picked by a luminance threshold, so a gold header had a
// white name at 1.4:1.
//
// The real screen is pumped for every type, open and closed, in both themes.
// The id below is a row of test/core/theme/contrast_pairs.dart; the guard finds
// it here.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/tonal_icon_action.dart';
import 'package:inv_tracker/features/income_projection/presentation/providers/expected_cash_flow_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/document_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/investment_detail_screen.dart';
import 'package:inv_tracker/features/investment/presentation/ui_extensions/investment_ui.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/contrast.dart';

const _pair = 'inv-detail-header@fill';
const _notes = 'Demo notes';

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

class _SameCurrencyService implements CurrencyConversionService {
  @override
  Future<double> convert({
    required double amount,
    required String from,
    required String to,
    DateTime? date,
  }) async => amount;

  @override
  Future<Map<String, double>> batchConvertHistorical({
    required Map<String, ConversionRequest> requests,
    required String to,
  }) async => {for (final e in requests.entries) e.key: e.value.amount};

  @override
  Future<double?> getLastKnownRate({
    required String from,
    required String to,
  }) async => 1.0;

  @override
  Future<double> getRate({
    required String from,
    required String to,
    DateTime? date,
  }) async => 1.0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

InvestmentEntity _investment(InvestmentType type, {bool closed = false}) =>
    InvestmentEntity(
      id: 'demo',
      name: 'Demo investment',
      type: type,
      status: closed ? InvestmentStatus.closed : InvestmentStatus.open,
      notes: _notes,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      currency: 'INR',
    );

Future<void> _pump(
  WidgetTester tester,
  InvestmentEntity investment,
  Brightness brightness,
) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        privacyModeProvider.overrideWith(_PrivacyOff.new),
        currencyCodeProvider.overrideWithValue('INR'),
        currencyConversionServiceProvider.overrideWithValue(
          _SameCurrencyService(),
        ),
        cashFlowsByInvestmentProvider(
          investment.id,
        ).overrideWith((ref) => Stream.value([])),
        expectedCashFlowsByInvestmentProvider(
          investment.id,
        ).overrideWith((ref) => Stream.value([])),
        documentsByInvestmentProvider(
          investment.id,
        ).overrideWith((ref) => Stream.value([])),
      ],
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InvestmentDetailScreen(investment: investment),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The colour of the header: the first stop of its gradient, which the app bar
/// repeats behind it as a solid.
Color _headerFill(WidgetTester tester) {
  for (final container in tester.widgetList<Container>(
    find.descendant(
      of: find.byType(FlexibleSpaceBar),
      matching: find.byType(Container),
    ),
  )) {
    final decoration = container.decoration;
    if (decoration is BoxDecoration && decoration.gradient is LinearGradient) {
      return (decoration.gradient! as LinearGradient).colors.first;
    }
  }
  throw StateError('No gradient header.');
}

/// What [of] sits on: the nearest filled Container around it inside the
/// header, over [fill]; the header's own fill when there is none.
Color _ground(WidgetTester tester, Finder of, Color fill) {
  for (final element
      in find.ancestor(of: of, matching: find.byType(Container)).evaluate()) {
    final decoration = (element.widget as Container).decoration;
    if (decoration is BoxDecoration && decoration.color != null) {
      return composeOver(decoration.color!, fill);
    }
  }
  return fill;
}

Finder _inHeader(Finder inner) =>
    find.descendant(of: find.byType(FlexibleSpaceBar), matching: inner);

void main() {
  for (final brightness in Brightness.values) {
    for (final closed in [false, true]) {
      final types = closed
          ? [InvestmentType.fixedDeposit]
          : InvestmentType.values;
      for (final type in types) {
        final label = closed ? 'closed' : type.name;
        testWidgets('$label in ${brightness.name}: the header is readable', (
          tester,
        ) async {
          final investment = _investment(type, closed: closed);
          await _pump(tester, investment, brightness);
          final fill = _headerFill(tester);

          void text(String what, Finder finder, double min) {
            expect(finder, findsOneWidget, reason: '$_pair: $what is shown');
            final style = tester.widget<Text>(finder).style!;
            final ratio = contrastRatio(
              style.color!,
              _ground(tester, finder, fill),
            );
            expect(
              ratio,
              greaterThanOrEqualTo(min),
              reason: '$_pair: $what is ${ratio.toStringAsFixed(2)}:1',
            );
          }

          void glyph(String what, Finder finder) {
            expect(finder, findsOneWidget, reason: '$_pair: $what is shown');
            final ratio = contrastRatio(
              tester.widget<Icon>(finder).color!,
              _ground(tester, finder, fill),
            );
            expect(
              ratio,
              greaterThanOrEqualTo(kMinGraphic),
              reason: '$_pair: $what is ${ratio.toStringAsFixed(2)}:1',
            );
          }

          // The name and the type are text, so the type never rests on colour.
          text('the name', _inHeader(find.text(investment.name)), kMinText);
          text(
            'the type label',
            _inHeader(find.text(type.displayName)),
            kMinText,
          );
          if (closed) text('CLOSED', _inHeader(find.text('CLOSED')), kMinText);
          text('the notes', _inHeader(find.text(_notes)), kMinText);
          glyph('the type icon', _inHeader(find.byIcon(type.icon)));
          glyph(
            'the notes icon',
            _inHeader(find.byIcon(Icons.edit_note_rounded)),
          );

          // The back and menu buttons: an icon on a 36px chip over the bar.
          final bar = tester.widget<AppBar>(find.byType(AppBar));
          final chips = find.byKey(TonalIconAction.chipKey);
          expect(chips, findsNWidgets(2));
          for (var i = 0; i < 2; i++) {
            final iconFinder = find.descendant(
              of: chips.at(i),
              matching: find.byType(Icon),
            );
            final ratio = contrastRatio(
              tester.widget<Icon>(iconFinder).color!,
              _ground(tester, iconFinder, bar.backgroundColor!),
            );
            expect(
              ratio,
              greaterThanOrEqualTo(kMinGraphic),
              reason:
                  '$_pair: app bar button $i is ${ratio.toStringAsFixed(2)}:1',
            );
          }

          // Scrolled away, the bar carries the name on the same colour.
          final sliver = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
          final scrollable = tester.state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          scrollable.position.jumpTo(sliver.expandedHeight! - kToolbarHeight);
          await tester.pump();
          final title = find.descendant(
            of: find.byType(NavigationToolbar),
            matching: find.text(investment.name),
          );
          expect(title, findsOneWidget);
          final titleRatio = contrastRatio(
            tester.widget<Text>(title).style!.color!,
            bar.backgroundColor!,
          );
          expect(
            titleRatio,
            greaterThanOrEqualTo(kMinText),
            reason:
                '$_pair: the app bar title is ${titleRatio.toStringAsFixed(2)}:1',
          );
        });
      }
    }
  }
}
