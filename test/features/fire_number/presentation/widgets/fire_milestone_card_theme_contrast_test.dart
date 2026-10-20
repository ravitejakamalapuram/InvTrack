// An achieved FIRE milestone shows a check on a disc. In light the check and the
// ring are the deeper green (it reads on white) and the disc is a 20% tint of
// the brighter green it always was; in dark both are the dark green. Pumped in
// both themes, read from the real widgets. Colour is not the only carrier: the
// milestone is written out, and a check replaces the percentage on the disc.
//
// The id in the test name is a row of test/core/theme/contrast_pairs.dart; the
// guard finds it here.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_calculation_result.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/presentation/widgets/fire_milestone_card.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/contrast.dart';

// Demo figures only.
const _achieved = FireMilestone(
  type: FireMilestoneType.percent25,
  targetAmount: 2500000,
  isAchieved: true,
  currentProgress: 100,
);

const _pending = FireMilestone(
  type: FireMilestoneType.percent50,
  targetAmount: 5000000,
  isAchieved: false,
  currentProgress: 40,
);

Future<void> _pump(WidgetTester tester, Brightness brightness) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currencyLocaleProvider.overrideWith((ref) => 'en_IN'),
      ],
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: FireMilestoneCard(
            milestones: [_achieved, _pending],
            currencySymbol: '₹',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The fill and the ring of the disc around the check.
BoxDecoration _discAround(WidgetTester tester, Finder check) {
  for (final element
      in find
          .ancestor(of: check, matching: find.byType(Container))
          .evaluate()) {
    final decoration = (element.widget as Container).decoration;
    if (decoration is BoxDecoration && decoration.color != null) {
      return decoration;
    }
  }
  throw StateError('No filled disc around the check.');
}

void main() {
  testWidgets('in light the check and ring are the deeper green on a tint of '
      'the brighter one (fire-milestone-disc-light@tint20)', (tester) async {
    await _pump(tester, Brightness.light);

    final check = find.byIcon(Icons.check);
    expect(check, findsOneWidget, reason: 'one milestone is achieved');
    expect(find.text(_achieved.label), findsOneWidget);
    expect(find.text('${_pending.percentage}%'), findsOneWidget);
    expect(tester.widget<Icon>(check).color, AppColors.successLight);

    final disc = _discAround(tester, check);
    expect(
      (disc.border! as Border).top.color,
      AppColors.successLight,
      reason: 'the ring is drawn in the text green',
    );
    final fill = composeOver(disc.color!, AppColors.cardLight);
    expect(
      fill,
      composeOver(
        AppColors.successTintLight.withValues(alpha: 0.2),
        AppColors.cardLight,
      ),
    );
    expect(
      contrastRatio(AppColors.successLight, fill),
      greaterThanOrEqualTo(kMinGraphic),
      reason: 'fire-milestone-disc-light@tint20',
    );
  });

  testWidgets('in dark the check, ring and tint are the dark green', (
    tester,
  ) async {
    await _pump(tester, Brightness.dark);

    final check = find.byIcon(Icons.check);
    expect(tester.widget<Icon>(check).color, AppColors.successDark);
    final disc = _discAround(tester, check);
    expect((disc.border! as Border).top.color, AppColors.successDark);
    final fill = composeOver(disc.color!, AppColors.cardDark);
    expect(
      fill,
      composeOver(
        AppColors.successDark.withValues(alpha: 0.2),
        AppColors.cardDark,
      ),
    );
    expect(
      contrastRatio(AppColors.successDark, fill),
      greaterThanOrEqualTo(kMinGraphic),
    );
  });
}
