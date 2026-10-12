// Four more places paint an investment type's colour as text or as an icon on
// a pale tint of it, and the colour audit never judged them: the merge dialog's
// type chips, the goal picker's investment and type lists, the type filter
// sheet and the active filter chip on the investment list. The real widgets are
// pumped here for every type, in both themes, and what they painted is
// measured:
//
//  - a type name on its chip reaches 4.5:1, an icon on its tile or chip 3:1;
//  - the name and the icon are still shown, so the type never rests on colour.
//
// They paint the same pair as the investment card's chip, so the guard's rows
// `inv-<type>-<theme>@tint10` cover them.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_theme.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/investment_selector_sheet.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_list_state_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/investment_list_screen.dart';
import 'package:inv_tracker/features/investment/presentation/ui_extensions/investment_ui.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/merge_investments_dialog.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../../../helpers/contrast.dart';

ThemeData _theme(Brightness b) =>
    b == Brightness.dark ? AppTheme.darkTheme : AppTheme.lightTheme;

/// The fill of the nearest Container around [of] that has a plain colour,
/// composed over [ground] the way it is painted.
Color _fillBehind(Finder of, Color ground) {
  for (final element
      in find.ancestor(of: of, matching: find.byType(Container)).evaluate()) {
    final decoration = (element.widget as Container).decoration;
    if (decoration is BoxDecoration && decoration.color != null) {
      return composeOver(decoration.color!, ground);
    }
  }
  return ground;
}

InvestmentEntity _investment(InvestmentType type) => InvestmentEntity(
  id: 'demo-${type.name}',
  name: 'Demo ${type.name}',
  type: type,
  status: InvestmentStatus.open,
  createdAt: DateTime(2025, 1, 1),
  updatedAt: DateTime(2025, 1, 1),
  currency: 'INR',
);

