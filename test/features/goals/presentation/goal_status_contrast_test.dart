// The status of a goal (Ahead, On Track, Behind, Achieved ...) is painted as a
// line on the goal card and as an icon and a word on the goal details screen.
// The colours used to be hex copies of the bright palette, 2.15:1 to 3.68:1 on
// white, and the two greys were under 4.5:1 on the dark card. Every status
// takes a colour that reads in the theme it is in; the label and the icon
// still say which status it is.
//
// The ids are rows of test/core/theme/contrast_pairs.dart; the guard finds
// them here.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/goals/presentation/screens/goal_details_screen.dart';
import 'package:inv_tracker/features/goals/presentation/ui_extensions/goal_type_ui.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goal_card.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/contrast.dart';
import '../../../helpers/themed_pump.dart';

final _goal = GoalEntity(
  id: 'house',
  name: 'House',
  type: GoalType.targetAmount,
  targetAmount: 1000000,
  trackingMode: GoalTrackingMode.all,
  icon: '🏠',
  colorValue: 0xFF3B82F6,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  currency: 'INR',
);

GoalProgress _progress(GoalStatus status) => GoalProgress(
  goal: _goal,
  currentAmount: 200000,
  targetAmount: 1000000,
  progressPercent: 20,
  monthlyVelocity: 0,
  monthlyIncome: 0,
  status: status,
  currentMilestone: GoalMilestone.start,
  achievedMilestones: const [],
  linkedInvestmentCount: 1,
  calculatedAt: DateTime(2026, 10, 4),
);

/// Each status with the id of its pair in the light and in the dark theme.
const _ids = <GoalStatus, (String, String)>{
  GoalStatus.notStarted: (
    'goal-status-not-started-light@card',
    'goal-status-not-started-dark@card',
  ),
  GoalStatus.inProgress: (
    'goal-status-in-progress-light@card',
    'goal-status-in-progress-dark@card',
  ),
  GoalStatus.onTrack: (
    'goal-status-on-track-light@card',
    'goal-status-on-track-dark@card',
  ),
  GoalStatus.ahead: (
    'goal-status-ahead-light@card',
    'goal-status-ahead-dark@card',
  ),
  GoalStatus.behind: (
    'goal-status-behind-light@card',
    'goal-status-behind-dark@card',
  ),
  GoalStatus.achieved: (
    'goal-status-achieved-light@card',
    'goal-status-achieved-dark@card',
  ),
  GoalStatus.archived: (
    'goal-status-archived-light@card',
    'goal-status-archived-dark@card',
  ),
};

Future<void> _pumpApp(
  WidgetTester tester,
  Widget body,
  Brightness brightness,
  GoalStatus status,
) async {
  SharedPreferences.setMockInitialValues({'privacy_mode_enabled': false});
  final prefs = await SharedPreferences.getInstance();
  await pumpThemed(
    tester,
    body,
    brightness: brightness,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      currencySymbolProvider.overrideWith((ref) => '₹'),
      currencyLocaleProvider.overrideWith((ref) => 'en_IN'),
      multiCurrencyGoalProgressProvider(
        _goal.id,
      ).overrideWith((ref) async => _progress(status)),
      watchGoalByIdProvider(
        _goal.id,
      ).overrideWith((ref) => Stream.value(_goal)),
      goalLinkedInvestmentsProvider(
        _goal.id,
      ).overrideWith((ref) async => const []),
    ],
  );
  await tester.pumpAndSettle();
}

Color _page(Brightness b) =>
    b == Brightness.dark ? AppColors.backgroundDark : AppColors.backgroundLight;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  for (final status in GoalStatus.values) {
    for (final brightness in Brightness.values) {
      final dark = brightness == Brightness.dark;
      final id = dark ? _ids[status]!.$2 : _ids[status]!.$1;

      testWidgets('$id: the status line of the goal card reads', (
        tester,
      ) async {
        await _pumpApp(
          tester,
          GoalCard(goal: _goal, onTap: () {}),
          brightness,
          status,
        );
        final l10n = AppLocalizations.of(tester.element(find.byType(GoalCard)));
        final label = find.text(status.label(l10n));
        expect(label, findsOneWidget);
        final color = paintedTextColor(tester, label);
        expect(color, status.textColor(dark));
        expect(
          contrastRatio(color, groundBehind(tester, label, _page(brightness))),
          greaterThanOrEqualTo(kMinText),
          reason: id,
        );
        // The icon says the same thing without the colour.
        expect(find.byIcon(status.icon), findsOneWidget);
      });

      testWidgets('$id: the status icon and word on the details screen read', (
        tester,
      ) async {
        await _pumpApp(
          tester,
          GoalDetailsScreen(goalId: _goal.id),
          brightness,
          status,
        );
        final l10n = AppLocalizations.of(
          tester.element(find.byType(GoalDetailsScreen)),
        );
        final label = find.text(status.label(l10n));
        expect(label, findsOneWidget);
        final color = paintedTextColor(tester, label);
        expect(color, status.textColor(dark));
        final ground = groundBehind(tester, label, _page(brightness));
        expect(
          contrastRatio(color, ground),
          greaterThanOrEqualTo(kMinText),
          reason: id,
        );
        final icon = find.byIcon(status.icon);
        expect(icon, findsWidgets);
        expect(
          contrastRatio(paintedIconColor(tester, icon.first), ground),
          greaterThanOrEqualTo(kMinGraphic),
          reason: id,
        );
      });
    }
  }

  test(
    'the light statuses keep the greys and take the deeper text colours',
    () {
      expect(GoalStatus.ahead.textColor(false), AppColors.successLight);
      expect(GoalStatus.achieved.textColor(false), AppColors.successLight);
      expect(GoalStatus.behind.textColor(false), AppColors.warningTextLight);
      expect(GoalStatus.onTrack.textColor(false), AppColors.accentTextLight);
      expect(GoalStatus.notStarted.textColor(true), AppColors.neutral400Dark);
      expect(GoalStatus.inProgress.textColor(true), AppColors.neutral400Dark);
      expect(GoalStatus.archived.textColor(true), AppColors.neutral400Dark);
    },
  );
}