Widget _app(Brightness b, Widget home, [List<Override> overrides = const []]) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: _theme(b),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  for (final brightness in Brightness.values) {
    final theme = brightness.name;
    final sheetGround = brightness == Brightness.dark
        ? AppColors.surfaceDark
        : AppColors.surfaceLight;
    final pageGround = brightness == Brightness.dark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;

    group('the merge dialog in $theme', () {
      for (final type in InvestmentType.values) {
        testWidgets('${type.name}: the selected chip is readable', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(800, 1600);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            _app(
              brightness,
              Scaffold(
                body: MergeInvestmentsDialog(
                  selectedCount: 2,
                  defaultType: type,
                  investmentTypes: [type],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // The dialog's own surface, as painted.
          final surface = tester
              .widget<Material>(
                find
                    .descendant(
                      of: find.byType(Dialog),
                      matching: find.byType(Material),
                    )
                    .first,
              )
              .color!;
          final name = find.text(type.displayName);
          expect(name, findsOneWidget);
          final chip = _fillBehind(name, surface);
          final text = tester.widget<Text>(name).style!.color!;
          final ratio = contrastRatio(text, chip);
          expect(
            ratio,
            greaterThanOrEqualTo(kMinText),
            reason:
                'inv-${type.name}-$theme@tint10: the merge chip is '
                '${ratio.toStringAsFixed(2)}:1',
          );
          // The chip's icon and the "present in selection" check are the
          // other two things coloured by the type.
          for (final icon in [type.icon, Icons.check_circle]) {
            final glyph = find.byIcon(icon);
            expect(glyph, findsOneWidget);
            final r = contrastRatio(tester.widget<Icon>(glyph).color!, chip);
            expect(
              r,
              greaterThanOrEqualTo(kMinGraphic),
              reason:
                  'inv-${type.name}-$theme@tint10: the merge chip icon '
                  '$icon is ${r.toStringAsFixed(2)}:1',
            );
          }
        });
      }
    });

    group('the goal picker in $theme', () {
      for (final mode in [GoalTrackingMode.byType, GoalTrackingMode.selected]) {
        testWidgets('${mode.name}: every type icon is readable', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(1080, 4800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            _app(
              brightness,
              Scaffold(
                body: InvestmentSelectorSheet(
                  trackingMode: mode,
                  selectedInvestmentIds: const [],
                  selectedTypes: const [],
                  onInvestmentsSelected: (_) {},
                  onTypesSelected: (_) {},
                ),
              ),
              [
                allInvestmentsProvider.overrideWith(
                  (ref) => Stream.value([
                    for (final t in InvestmentType.values) _investment(t),
                  ]),
                ),
              ],
            ),
          );
          await tester.pumpAndSettle();

          for (final type in InvestmentType.values) {
            final glyph = find.byIcon(type.icon);
            expect(glyph, findsWidgets);
            final tile = _fillBehind(glyph.first, sheetGround);
            final ratio = contrastRatio(
              tester.widget<Icon>(glyph.first).color!,
              tile,
            );
            expect(
              ratio,
              greaterThanOrEqualTo(kMinGraphic),
              reason:
                  'inv-${type.name}-$theme@tint10: the picker icon is '
                  '${ratio.toStringAsFixed(2)}:1',
            );
            // The name is text beside the icon.
            expect(
              mode == GoalTrackingMode.byType
                  ? find.text(type.displayName)
                  : find.text('Demo ${type.name}'),
              findsOneWidget,
            );
          }
        });
      }
    });

    group('the type filter on the investment list in $theme', () {
      Future<void> pumpList(WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _app(brightness, const InvestmentListScreen(), [
            allInvestmentsProvider.overrideWith((ref) => Stream.value([])),
            archivedInvestmentsProvider.overrideWith((ref) => Stream.value([])),
          ]),
        );
        await tester.pumpAndSettle();
      }

      testWidgets('the filter sheet lists every type with a readable icon', (
        tester,
      ) async {
        await pumpList(tester);
        await tester.tap(find.byIcon(Icons.filter_list_rounded));
        await tester.pumpAndSettle();
        for (final type in InvestmentType.values) {
          final glyph = find.descendant(
            of: find.byType(ListTile),
            matching: find.byIcon(type.icon),
          );
          expect(glyph, findsOneWidget);
          final tile = _fillBehind(glyph, sheetGround);
          final ratio = contrastRatio(tester.widget<Icon>(glyph).color!, tile);
          expect(
            ratio,
            greaterThanOrEqualTo(kMinGraphic),
            reason:
                'inv-${type.name}-$theme@tint10: the filter sheet icon is '
                '${ratio.toStringAsFixed(2)}:1',
          );
          expect(find.text(type.displayName), findsOneWidget);
        }
      });

      testWidgets('the active filter chip is readable for every type', (
        tester,
      ) async {
        await pumpList(tester);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(InvestmentListScreen)),
        );
        for (final type in InvestmentType.values) {
          container
              .read(investmentListStateProvider.notifier)
              .setTypeFilter(type);
          await tester.pumpAndSettle();
          final name = find.text(type.displayName);
          expect(name, findsOneWidget);
          final chip = _fillBehind(name, pageGround);
          final ratio = contrastRatio(
            tester.widget<Text>(name).style!.color!,
            chip,
          );
          expect(
            ratio,
            greaterThanOrEqualTo(kMinText),
            reason:
                'inv-${type.name}-$theme@tint10: the filter chip is '
                '${ratio.toStringAsFixed(2)}:1',
          );
          // The icons are in the chip's own row, not the empty state's.
          final row = find.ancestor(of: name, matching: find.byType(Row)).first;
          for (final icon in [type.icon, Icons.close_rounded]) {
            final glyph = find.descendant(of: row, matching: find.byIcon(icon));
            expect(glyph, findsOneWidget);
            final r = contrastRatio(tester.widget<Icon>(glyph).color!, chip);
            expect(
              r,
              greaterThanOrEqualTo(kMinGraphic),
              reason:
                  'inv-${type.name}-$theme@tint10: the filter chip icon '
                  '$icon is ${r.toStringAsFixed(2)}:1',
            );
          }
        }
      });
    });
  }
}
